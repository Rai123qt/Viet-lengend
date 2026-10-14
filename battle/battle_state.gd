class_name BattleState
extends RefCounted
## Pure-logic battle state machine (no UI) for VIET LEGENDS — Story 1.
## Drives the turn loop, cards, intents, and Thach Sanh's CHORD system.
## UI (battle_screen.gd) observes this state and calls its methods.
## Headless tests + autoplay bot exercise this class directly.
##
## CHORDS: compose 1 chord per turn before playing Attack/Skill cards.
## Play notes in the chord's order ("A"=Attack, "S"=Skill) to complete it.
## Wrong note snaps the string (compose lost for the turn).
## Power cards are grace notes: free, never advance nor break.


class Fighter:
	extends RefCounted
	var name: String = ""
	var hp: int = 1
	var max_hp: int = 1
	var armor: int = 0
	var weak: int = 0          # deals 25% less attack damage; -1 at end of owner's turn
	var vulnerable: int = 0    # takes 50% more attack damage; -1 at end of owner's turn
	var is_player: bool = false
	var strength: int = 0      # +damage on all attacks
	var str_malus: int = 0     # temporary strength loss (Break Formation)
	var str_malus_turns: int = 0
	var evading: bool = false  # dodges Attack cards until end of next player turn
	var stunned: bool = false  # skips next turn (Divine Melody / Smoke Charm)
	var squeeze: bool = false  # Chan Tinh: attacks ramp if you hit too softly
	var squeeze_bonus: int = 0


var game: GameState
var rng := RandomNumberGenerator.new()

var player: Fighter
# v5.9: War Elephant companion (Hai Ba Trung only)
var elephant: Fighter = null
var elephant_turns: int = 0  # counts player turns; trample every 3
var has_elephant: bool = false
# v5.9 HBT cards: trample bonus (war_drum), per-turn elephant heal (me_linh_oath),
# elephant cards played this turn (sisters_fury).
var trample_bonus: int = 0
var me_linh_heal: int = 0
var elephant_cards_this_turn: int = 0
var enemies: Array = []
var enemy: Fighter
var encounter: Array = []        # Array of {"id": String, "hp_mult": float}
var target_idx: int = 0
var enemy_id: String = ""
var enemy_kind: String = ""
var phase: int = 1

var turn_count: int = 0
var energy: int = 0

var draw_pile: Array = []
var hand: Array = []
var discard_pile: Array = []
var stolen_pile: Array = []      # cards stolen by Ly Thong (gone for the battle)
var powers_in_play: Array = []   # power card ids active this battle
# v5.8 Thach Sanh story powers
var _lute_echo_dmg := 0
var _chord_discount := 0

var enemy_intents: Array = []
var pattern_indexes: Array = []
var intents: Array:
	get:
		if enemy_intents.is_empty():
			return []
		return enemy_intents[clampi(target_idx, 0, enemy_intents.size() - 1)]
	set(value):
		if enemy_intents.is_empty():
			return
		enemy_intents[clampi(target_idx, 0, enemy_intents.size() - 1)] = value

# --- CHORD state (reset each player turn) ---
# v3.8 AUTO-DETECT: no compose step. chord_seq = "A"/"S" notes played this
# turn; completing a known chord's sequence triggers it (max 1/turn).
# A note matching no known chord's prefix snaps the string.
var chord_seq: Array = []        # notes played this turn ("A"/"S")
var turn_notes: Array = []       # all notes incl. Power grace ("A"/"S"/"P")
var chord_snapped: bool = false  # set on wrong note; cleared on next note/turn
var chord_completed: bool = false # at most one chord completes per turn
var next_attack_bonus: int = 0    # CHARGE chord: next Attack +10
var _charge_active: int = 0       # bonus armed for the current attack
var sturdy_strings: bool = false  # power: first wrong note each battle doesn't snap
var _sturdy_uses: int = 0         # v5.2: remaining forgives (1, or 2 if upgraded)
var divine_lute: bool = false     # power: 3-note chords finish at 2 notes

# --- misc ---
var last_card: Dictionary = {}    # for Lute Pick replay
var player_dmg_this_turn: int = 0
var prev_turn_dmg: int = 0
## v3.4: Divine Axe passive — first Attack each turn +6 (reset each turn).
var divine_axe_used: bool = false
var whetstone_turns: int = 0      # War Paint: attacks +3 this turn
var whetstone_bonus: int = 0
var _cost_reduction: int = 0        # Fate's Thread: cards cost less this turn
var skills_played_this_turn: int = 0
var bloodlust_hits: int = 0         # Bloodlust: next 3 attacks +dmg
var frenzy_replay: bool = false     # Frenzy: replay flag
var next_chord_bonus: int = 0       # War Drums: next chord +dmg

var battle_over: bool = false
var result: String = ""
var log: Array = []
var events: Array = []  # structured events for UI animation; cleared per action


# ---------------------------------------------------------------- setup ---

func setup(p_deck: Array, p_encounter, p_game: GameState, p_seed: int) -> void:
	game = p_game
	rng.seed = p_seed
	var enc: Array = p_encounter if p_encounter is Array else [{"id": p_encounter, "hp_mult": 1.0}]
	if enc.is_empty():
		enc = [{"id": "wild_boar", "hp_mult": 1.0}]
	encounter = enc
	enemy_id = str(enc[0].get("id", ""))
	enemy_kind = EnemyDB.get_def(enemy_id).get("kind", "normal")

	player = Fighter.new()
	# v5.9: hero-aware player name.
	player.name = CharacterDB.hero_name(game.hero_id).capitalize()
	player.is_player = true
	player.max_hp = game.max_hp
	player.hp = game.hp
	player.armor = 0
	if game.has_perk("armor_start"):
		player.armor = 6
	if game.has_perk("strength_up"):
		player.strength = 1
	if game.has_relic("iron_rations"):
		player.armor += 4
		_log("Iron Rations: start with 4 Armor.")
	# v5.9: War Elephant for Hai Ba Trung
	if game.hero_id == "hai_ba_trung":
		elephant = Fighter.new()
		elephant.name = "War Elephant"
		elephant.max_hp = 30
		elephant.hp = 30
		elephant.is_player = true
		has_elephant = true
		elephant_turns = 0
		_log("War Elephant joins the battle! (30 HP)")

	enemies.clear()
	enemy_intents.clear()
	pattern_indexes.clear()
	for e in enc:
		var eid: String = str(e.get("id", ""))
		var edef := EnemyDB.get_def(eid)
		var f := Fighter.new()
		f.name = edef.get("name", "???")
		var mult := float(e.get("hp_mult", 1.0))
		f.max_hp = int(round(float(edef.get("hp", 30)) * mult))
		f.hp = f.max_hp
		f.squeeze = bool(edef.get("squeeze", false))
		if game.has_relic("caltrops"):
			f.max_hp = maxi(1, f.max_hp - 5)
			f.hp = f.max_hp
		enemies.append(f)
		enemy_intents.append([])
		pattern_indexes.append(0)
	target_idx = 0
	_sync_target()

	draw_pile = []
	for c in p_deck:
		draw_pile.append(CardDB.make(c["id"], c.get("upgraded", false)))
	_shuffle(draw_pile)
	_choose_all_intents()
	_log("Battle started: %s." % _enemy_list_name())


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t


func _log(s: String) -> void:
	log.append(s)


# --------------------------------------------------------------- intents ---

func _sync_target() -> void:
	target_idx = clampi(target_idx, 0, maxi(enemies.size() - 1, 0))
	if not enemies.is_empty():
		enemy = enemies[target_idx]


func _enemy_list_name() -> String:
	var names := []
	for f in enemies:
		names.append("%s (HP %d)" % [f.name, f.hp])
	return ", ".join(names)


func set_target(i: int) -> bool:
	if i < 0 or i >= enemies.size():
		return false
	if enemies[i].hp <= 0:
		return false
	target_idx = i
	_sync_target()
	_log("Target: %s." % enemies[i].name)
	return true


func _retarget() -> void:
	for i in range(enemies.size()):
		if enemies[i].hp > 0:
			target_idx = i
			_sync_target()
			return


func _choose_all_intents() -> void:
	for i in range(enemies.size()):
		if enemies[i].hp > 0:
			_choose_intents_for(i)


func _choose_intents_for(i: int) -> void:
	enemy_intents[i] = EnemyDB.intents_for_entry(encounter[i], pattern_indexes[i], phase)
	var pmult := float(encounter[i].get("power_mult", 1.0))
	var e: Fighter = enemies[i]
	for it in enemy_intents[i]:
		if pmult != 1.0:
			it["power"] = maxi(1, int(round(it["power"] * pmult)))
		# Chan Tinh squeeze ramp: attacks grow while you hit too softly.
		if e.squeeze and str(it.get("kind", "")) == "attack" and e.squeeze_bonus > 0:
			it["power"] = int(it["power"]) + e.squeeze_bonus


func intent_summary_for(i: int) -> Array:
	var out := []
	for it in enemy_intents[i]:
		out.append({"kind": str(it["kind"]), "power": int(it.get("power", 0)),
			"debuff": str(it.get("debuff", "")), "failed": false})
	return out


func intent_summary() -> Array:
	return intent_summary_for(target_idx)


# ------------------------------------------------------------ turn loop ---

func start_player_turn() -> void:
	turn_count += 1
	energy = 3
	# v5.9: War Elephant tramples every 3 player turns
	if has_elephant and elephant != null and elephant.hp > 0:
		elephant_turns += 1
		if elephant_turns >= 3:
			elephant_turns = 0
			_elephant_trample()
		# v5.9: ME LINH OATH — elephant heals at start of each turn
		if me_linh_heal > 0:
			elephant.hp = mini(elephant.max_hp, elephant.hp + me_linh_heal)
			events.append({"k": "elephant_heal", "n": me_linh_heal})
			_log("Me Linh Oath: War Elephant heals %d HP." % me_linh_heal)
	elephant_cards_this_turn = 0
	if turn_count == 1:
		if game.has_relic("coffee_thermos"):
			energy += 1
		if game.has_perk("energy_t1"):
			energy += 1
	# Chord state resets every turn.
	chord_seq = []
	turn_notes = []
	chord_snapped = false
	chord_completed = false
	next_attack_bonus = 0
	_charge_active = 0
	divine_axe_used = false
	# Chan Tinh squeeze: did you hit hard enough last turn?
	prev_turn_dmg = player_dmg_this_turn
	player_dmg_this_turn = 0
	for e in enemies:
		var edef := EnemyDB.get_def(str(encounter[enemies.find(e)].get("id", "")))
		if e.hp > 0 and e.squeeze and turn_count > 1 and prev_turn_dmg < 8 and e.squeeze_bonus < 6:
			e.squeeze_bonus += 1
			_log("%s squeezes tighter! Its attacks grow (+1)." % e.name)
			events.append({"k": "squeeze", "n": 1})
	if game.has_relic("chainmail"):
		player.armor += 2
	if game.has_relic("bandages") and player.hp < player.max_hp:
		player.hp = mini(player.hp + 3, player.max_hp)
		_log("Bandages: heal 3 HP.")
	var target := 5
	while hand.size() < target:
		if not _draw_one():
			break
	if turn_count == 1 and game.has_relic("second_breakfast"):
		draw_cards(1)
		_log("Second Breakfast: draw 1 extra card.")
	if turn_count == 1 and game.has_perk("draw_up"):
		draw_cards(1)
		_log("Quick Hands: draw 1 extra card.")
	_log("--- Turn %d: energy %d, hand %d ---" % [turn_count, energy, hand.size()])


func _draw_one() -> bool:
	if draw_pile.is_empty():
		if discard_pile.is_empty():
			return false
		draw_pile = discard_pile
		discard_pile = []
		_shuffle(draw_pile)
		_log("(reshuffle)")
		if game.has_relic("torn_page"):
			player.armor += 4
			_log("Torn Page: +4 Armor on reshuffle.")
	hand.append(draw_pile.pop_back())
	return true


func draw_cards(n: int) -> void:
	for i in range(n):
		if not _draw_one():
			break


func end_player_turn() -> void:
	events.clear()
	for e in enemies:
		e.armor = 0
	# Weak/Vulnerable on the player tick down at end of owner's turn.
	player.weak = maxi(0, player.weak - 1)
	player.vulnerable = maxi(0, player.vulnerable - 1)
	# Evade lasted through this player turn — it fades before the enemy phase.
	for e in enemies:
		e.evading = false
	whetstone_turns = 0
	whetstone_bonus = 0
	# Enemies act while you still hold your hand (Ly Thong steals from it!),
	# then the remaining hand is discarded.
	_run_enemy_phase()
	for c in hand:
		discard_pile.append(c)
	hand.clear()


func _run_enemy_phase() -> void:
	for i in range(enemies.size()):
		if battle_over:
			break
		if enemies[i].hp <= 0:
			continue
		if enemies[i].stunned:
			enemies[i].stunned = false
			events.append({"k": "e_stunned", "ei": i})
			_log("%s is stunned and loses its turn!" % enemies[i].name)
			continue
		for it in enemy_intents[i]:
			if battle_over:
				break
			_run_single_intent(it, enemies[i], i)
	if battle_over:
		return
	player.armor = 0
	for e in enemies:
		if e.hp > 0:
			e.weak = maxi(0, e.weak - 1)
			e.vulnerable = maxi(0, e.vulnerable - 1)
			# Break Formation wears off: restore stolen strength.
			if e.str_malus_turns > 0:
				e.str_malus_turns -= 1
				if e.str_malus_turns <= 0 and e.str_malus > 0:
					e.strength += e.str_malus
					_log("%s regains its strength (+%d)." % [e.name, e.str_malus])
					e.str_malus = 0
	for i in range(enemies.size()):
		if enemies[i].hp > 0:
			pattern_indexes[i] += 1
	_choose_all_intents()
	_check_boss_phase()


func _run_single_intent(it: Dictionary, e: Fighter, ei: int) -> void:
	var kind: String = str(it["kind"])
	var power: int = int(it.get("power", 0))
	events.append({"k": "e_intent", "kind": kind, "power": power, "ei": ei,
		"debuff": str(it.get("debuff", ""))})
	match kind:
		"attack":
			var dmg := power + e.strength
			if e.weak > 0:
				dmg = int(round(dmg * 0.75))
			_damage_player(dmg, ei)
			_log("%s attacks for %d." % [e.name, dmg])
		"defend":
			e.armor += power
			events.append({"k": "armor_e", "n": power, "ei": ei})
			_log("%s gains %d Block." % [e.name, power])
		"debuff":
			var db: String = str(it.get("debuff", "weak"))
			if db == "vulnerable":
				player.vulnerable += power
				events.append({"k": "vulnerable_p", "n": power, "ei": ei})
				_log("%s makes you Vulnerable (%d)." % [e.name, power])
			else:
				player.weak += power
				events.append({"k": "weak_p", "n": power, "ei": ei})
				_log("%s weakens you (%d Weak)." % [e.name, power])
		"heal":
			e.hp = mini(e.hp + power, e.max_hp)
			events.append({"k": "heal_e", "n": power, "ei": ei})
			_log("%s heals %d HP." % [e.name, power])
		"steal":
			var stolen := 0
			for s in range(power):
				if hand.is_empty():
					break
				var idx := rng.randi_range(0, hand.size() - 1)
				var c: Dictionary = hand[idx]
				hand.remove_at(idx)
				stolen_pile.append(c)
				stolen += 1
			events.append({"k": "steal", "n": stolen, "ei": ei})
			_log("%s steals %d card(s) from your hand!" % [e.name, stolen])
		"evade":
			e.evading = true
			events.append({"k": "evade", "ei": ei})
			_log("%s takes to the sky — it will evade your Attacks!" % e.name)
		"buff":
			e.strength += power
			events.append({"k": "strength_e", "n": power, "ei": ei})
			_log("%s gains %d Strength." % [e.name, power])
	_check_death()


func _check_boss_phase() -> void:
	if encounter.size() == 1 and phase == 1:
		var eid: String = str(encounter[0].get("id", ""))
		if (eid == "chan_tinh" or eid == "dai_bang") \
				and enemies[0].hp <= enemies[0].max_hp / 2:
			phase = 2
			pattern_indexes[0] = 0
			_choose_all_intents()
			events.append({"k": "phase2"})
			_log("%s ENRAGED! (Phase 2)" % enemies[0].name)


# ---------------------------------------------------------------- damage ---

func _damage_enemy(amount: int, is_attack_card: bool = false) -> void:
	var tgt: Fighter = enemies[target_idx]
	if tgt.hp <= 0:
		return
	if is_attack_card and tgt.evading:
		events.append({"k": "evaded", "target": target_idx})
		_log("%s evades the attack!" % tgt.name)
		return
	var a := amount
	if tgt.armor > 0:
		var blocked: int = mini(tgt.armor, a)
		tgt.armor -= blocked
		a -= blocked
	if a > 0:
		tgt.hp -= a
		player_dmg_this_turn += a
		events.append({"k": "dmg_e", "n": a, "target": target_idx})
		_log("Dealt %d to %s (HP %d)." % [amount, tgt.name, maxi(tgt.hp, 0)])
	if tgt.hp <= 0:
		tgt.hp = 0
		events.append({"k": "kill_e", "target": target_idx})
		_log("%s is defeated!" % tgt.name)
		_retarget()
	_check_boss_phase()
	_check_death()


func _damage_all_enemies(amount: int) -> void:
	for i in range(enemies.size()):
		if enemies[i].hp > 0:
			var keep := target_idx
			target_idx = i
			_sync_target()
			_damage_enemy(amount)
			target_idx = keep
			_sync_target()


func _damage_player(amount: int, ei: int = 0) -> void:
	# v5.9: 25% chance the elephant takes the hit instead (Hai Ba Trung)
	if has_elephant and elephant != null and elephant.hp > 0:
		if rng.randf() < 0.25:
			_damage_elephant(amount, ei)
			return
	var a := amount
	var broke := false
	if player.armor > 0:
		var blocked: int = mini(player.armor, a)
		player.armor -= blocked
		a -= blocked
		broke = player.armor == 0
	if a > 0:
		player.hp -= a
		events.append({"k": "dmg_p", "n": a, "ei": ei, "armor_broke": broke})
		_log("You take %d damage (HP %d)." % [a, maxi(player.hp, 0)])
	if a > 0 and game.has_relic("bramble_crown") and not battle_over:
		_log("Bramble Crown: thorns strike back for 2.")
		_damage_enemy(2)
	_check_death()


# v5.9: elephant tramples ALL enemies for 12 damage (+ war_drum bonus)
func _elephant_trample() -> void:
	if battle_over:
		return
	var dmg := 12 + trample_bonus
	if trample_bonus > 0:
		_log("War Drum echoes! Trample +%d damage." % trample_bonus)
		trample_bonus = 0
	_log("WAR ELEPHANT TRAMPLES! %d damage to ALL enemies!" % dmg)
	events.append({"k": "trample", "n": dmg})
	for i in range(enemies.size()):
		if enemies[i].hp > 0:
			enemies[i].hp = maxi(0, enemies[i].hp - dmg)
	_check_death()


# v5.9: heal the war elephant (capped at max_hp)
func _heal_elephant(amount: int) -> void:
	if elephant == null or elephant.hp <= 0:
		return
	elephant.hp = mini(elephant.max_hp, elephant.hp + amount)
	events.append({"k": "elephant_heal", "n": amount})
	_log("War Elephant heals %d HP (HP %d/%d)." % [amount, elephant.hp, elephant.max_hp])


# v5.9: damage the war elephant
func _damage_elephant(amount: int, ei: int = 0) -> void:
	if elephant == null or elephant.hp <= 0:
		return
	var a := amount
	if elephant.armor > 0:
		var blocked: int = mini(elephant.armor, a)
		elephant.armor -= blocked
		a -= blocked
	if a > 0:
		elephant.hp -= a
		events.append({"k": "dmg_e", "n": a, "ei": ei})
		_log("War Elephant takes %d damage (HP %d)!" % [a, maxi(elephant.hp, 0)])
		if elephant.hp <= 0:
			elephant.hp = 0
			_log("The War Elephant has fallen!")
			events.append({"k": "elephant_down"})


func _check_death() -> void:
	if battle_over:
		return
	var any_alive := false
	for e in enemies:
		if e.hp > 0:
			any_alive = true
			break
	if not any_alive:
		for e in enemies:
			e.hp = 0
		battle_over = true
		result = "win"
		events.append({"k": "end", "result": "win"})
		_log("Victory!")
	elif player.hp <= 0:
		player.hp = 0
		battle_over = true
		result = "lose"
		events.append({"k": "end", "result": "lose"})
		_log("Defeat...")


# ----------------------------------------------------------------- cards ---

func _up(base: int) -> int:
	return int(round(base * 1.3))


func card_cost(card: Dictionary) -> int:
	return int(CardDB.get_def(card["id"]).get("cost", 0))


func can_play(hand_idx: int) -> Dictionary:
	if battle_over:
		return {"ok": false, "reason": "Battle over."}
	if hand_idx < 0 or hand_idx >= hand.size():
		return {"ok": false, "reason": "Bad index."}
	var card: Dictionary = hand[hand_idx]
	if not CardDB.is_playable(card):
		return {"ok": false, "reason": "Unplayable."}
	var cost := card_cost(card)
	if energy < cost:
		return {"ok": false, "reason": "Not enough energy."}
	if card["id"] == "victory_song" and not chord_completed:
		return {"ok": false, "reason": "Play Victory Song only after completing a chord this turn."}
	return {"ok": true, "reason": ""}


func play_card(hand_idx: int) -> Dictionary:
	var chk := can_play(hand_idx)
	if not chk["ok"]:
		return chk
	events.clear()
	var card: Dictionary = hand[hand_idx]
	var d := CardDB.get_def(card["id"])
	var ctype: String = str(d.get("ctype", ""))
	var cost := card_cost(card)

	energy -= cost
	hand.remove_at(hand_idx)
	events.append({"k": "card", "id": card["id"], "ctype": ctype})
	# CHARGE: arm the bonus for the next Attack card.
	if ctype == "ATTACK" and next_attack_bonus > 0:
		_charge_active = next_attack_bonus
		next_attack_bonus = 0
		_log("CHARGE releases: +%d damage on this Attack." % _charge_active)
	if str(card["id"]).begins_with("elephant") or str(card["id"]) in ["war_drum", "stampede", "me_linh_oath", "victory_horn"]:
		elephant_cards_this_turn += 1
	_apply_card_effect(card, ctype)
	if not battle_over:
		discard_pile.append(card)
		last_card = card.duplicate()
		# Chord note tracking (v3.8 auto-detect; Power = grace note: shown, never breaks).
		if ctype == "ATTACK" or ctype == "SKILL":
			_note_played("A" if ctype == "ATTACK" else "S")
		elif ctype == "POWER":
			turn_notes.append("P")
	_check_death()
	return {"ok": true, "reason": ""}


# --------------------------------------------------------------- chords ---
# v3.8 AUTO-DETECT: playing Attack/Skill cards builds the note string
# automatically. Completing a known chord's sequence triggers its effect
# (max 1 chord per turn). A note matching no known chord's prefix snaps
# the string (cleared). Power cards are grace notes: tracked for display
# but never advance nor snap. ChordDB patterns are prefix-free, so an
# exact match is always unambiguous.

## Known chord ids (starter + learned this run).
func _known_chords() -> Array:
	return game.chords


## Does `seq` start with every note of `prefix`?
func _seq_starts_with(seq: Array, prefix: Array) -> bool:
	if seq.size() < prefix.size():
		return false
	for i in range(prefix.size()):
		if str(seq[i]) != str(prefix[i]):
			return false
	return true


## Shortest known chord having chord_seq as a proper prefix ("" if none).
## The tracker UI shows this as "what you're building toward".
func chord_target() -> String:
	if chord_completed or chord_seq.is_empty():
		return ""
	var best := ""
	var best_len := 999
	for cid in _known_chords():
		var seq: Array = ChordDB.seq(cid)
		if seq.size() > chord_seq.size() and seq.size() < best_len \
				and _seq_starts_with(seq, chord_seq):
			best = str(cid)
			best_len = seq.size()
	return best


func _note_played(note: String) -> void:
	turn_notes.append(note)  # display tracker keeps recording all turn
	if battle_over or chord_completed:
		return
	chord_snapped = false
	chord_seq.append(note)
	var known: Array = _known_chords()
	# Exact match -> complete (prefix-free DB => unambiguous).
	var matched := []
	for cid in known:
		var seq: Array = ChordDB.seq(cid)
		if seq.size() == chord_seq.size() and _seq_starts_with(chord_seq, seq):
			matched.append(cid)
	if not matched.is_empty():
		_complete_chords(matched)
		return
	# Divine Lute power: 3-note chords finish at 2 notes. Completes every
	# known 3-note chord sharing the 2-note prefix (deterministic set).
	if divine_lute and chord_seq.size() == 2:
		var quick := []
		for cid in known:
			var seq: Array = ChordDB.seq(cid)
			if seq.size() == 3 and _seq_starts_with(seq, chord_seq):
				quick.append(cid)
		if not quick.is_empty():
			_complete_chords(quick)
			return
	# v5.8: MAGIC LUTE SONG — chords complete with 1 fewer note
	if _chord_discount > 0:
		var discounted := []
		for cid in known:
			var seq: Array = ChordDB.seq(cid)
			var need := seq.size() - _chord_discount
			if need > 0 and chord_seq.size() == need and _seq_starts_with(seq, chord_seq):
				discounted.append(cid)
		if not discounted.is_empty():
			_complete_chords(discounted)
			return
	# Still a proper prefix of something known? Keep building.
	for cid in known:
		var seq: Array = ChordDB.seq(cid)
		if seq.size() > chord_seq.size() and _seq_starts_with(seq, chord_seq):
			events.append({"k": "chord_note", "progress": chord_seq.size()})
			return
	# Wrong note: Sturdy Strings forgives once per battle, else snap.
	if sturdy_strings and _sturdy_uses > 0:
		_sturdy_uses -= 1
		chord_seq.pop_back()
		events.append({"k": "chord_hold"})
		_log("Sturdy Strings holds! The wrong note does not snap the string.")
	else:
		chord_seq = []
		chord_snapped = true
		events.append({"k": "chord_snap"})
		_log("Wrong note! The string snaps.")


## Complete one or more chords (multi only via Divine Lute power).
## Counts as the turn's single chord completion.
func _complete_chords(matched: Array) -> void:
	chord_seq = []
	chord_completed = true
	var names := []
	for cid in matched:
		names.append(ChordDB.chord_name(str(cid)))
	events.append({"k": "chord_done", "ids": matched})
	_log("♪ %s completed!" % " + ".join(names))
	if game.has_relic("herbal_pouch"):
		_heal_player(2)
		_log("Herbal Pouch: heal 2 HP.")
	# v5.8: LUTE ECHO — chord completion damages ALL enemies
	if _lute_echo_dmg > 0 and not battle_over:
		for i in range(enemies.size()):
			if enemies[i].hp > 0:
				enemies[i].hp = maxi(0, enemies[i].hp - _lute_echo_dmg)
			events.append({"k": "dmg", "n": _lute_echo_dmg, "target": i})
		_log("Lute Echo: ALL enemies lose %d HP!" % _lute_echo_dmg)
		_check_death()
	# v3.4: Divine Lute equipment — completing a chord deals 4 damage to ALL enemies.
	if game.equipment == "divine_lute":
		_damage_all_enemies(4)
		_log("Divine Lute: all enemies lose 4 HP!")
		events.append({"k": "divine_lute"})
	for cid in matched:
		_apply_chord_effect(str(cid))
	_check_death()


func _apply_chord_effect(cid: String) -> void:
	match cid:
		"war_drum":
			_damage_all_enemies(10)
		"lullaby":
			_gain_block(10)
		"charge":
			next_attack_bonus += 10
			_log("CHARGE: your next Attack this turn deals +10 damage.")
		"steadfast":
			draw_cards(2)
		"linked_pearls":
			for h in range(4):
				var alive := []
				for i in range(enemies.size()):
					if enemies[i].hp > 0:
						alive.append(i)
				if alive.is_empty():
					break
				var pick: int = alive[rng.randi_range(0, alive.size() - 1)]
				var keep := target_idx
				target_idx = pick
				_sync_target()
				_damage_enemy(7)
				target_idx = keep
				_sync_target()
		"thunder":
			_damage_enemy(20)
			for i in range(enemies.size()):
				if i != target_idx and enemies[i].hp > 0:
					var keep := target_idx
					target_idx = i
					_sync_target()
					_damage_enemy(8)
					target_idx = keep
					_sync_target()
		"ensemble":
			draw_cards(3)
			_gain_block(5)
		"break_formation":
			for e in enemies:
				if e.hp > 0:
					e.strength -= 3
					e.str_malus += 3
					e.str_malus_turns = 2
			events.append({"k": "break_formation"})
			_log("BREAK FORMATION: all enemies lose 3 Strength for 2 turns.")
		"stillness":
			_heal_player(15)
			_gain_block(15)
		"divine_melody":
			for e in enemies:
				if e.hp > 0:
					e.stunned = true
			events.append({"k": "divine_melody"})
			_log("DIVINE MELODY: all enemies lose their next turn!")
			_heal_player(20)
		"heavens_thunder":
			_damage_enemy(50)


## Learn a chord between battles. Returns true if it was new.
func learn_chord(chord_id: String) -> bool:
	return game.learn_chord(chord_id)


# ------------------------------------------------------------ card math ---

## Pure damage calc for player Attack cards (no side effects).
func calc_attack_damage(base: int, target: Fighter) -> int:
	var dmg := base + player.strength
	if game.has_perk("attack_up"):
		dmg += 2
	if game.has_relic("whetstone"):
		dmg += 1
	if whetstone_turns > 0:
		dmg += whetstone_bonus
	if _charge_active > 0:
		dmg += _charge_active
	if game.has_relic("executioner_hood") and target.hp * 2 <= target.max_hp:
		dmg += 3
		_log("Executioner's Hood: +3 damage to a weakened foe.")
	if player.weak > 0:
		dmg = int(round(dmg * 0.75))
	if target.vulnerable > 0:
		dmg = int(round(dmg * 1.5))
	return maxi(0, dmg)


func _attack_damage(base: int, target: Fighter) -> void:
	var b := base
	# v3.4: Divine Axe — first Attack each turn deals +6 damage.
	if game.equipment == "divine_axe" and not divine_axe_used:
		b += 6
		divine_axe_used = true
		_log("Divine Axe: +6 damage!")
		events.append({"k": "divine_axe"})
	var dmg := calc_attack_damage(b, target)
	_charge_active = 0  # CHARGE is consumed by the first Attack
	_damage_enemy(dmg, true)


func _attack_all(base: int) -> void:
	for i in range(enemies.size()):
		if enemies[i].hp > 0:
			var keep := target_idx
			target_idx = i
			_sync_target()
			_attack_damage(base, enemies[i])
			target_idx = keep
			_sync_target()


# v5.8: attack that ignores enemy Block (EAGLE DIVE)
func _attack_ignore_block(base: int, target: Fighter) -> void:
	var dmg := calc_attack_damage(base, target)
	# Bypass block: damage directly to HP
	target.hp = maxi(0, target.hp - dmg)
	events.append({"k": "dmg", "n": dmg, "target": target_idx, "ignore_block": true})
	_log("Eagle Dive: %d damage (ignores Block)!" % dmg)
	_check_death()


# v5.8: direct HP loss not via attack (LY THONG TRICK)
func _damage_enemy_direct(amount: int) -> void:
	var e := enemy
	if e != null and e.hp > 0:
		e.hp = maxi(0, e.hp - amount)
		events.append({"k": "dmg", "n": amount, "target": target_idx})
		_log("Ly Thong Trick: enemy loses %d HP." % amount)
		_check_death()


# v5.8: remove all player debuffs (PRINCESS BLESSING)
func _cleanse_debuffs() -> void:
	player.weak = 0
	player.vulnerable = 0
	# Add other debuff clears as needed
	events.append({"k": "cleanse"})
	_log("Princess Blessing: all debuffs removed.")


func _gain_block(amount: int) -> void:
	var am := amount
	if game.has_perk("block_up"):
		am += 2
	am = maxi(0, am)
	player.armor += am
	events.append({"k": "block_p", "n": am})
	_log("You gain %d Block." % am)


func _heal_player(amount: int) -> void:
	var h := amount
	if game.has_perk("heal_up"):
		h += 3
	# v3.4: Endless Rice Pot — heals give +6 HP more.
	if game.equipment == "endless_rice_pot":
		h += 6
		_log("Endless Rice Pot: +6 HP!")
	h = maxi(0, h)
	player.hp = mini(player.hp + h, player.max_hp)
	events.append({"k": "heal_p", "n": h})
	_log("You heal %d HP." % h)


func _apply_weak(n: int, all_enemies: bool = false) -> void:
	if all_enemies:
		for e in enemies:
			if e.hp > 0:
				e.weak += n
				events.append({"k": "weak_e", "n": n})
		_log("All enemies gain %d Weak." % n)
	else:
		enemy.weak += n
		events.append({"k": "weak_e", "n": n})
		_log("%s gains %d Weak." % [enemy.name, n])


func _apply_vulnerable(n: int, all_enemies: bool = false) -> void:
	if all_enemies:
		for e in enemies:
			if e.hp > 0:
				e.vulnerable += n
				events.append({"k": "vulnerable_e", "n": n})
		_log("All enemies gain %d Vulnerable." % n)
	else:
		enemy.vulnerable += n
		events.append({"k": "vulnerable_e", "n": n})
		_log("%s gains %d Vulnerable." % [enemy.name, n])


## Preview what a hand card would do if played now.
func preview_card(hand_idx: int) -> Dictionary:
	var out := {"dmg": 0, "heal": 0, "block": 0}
	if hand_idx < 0 or hand_idx >= hand.size():
		return out
	var card: Dictionary = hand[hand_idx]
	var id: String = card.get("id", "")
	var up: bool = card.get("upgraded", false)
	var tgt: Fighter = enemy
	if tgt == null or tgt.hp <= 0:
		return out
	var base := -1
	match id:
		"strike": base = _up(9) if up else 7
		"wood_axe": base = _up(12) if up else 9
		"quick_note": base = _up(4) if up else 3
		"axe_swing": base = _up(9) if up else 7
		"forest_chop": base = _up(18) if up else 14
		"double_cut": base = ((_up(5) if up else 4)) * 2
		"heavy_fell": base = _up(21) if up else 16
		"piercing_melody": base = (_up(12) if up else 9) if chord_completed else (_up(7) if up else 5)
		"thunder_crash": base = _up(10) if up else 8
		"execution": base = _up(29) if up else 22
		"jab": base = _up(4) if up else 3
		"heavy_blow": base = _up(16) if up else 12
		"chain_strike": base = _up(5) if up else 4
		"crippling_blow": base = _up(9) if up else 7
		"pommel_strike": base = _up(7) if up else 5
		"sweeping_cut": base = _up(8) if up else 6
		"maw": base = _up(23) if up else 18
	if base >= 0:
		var raw := calc_attack_damage(base, tgt)
		out["dmg"] = maxi(0, raw - tgt.armor)
	match id:
		"rice_meal": out["heal"] = 8 if up else 6
		"magic_rice_pot": out["heal"] = 16 if up else 12
		"rally": out["heal"] = 10 if up else 8
		"maw": out["heal"] = maxi(1, out["dmg"] / 2)
	if out["heal"] > 0:
		out["heal"] = mini(out["heal"], maxi(0, player.max_hp - player.hp))
	match id:
		"defend": out["block"] = _up(7) if up else 5
		"soft_pluck": out["block"] = _up(4) if up else 3
		"guard_stance": out["block"] = _up(10) if up else 8
		"iron_bark": out["block"] = _up(18) if up else 14
		"deep_breath": out["block"] = _up(5) if up else 4
		"sturdy_defense": out["block"] = _up(12) if up else 9
		"brace": out["block"] = _up(4) if up else 3
		"second_wind": out["block"] = _up(10) if up else 8
		"fortress": out["block"] = _up(26) if up else 20
		"last_stand": out["block"] = mini(16 if up else 12, maxi(0, player.max_hp - player.hp))
	return out


func _complete_chord_instantly() -> void:
	if chord_completed:
		_log("Chord already completed this turn.")
		return
	chord_completed = true
	_log("Chord completed instantly!")
	events.append({"k": "chord_complete"})


func _apply_card_effect(card: Dictionary, ctype: String) -> void:
	var id: String = card["id"]
	var up: bool = card.get("upgraded", false)
	_log("Played %s." % CardDB.card_name(card))
	match id:
		# ---- ATTACK ----
		"strike": _attack_damage(_up(9) if up else 7, enemy)
		"wood_axe": _attack_damage(_up(12) if up else 9, enemy)
		"quick_note": _attack_damage(_up(4) if up else 3, enemy)
		"axe_swing": _attack_damage(_up(9) if up else 7, enemy)
		"forest_chop": _attack_damage(_up(18) if up else 14, enemy)
		"double_cut":
			_attack_damage(_up(5) if up else 4, enemy)
			if not battle_over:
				_attack_damage(_up(5) if up else 4, enemy)
		"heavy_fell": _attack_damage(_up(21) if up else 16, enemy)
		"piercing_melody":
			_attack_damage((_up(12) if up else 9) if chord_completed else (_up(7) if up else 5), enemy)
		"thunder_crash": _attack_all(_up(10) if up else 8)
		"execution": _attack_damage(_up(29) if up else 22, enemy)
		"jab": _attack_damage(_up(4) if up else 3, enemy)
		"heavy_blow": _attack_damage(_up(16) if up else 12, enemy)
		"chain_strike":
			_attack_damage(_up(5) if up else 4, enemy)
			if enemy.hp <= 0 and not battle_over:
				energy += 1
				_log("Chain Strike: +1 energy.")
		"crippling_blow":
			_attack_damage(_up(9) if up else 7, enemy)
			if not battle_over:
				_apply_weak(_up(2) if up else 1)
		"pommel_strike":
			_attack_damage(_up(7) if up else 5, enemy)
			if not battle_over:
				_apply_vulnerable(_up(2) if up else 1)
		"sweeping_cut": _attack_all(_up(8) if up else 6)
		"maw":
			var hp_before := enemy.hp
			_attack_damage(_up(23) if up else 18, enemy)
			var dealt := maxi(0, hp_before - enemy.hp)
			if dealt > 0:
				_heal_player(maxi(1, int(dealt / 2)))
		# --- v5.8 Thach Sanh story exclusives ---
		"python_coil":
			_attack_damage(_up(16) if up else 12, enemy)
			if not battle_over:
				_apply_weak(_up(2) if up else 1)
		"eagle_dive":
			_attack_ignore_block(_up(20) if up else 15, enemy)
		"woodcutter_swing": _attack_damage(_up(11) if up else 8, enemy)
		"thach_demon_slayer":
			_attack_damage(_up(28) if up else 20, enemy)
			# Exhaust: remove from combat (don't go to discard)
			if not battle_over:
				discard_pile.pop_back()  # remove the just-discarded card
				_log("Demon Slayer is exhausted.")
		# --- v5.9 Hai Ba Trung story exclusives ---
		"elephant_charge": _attack_all(_up(19) if up else 14)
		"sisters_fury":
			var bonus := elephant_cards_this_turn * (_up(7) if up else 5)
			_attack_damage((_up(14) if up else 10) + bonus, enemy)
			if bonus > 0:
				_log("Sister's Fury: +%d from Elephant cards this turn!" % bonus)
		"han_slayer": _attack_damage(_up(24) if up else 18, enemy)
		"to_dinh_bane": _attack_damage(_up(34) if up else 25, enemy)
		"stampede":
			_attack_all(_up(11) if up else 8)
			if not battle_over:
				_apply_weak(_up(2) if up else 1, true)
		# ---- SKILL ----
		# --- v5.8 Thach Sanh story exclusives ---
		"rice_pot": _heal_player(_up(12) if up else 8)
		"ly_thong_trick":
			_damage_enemy_direct(_up(8) if up else 5)
			draw_cards(3 if up else 2)
		"princess_blessing":
			_heal_player(_up(15) if up else 10)
			_cleanse_debuffs()
		"stone_dog_guard": _gain_block(_up(16) if up else 12)
		# --- v5.9 Hai Ba Trung story exclusives ---
		"trung_sisters":
			energy += 2
			draw_cards(3 if up else 2)
			_log("Trung Sisters: +2 Energy.")
		"war_drum":
			if has_elephant and elephant != null and elephant.hp > 0:
				_heal_elephant(_up(15) if up else 10)
				trample_bonus += _up(6) if up else 4
				_log("War Drum: next trample +%d damage!" % trample_bonus)
			else:
				_log("War Drum echoes, but the elephant is gone.")
		"spear_wall": _gain_block(_up(20) if up else 15)
		"elephant_armor":
			if has_elephant and elephant != null and elephant.hp > 0:
				elephant.armor += _up(28) if up else 20
				events.append({"k": "block_e", "n": _up(28) if up else 20})
				_log("War Elephant gains %d Block." % (_up(28) if up else 20))
			else:
				_log("No elephant to armor.")
		"rice_provision":
			_heal_player(_up(16) if up else 12)
			_heal_elephant(_up(16) if up else 12)
		"bamboo_spike": _gain_block(_up(11) if up else 8)
		"rebel_cry":
			player.strength += _up(3) if up else 2
			events.append({"k": "str_p", "n": _up(3) if up else 2})
			_log("Rebel Cry: +%d Strength!" % (_up(3) if up else 2))
		"victory_horn":
			if has_elephant and elephant != null and elephant.hp > 0:
				_elephant_trample()
				if up and not battle_over:
					draw_cards(1)
			else:
				_log("Victory Horn sounds, but the elephant is gone.")
		"defend": _gain_block(_up(7) if up else 5)
		"grace_note": draw_cards(2 if up else 1)
		"take_breath":
			energy += 1
			_log("+1 energy.")
			draw_cards(2 if up else 1)
		"soft_pluck": _gain_block(_up(4) if up else 3)
		"tune_up": draw_cards(3 if up else 2)
		"rice_meal": _heal_player(_up(8) if up else 6)
		"guard_stance": _gain_block(_up(10) if up else 8)
		"iron_bark": _gain_block(_up(18) if up else 14)
		"deep_breath":
			_gain_block(_up(5) if up else 4)
			draw_cards(1)
		"sturdy_defense": _gain_block(_up(12) if up else 9)
		"battle_shout":
			player.strength += _up(3) if up else 2
			events.append({"k": "strength_p", "n": _up(3) if up else 2})
			_log("You gain %d Strength." % (_up(3) if up else 2))
		"lullaby_hum": _apply_weak(_up(3) if up else 2)
		"magic_rice_pot": _heal_player(_up(16) if up else 12)
		"sorrowful_tune": _apply_weak(_up(3) if up else 2, true)
		"victory_song": draw_cards(3 if up else 2)
		"encore": draw_cards((4 if chord_completed else 3) if up else (3 if chord_completed else 2))
		"brace": _gain_block(_up(4) if up else 3)
		"mark": _apply_vulnerable(_up(2) if up else 1)
		"quick_step": draw_cards(2 if up else 1)
		"sharpen":
			player.strength += _up(3) if up else 2
			events.append({"k": "strength_p", "n": _up(3) if up else 2})
			_log("You gain %d Strength." % (_up(3) if up else 2))
		"war_chant":
			player.strength += _up(3) if up else 2
			events.append({"k": "strength_p", "n": _up(3) if up else 2})
			draw_cards(1)
		"blood_draw":
			draw_cards(4 if up else 3)
			_damage_player(3)
			_log("Blood Draw: lose 3 HP.")
		"second_wind":
			_gain_block(_up(10) if up else 8)
			draw_cards(1)
		"expose": _apply_vulnerable(_up(3) if up else 2)
		"last_stand":
			_gain_block(mini(_up(16) if up else 12, maxi(0, player.max_hp - player.hp)))
		"trung_last_stand":
			if player.hp < player.max_hp * 0.5:
				_gain_block(_up(28) if up else 20)
				energy += _up(4) if up else 3
				_log("Last Stand: +%d Block, +%d Energy!" % [_up(28) if up else 20, _up(4) if up else 3])
			else:
				_gain_block(_up(10) if up else 6)
				_log("Last Stand: HP too high for full effect.")
		"focus":
			player.strength += _up(4) if up else 3
			events.append({"k": "strength_p", "n": _up(4) if up else 3})
			_log("You gain %d Strength." % (_up(4) if up else 3))
		"rally":
			_heal_player(_up(10) if up else 8)
			draw_cards(1)
		"fortress": _gain_block(_up(26) if up else 20)
		# ---- POWER (grace notes: stay in play for the battle) ----
		# --- v5.8 Thach Sanh story exclusives ---
		"lute_echo":
			powers_in_play.append("lute_echo")
			_lute_echo_dmg = 5 if up else 3
			events.append({"k": "power_p", "id": "lute_echo"})
			_log("LUTE ECHO: chord completions deal %d to ALL enemies." % _lute_echo_dmg)
		"magic_lute_song":
			powers_in_play.append("magic_lute_song")
			_chord_discount = 1
			if up:
				energy += 1
			events.append({"k": "power_p", "id": "magic_lute_song"})
			_log("MAGIC LUTE SONG: chords need 1 fewer note.")
		# --- v5.9 Hai Ba Trung story exclusives ---
		"me_linh_oath":
			powers_in_play.append("me_linh_oath")
			me_linh_heal = _up(5) if up else 3
			events.append({"k": "power_p", "id": "me_linh_oath"})
			_log("ME LINH OATH: War Elephant heals %d HP each turn." % me_linh_heal)
		"sturdy_strings":
			sturdy_strings = true
			_sturdy_uses = 2 if up else 1
			powers_in_play.append("sturdy_strings")
			events.append({"k": "power_p", "id": "sturdy_strings"})
			_log("STURDY STRINGS: your first wrong note each battle will not snap the string.")
		"divine_lute":
			divine_lute = true
			powers_in_play.append("divine_lute")
			events.append({"k": "power_p", "id": "divine_lute"})
			_log("DIVINE LUTE: your 3-note chords need only 2 notes.")

		# ---- LEGENDARY (NEW) ----
		"demon_slayer": _attack_damage(_up(45) if up else 35, enemy)
		"storm_wings":
			for i in range(3):
				if battle_over: break
				_attack_all(_up(11) if up else 8)
		"heros_legacy":
			_gain_block(_up(28) if up else 20)
			_complete_chord_instantly()
		"thunder_hammer":
			_attack_damage(_up(32) if up else 25, enemy)
			if not battle_over:
				_apply_vulnerable(_up(4) if up else 3)
		"celestial_army":
			_gain_block(_up(20) if up else 15)
			_attack_all(_up(20) if up else 15)
		"dragons_heart":
			_heal_player(_up(20) if up else 15)
			energy += _up(3) if up else 2
			_log("+%d energy." % (_up(3) if up else 2))
		"fox_fire":
			_attack_damage(_up(15) if up else 12, enemy)
			if not battle_over:
				_attack_damage(_up(15) if up else 12, enemy)
			if not battle_over:
				_apply_vulnerable(_up(3) if up else 2)
		"mountains_embrace":
			_gain_block(_up(40) if up else 30)
			_gain_block(_up(4) if up else 3)  # plated as bonus block
		"fates_thread":
			draw_cards(_up(6) if up else 5)
			_cost_reduction = 1
			_log("All cards cost 1 less this turn.")
		"apocalypse":
			_attack_damage(_up(65) if up else 50, enemy)
			_complete_chord_instantly()
		# ---- MYTHIC (NEW) ----
		"thunder_strike":
			var bonus := (_up(12) if up else 8) if chord_completed else 0
			_attack_damage((_up(24) if up else 18) + bonus, enemy)
		"iron_wall":
			_gain_block(_up(22) if up else 16)
			draw_cards(_up(3) if up else 2)
		"heavens_grace":
			_heal_player(_up(12) if up else 8)
			draw_cards(_up(2) if up else 1)
		"twin_dragons":
			_attack_damage(_up(16) if up else 12, enemy)
			if not battle_over:
				_attack_damage(_up(16) if up else 12, enemy)
		"phoenix_rebirth":
			_heal_player(_up(16) if up else 12)
			_gain_block(_up(16) if up else 12)
		"lightning_chain":
			var hp_before := 0
			for e in enemies:
				hp_before += e.hp
			_attack_all(_up(14) if up else 10)
			var killed := false
			for e in enemies:
				if e.hp <= 0 and e.max_hp > 0:
					killed = true
			if killed and not battle_over:
				_attack_all(_up(14) if up else 10)
				_log("Lightning Chain repeats!")
		"sages_wisdom":
			draw_cards(_up(4) if up else 3)
			energy += 1
			_log("+1 energy.")
		"tigers_fury":
			for i in range(3):
				if battle_over: break
				_attack_damage(_up(11) if up else 8, enemy)
		"turtles_shell": _gain_block(_up(28) if up else 20)
		"cranes_dance":
			energy += _up(3) if up else 2
			_log("+%d energy." % (_up(3) if up else 2))
			draw_cards(2)
		"volcano":
			_attack_all(_up(20) if up else 15)
			_apply_vulnerable(_up(3) if up else 2, true)
		"monsoon_shield":
			_gain_block(_up(16) if up else 12)
			player.weak = 0
			player.vulnerable = 0
			_log("Debuffs cleansed.")
		"ancestors_blessing":
			player.strength += _up(8) if up else 5
			events.append({"k": "strength_p", "n": _up(8) if up else 5})
		"serpents_coil":
			_attack_damage(_up(18) if up else 14, enemy)
			if not battle_over:
				_apply_vulnerable(_up(4) if up else 3)
				_apply_weak(_up(3) if up else 2)
		"moonlit_sonata":
			_gain_block(_up(14) if up else 10)
			draw_cards(_up(3) if up else 2)
			_heal_player(_up(8) if up else 5)

		# ---- RARE (NEW) ----
		"executioners_axe":
			var dmg := _up(22) if up else 16
			if enemy.hp < enemy.max_hp / 2:
				dmg *= 2
				_log("Execution!")
			_attack_damage(dmg, enemy)
		"bastion":
			var bonus := skills_played_this_turn * (_up(6) if up else 4)
			_gain_block((_up(18) if up else 14) + bonus)
		"bloodlust":
			player.strength += _up(6) if up else 4
			bloodlust_hits = 3
			events.append({"k": "strength_p", "n": _up(6) if up else 4})
		"whirlwind":
			_attack_all(_up(8) if up else 6)
			if not battle_over:
				_attack_all(_up(8) if up else 6)
		"meditation":
			energy += 2
			_log("+2 energy.")
			draw_cards(_up(2) if up else 1)
			_heal_player(-3)
		"piercing_arrow": _attack_damage(_up(26) if up else 20, enemy)  # ignores block via direct hp
		"stone_skin":
			_gain_block(_up(11) if up else 8)
			_gain_block(_up(3) if up else 2)
		"frenzy":
			_attack_damage(_up(8) if up else 5, enemy)
			frenzy_replay = true
		"tactical_retreat":
			_gain_block(_up(14) if up else 10)
			draw_cards(2)
			# discard 1 handled by UI
		"venom_blade":
			_attack_damage(_up(11) if up else 8, enemy)
			if not battle_over:
				_apply_vulnerable(_up(6) if up else 4)
		"war_drums":
			energy += 1
			next_chord_bonus = _up(15) if up else 10
			_log("Next chord +%d damage." % next_chord_bonus)
		"guardian_spirit":
			_gain_block(_up(16) if up else 12)
			_heal_player(_up(9) if up else 6)
		"meteor_fall": _attack_damage(_up(36) if up else 28, enemy)
		"shadow_step":
			_gain_block(_up(9) if up else 6)
			draw_cards(_up(2) if up else 1)
		"rallying_cry":
			draw_cards(_up(4) if up else 3)
		"earthquake":
			_attack_all(_up(16) if up else 12)
			_apply_weak(_up(2) if up else 1, true)
		# ---- UNCOMMON (NEW) ----
		"heavy_smash": _attack_damage(_up(18) if up else 14, enemy)
		"quick_guard": _gain_block(_up(7) if up else 4)
		"double_strike":
			_attack_damage(_up(7) if up else 5, enemy)
			if not battle_over:
				_attack_damage(_up(7) if up else 5, enemy)
		"battle_focus": draw_cards(_up(3) if up else 2)
		"cleave": _attack_all(_up(14) if up else 10)
		"reinforce": _gain_block(_up(12) if up else 9)
		"poison_dart":
			_attack_damage(_up(8) if up else 6, enemy)
			if not battle_over:
				_apply_vulnerable(_up(4) if up else 3)
		"renewed_vigor":
			_heal_player(_up(9) if up else 6)
			_gain_block(_up(9) if up else 6)
		"swift_melody":
			draw_cards(_up(2) if up else 1)
			energy += 1
		"crushing_blow":
			_attack_damage(_up(16) if up else 12, enemy)
			if not battle_over:
				_apply_vulnerable(_up(2) if up else 1)
		"barrier": _gain_block(_up(17) if up else 13)
		_:
			_log("Nothing happens. (unimplemented: %s)" % id)


# ------------------------------------------- Divine Artifacts (v3.4, passive) ---
## Artifacts are PASSIVE — always on, no activation. The EQUIP slot shows the
## artifact icon; tapping it opens an inspect popup (see battle_screen).

func artifact_name() -> String:
	var d: Dictionary = GameState.EQUIPMENT.get(game.equipment, {})
	return str(d.get("name", "None"))


func artifact_desc() -> String:
	var d: Dictionary = GameState.EQUIPMENT.get(game.equipment, {})
	return str(d.get("desc", "No artifact equipped."))
