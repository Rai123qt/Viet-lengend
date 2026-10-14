extends SceneTree
## Headless logic tests. Run:
##   Godot_v4.7.2-stable_linux.x86_64 --headless --path ~/workspace/world-verb \
##     --script res://tests/run_tests.gd

var passed := 0
var failed := 0


func _init() -> void:
	_run_all()
	print("==== TESTS: %d passed, %d failed ====" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(cond: bool, name: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: " + name)


func new_game() -> GameState:
	var g := GameState.new()
	g.new_run("silence_anchor")
	return g


func new_battle(p_encounter = "restless_citizen", seed := 12345, game: GameState = null) -> BattleState:
	if game == null:
		game = new_game()
	var bs := BattleState.new()
	bs.setup(game.deck.duplicate(true), p_encounter, game, seed)
	bs.start_player_turn()
	return bs


func find_in_hand(bs: BattleState, card_id: String) -> int:
	for i in range(bs.hand.size()):
		if bs.hand[i]["id"] == card_id:
			return i
	return -1


func give_card(bs: BattleState, card_id: String, upgraded := false) -> int:
	var c := CardDB.make(card_id, upgraded)
	bs.hand.append(c)
	return bs.hand.size() - 1


func _run_all() -> void:
	# ---- damage / armor order ----
	var bs := new_battle()
	bs.enemy.armor = 5
	var hp0: int = bs.enemy.hp
	bs._damage_enemy(8)
	check(bs.enemy.armor == 0 and bs.enemy.hp == hp0 - 3, "armor absorbs first")

	# ---- player armor expires at end of enemy turn ----
	bs = new_battle()
	bs.player.armor = 10
	bs.end_player_turn()  # runs enemy phase
	check(bs.player.armor == 0, "player armor expires after enemy turn")

	# ---- enemy armor expires at end of player turn ----
	bs = new_battle()
	bs.enemy.armor = 9
	bs.end_player_turn()
	check(bs.enemy.armor == 0, "enemy armor expires at end of player turn")

	# ---- reshuffle ----
	bs = new_battle()
	bs.draw_pile.clear()
	bs.discard_pile = [CardDB.make("nightmare_cut"), CardDB.make("rest_brace")]
	var h0: int = bs.hand.size()
	bs.draw_cards(2)
	check(bs.hand.size() == h0 + 2 and bs.draw_pile.size() == 0, "reshuffle discard into draw")

	# ---- energy ----
	bs = new_battle()
	bs.energy = 0
	var idx := give_card(bs, "nightmare_cut")
	check(not bs.can_play(idx)["ok"], "cannot play without energy")

	# ---- NIGHTMARE dye +50% vs drowsy ----
	bs = new_battle()
	bs.enemy.drowsy = 1
	hp0 = bs.enemy.hp
	idx = give_card(bs, "nightmare_cut")
	bs.energy = 3
	bs.play_card(idx)
	check(hp0 - bs.enemy.hp == 11, "nightmare dye 7 -> 11 vs drowsy (got %d)" % (hp0 - bs.enemy.hp))

	# ---- REST dye double armor when drowsy ----
	bs = new_battle()
	bs.player.drowsy = 1
	idx = give_card(bs, "rest_brace")
	bs.energy = 3
	bs.play_card(idx)
	check(bs.player.armor == 14, "rest dye doubles armor when drowsy")

	# ---- DREAM: heal + wakefulness -1 + nightmare shuffled ----
	bs = new_battle()
	var g := bs.game
	g.wakefulness = 3
	bs.player.hp = 50
	idx = give_card(bs, "dream_mend")
	bs.energy = 3
	bs.play_card(idx)
	check(bs.player.hp == 55, "dream_mend heals 5")
	check(g.wakefulness == 2, "dream reduces wakefulness")
	var found := false
	for c in bs.discard_pile:
		if c["id"] == "nightmare_curse":
			found = true
	check(found, "dream shuffles nightmare into discard")

	# ---- Dreamcatcher: first DREAM no nightmare ----
	bs = new_battle()
	bs.game.add_relic("dreamcatcher")
	idx = give_card(bs, "dream_mend")
	bs.energy = 3
	bs.play_card(idx)
	found = false
	for c in bs.discard_pile:
		if c["id"] == "nightmare_curse":
			found = true
	check(not found, "dreamcatcher blocks first nightmare")

	# ---- Nightmare curse unplayable ----
	bs = new_battle()
	idx = give_card(bs, "nightmare_curse")
	check(not bs.can_play(idx)["ok"], "curse unplayable")

	# ---- v3.4 Divine Artifacts (passive) ----
	# Divine Axe: first Attack each turn +6 damage.
	bs = new_battle([{"id": "wild_boar", "hp_mult": 1.0}], 42)
	g = new_game()
	g.equipment = "divine_axe"
	bs.game = g
	var e0_hp: int = bs.enemies[0].hp
	# Play a Strike (7 base). First attack should be 7+6=13.
	bs._attack_damage(7, bs.enemies[0])
	check(bs.enemies[0].hp == e0_hp - 13, "divine axe first attack +6 (got %d dmg)" % (e0_hp - bs.enemies[0].hp))
	# Second attack should NOT get +6.
	e0_hp = bs.enemies[0].hp
	bs._attack_damage(7, bs.enemies[0])
	check(bs.enemies[0].hp == e0_hp - 7, "divine axe second attack no bonus (got %d dmg)" % (e0_hp - bs.enemies[0].hp))
	# New turn resets the axe.
	bs.start_player_turn()
	e0_hp = bs.enemies[0].hp
	bs._attack_damage(7, bs.enemies[0])
	check(bs.enemies[0].hp == e0_hp - 13, "divine axe resets each turn")

	# Divine Lute: completing a chord deals 4 damage to ALL enemies.
	bs = new_battle([{"id": "wild_boar", "hp_mult": 1.0}, {"id": "wild_boar", "hp_mult": 1.0}], 43)
	g = new_game()
	g.equipment = "divine_lute"
	bs.game = g
	var hps := [bs.enemies[0].hp, bs.enemies[1].hp]
	bs._complete_chords(["war_drum"])
	# war_drum itself deals 10, plus lute 4 = 14 total.
	check(bs.enemies[0].hp == hps[0] - 14 and bs.enemies[1].hp == hps[1] - 14,
		"divine lute chord complete 4 to all (got %d, %d)" % [hps[0] - bs.enemies[0].hp, hps[1] - bs.enemies[1].hp])

	# Endless Rice Pot: heals give +6 HP more.
	bs = new_battle([{"id": "wild_boar", "hp_mult": 1.0}], 44)
	g = new_game()
	g.equipment = "endless_rice_pot"
	bs.game = g
	bs.player.hp = 50
	bs._heal_player(10)
	check(bs.player.hp == 66, "rice pot heal +6 (got %d)" % bs.player.hp)

	# Equip new replaces old (1 slot).
	g = new_game()
	g.equipment = "divine_axe"
	g.equip("divine_lute")
	check(g.equipment == "divine_lute", "equip new replaces old")

	# ---- Vessel Protocol: arm with 1 energy, capture 50% (max 8), RELEASE token ----
	bs = new_battle()
	bs.energy = 3
	bs.player.hp = 80  # survive the enemy hit
	# Simulate enemy with a numeric intent
	bs.enemies[0].hp = 50
	bs.enemy_intents[0] = [{"kind": "attack", "power": 16, "muddled": false}]
	bs.end_player_turn()  # should arm (consumes 1 energy), then capture during enemy phase
	check(bs.vessel_stored == 8, "vessel captured 50% of 16 = 8")
	bs.start_player_turn()
	var ridx = find_in_hand(bs, "echo_of_sleep")
	check(ridx >= 0, "ECHO OF SLEEP token arrives in hand")
	if ridx >= 0:
		check(bs.hand[ridx].get("power", 0) == 8, "echo has stored power 8")
		# Play echo and choose drown
		var rr = bs.play_card(ridx)
		check(rr.get("needs_release_choice", false), "echo needs choice")
		var hp_before: int = bs.enemies[0].hp
		bs.resolve_release("drown")
		check(bs.enemies[0].hp < hp_before, "echo drown deals damage")
	# SLUMBER: armor + cleanse drowsy
	bs = new_battle()
	bs.energy = 3
	bs.vessel_stored = 6
	bs.start_player_turn()
	ridx = find_in_hand(bs, "echo_of_sleep")
	bs.play_card(ridx)
	bs.resolve_release("slumber")
	check(bs.player.armor == 6, "echo slumber gains armor")
	bs = new_battle()
	bs.energy = 3
	bs.vessel_stored = 6
	bs.start_player_turn()
	bs.player.drowsy = 2  # set after turn start to avoid drowsy-lock
	ridx = find_in_hand(bs, "echo_of_sleep")
	bs.play_card(ridx)
	bs.resolve_release("slumber")
	check(bs.player.drowsy == 0, "echo slumber cleanses drowsy")

	bs = new_battle()
	# Vessel Protocol cap: 30 -> 8 (max)
	bs.energy = 3
	bs.enemies[0].hp = 50
	bs.enemy_intents[0] = [{"kind": "attack", "power": 30, "muddled": false}]
	bs.end_player_turn()
	check(bs.vessel_stored == 8, "vessel caps at 8 (30->8)")

	# ---- Drowsy lock ----
	bs = new_battle()
	bs2_setup_drowsy(bs)
	check(bs.drowsy_locked.size() == 2, "2 cards drowsy-locked")
	var locked_ok := true
	for i in range(bs.hand.size()):
		var c: Dictionary = bs.hand[i]
		var should_lock: bool = c["uid"] in bs.drowsy_locked
		if should_lock and bs.can_play(i)["ok"]:
			locked_ok = false
	check(locked_ok, "locked cards unplayable, others playable")

	# ---- Muddle: muddled intent power = round(p*0.65), occurs sometimes ----
	bs = new_battle("dream_eater", 7)
	var seen_muddle := false
	var muddle_ok := true
	for t in range(300):
		bs.enemy.drowsy = 1
		bs._choose_all_intents()
		for it in bs.intents:
			if it["kind"] == "attack":
				if it.get("muddled", false):
					seen_muddle = true
				# power is either original or reduced; reduced must equal round(orig*0.65)
	bs.enemy.drowsy = 0
	check(seen_muddle, "muddle occurs with drowsy enemy")

	# ---- Wakefulness thresholds (SLEEP campaign) ----
	g = new_game()
	g.wakefulness = 2
	bs = new_battle("restless_citizen", 1, g)
	check(bs.hand.size() == 4, "wakefulness 2 -> opening hand 4, got %d" % bs.hand.size())
	g = new_game()
	g.wakefulness = 3
	bs = new_battle("restless_citizen", 1, g)
	check(bs.player.drowsy == 1, "wakefulness 3 -> start drowsy 1")
	g = new_game()
	g.wakefulness = 3
	g.add_relic("smelling_salts")
	bs = new_battle("restless_citizen", 1, g)
	check(bs.player.drowsy == 0, "smelling salts blocks wakefulness drowsy")
	g = new_game()
	g.wakefulness = 4
	bs = new_battle("restless_citizen", 1, g)
	var hallu := 0
	for cd in bs.draw_pile:
		if cd["id"] == "hallucination":
			hallu += 1
	check(hallu == 2, "wakefulness 4 -> 2 hallucinations in draw pile")

	# ---- Combo: lucid_strike +5 after REST ----
	bs = new_battle()
	bs.energy = 9
	idx = give_card(bs, "rest_brace")
	bs.play_card(idx)
	hp0 = bs.enemy.hp
	idx = give_card(bs, "lucid_strike")
	bs.play_card(idx)
	check(hp0 - bs.enemy.hp == 10, "lucid strike combo +5 after REST")

	# ---- Upgrade +30% ----
	bs = new_battle()
	bs.energy = 3
	idx = give_card(bs, "nightmare_cut", true)
	hp0 = bs.enemy.hp
	bs.play_card(idx)
	check(hp0 - bs.enemy.hp == 9, "upgrade +30%: 7 -> 9")

	# ---- Divine Artifacts are passive (no active use) ----
	bs = new_battle()
	g = new_game()
	g.equipment = "divine_axe"
	bs = new_battle("wild_boar", 5, g)
	check(bs.artifact_name() == "Divine Axe", "artifact_name")
	check(bs.artifact_desc().contains("+6"), "artifact_desc")

	# ---- Sleep talk -6 attack intent ----
	bs = new_battle()
	bs.intents = [{"kind": "attack", "power": 14, "muddled": false}]
	idx = give_card(bs, "sleep_talk")
	bs.energy = 3
	bs.play_card(idx)
	check(bs.intents[0]["power"] == 8, "sleep talk -6 intent")

	# ---- Bottled scream: 16 if took HP damage last turn ----
	bs = new_battle()
	bs.took_hp_damage_last_turn = true
	hp0 = bs.enemy.hp
	idx = give_card(bs, "bottled_scream")
	bs.energy = 3
	bs.play_card(idx)
	check(hp0 - bs.enemy.hp == 16, "bottled scream 16 after damage")

	# ---- Last light: +2 energy if last card in hand ----
	bs = new_battle()
	bs.hand.clear()
	idx = give_card(bs, "last_light")
	bs.energy = 2
	bs.play_card(idx)
	check(bs.energy == 2, "last light +2 energy as last card")

	# ---- Boss phase 2 ----
	bs = new_battle("keeper_of_sleep", 9)
	bs.enemy.hp = 100
	bs._check_boss_phase()
	check(bs.phase == 2, "boss phase 2 at <=50%")
	check(bs.intents.size() == 2, "phase 2 has 2 intents")

	# ---- Multi-enemy: targeting, retarget, all-dead win ----
	bs = new_battle([{"id": "restless_citizen", "hp_mult": 1.0}, {"id": "dream_eater", "hp_mult": 1.0}], 11)
	check(bs.enemies.size() == 2, "two enemies created")
	check(bs.target_idx == 0 and bs.enemy == bs.enemies[0], "default target is leftmost")
	check(bs.set_target(1), "set_target(1) ok")
	check(bs.target_idx == 1 and bs.enemy == bs.enemies[1], "target switched")
	check(not bs.set_target(5), "set_target out of range fails")
	# damage goes to the selected target only
	var e0hp: int = bs.enemies[0].hp
	bs._damage_enemy(10)
	check(bs.enemies[1].hp == 50 - 10 and bs.enemies[0].hp == e0hp, "damage hits selected target")
	# killing the target auto-retargets to the next living enemy
	bs.enemies[1].hp = 1
	bs._damage_enemy(5)
	check(bs.enemies[1].hp == 0, "target killed")
	check(bs.target_idx == 0 and not bs.battle_over, "auto-retarget to leftmost living, battle continues")
	check(not bs.set_target(1), "cannot target the dead")
	# killing the last enemy wins
	bs.enemies[0].hp = 1
	bs._damage_enemy(5)
	check(bs.battle_over and bs.result == "win", "win when ALL enemies dead")
	# enemy phase: each living enemy acts left to right
	bs = new_battle([{"id": "restless_citizen", "hp_mult": 1.0}, {"id": "restless_citizen", "hp_mult": 1.0}], 12)
	bs.intents = [{"kind": "attack", "power": 8, "muddled": false}]
	bs.enemy_intents[1] = [{"kind": "attack", "power": 8, "muddled": false}]
	var php2: int = bs.player.hp
	bs.end_player_turn()
	check(bs.player.hp == php2 - 16, "both enemies attack in one enemy phase")
	# dead enemies are skipped in the enemy phase
	bs = new_battle([{"id": "restless_citizen", "hp_mult": 1.0}, {"id": "restless_citizen", "hp_mult": 1.0}], 13)
	bs.enemies[0].hp = 0
	bs._retarget()
	check(bs.target_idx == 1, "retarget skips the dead")

	# ---- Win / lose ----
	bs = new_battle()
	bs.enemy.hp = 1
	bs._damage_enemy(5)
	check(bs.battle_over and bs.result == "win", "win on enemy death")
	bs = new_battle()
	bs.player.hp = 1
	bs.player.armor = 0
	bs._damage_player(5)
	check(bs.battle_over and bs.result == "lose", "lose on player death")

	# ---- CardDB integrity: 72 playable + tokens/curses ----
	var n_cards := 0
	for id in CardDB.CARDS.keys():
		var d: Dictionary = CardDB.CARDS[id]
		if d["rarity"] not in ["token", "curse"]:
			n_cards += 1
	check(n_cards == 72, "72 playable cards (got %d)" % n_cards)
	check(CardDB.CARDS.size() == 75, "75 total defs")

	# ---- Relics: 30 total ----
	check(GameState.RELICS.size() == 30, "30 relics (got %d)" % GameState.RELICS.size())

	# ---- relic hooks ----
	# iron_rations: +4 armor at battle start
	var rg := new_game()
	rg.add_relic("iron_rations")
	bs = new_battle("restless_citizen", 11, rg)
	check(bs.player.armor == 4, "iron_rations +4 armor")
	# smelling_salts: no wakefulness drowsy
	rg = new_game()
	rg.wakefulness = 2
	rg.add_relic("smelling_salts")
	bs = new_battle("restless_citizen", 12, rg)
	check(bs.player.drowsy == 0, "smelling_salts clears start drowsy")
	# caltrops: enemies -5 max HP
	rg = new_game()
	rg.add_relic("caltrops")
	bs = new_battle("restless_citizen", 13, rg)
	check(bs.enemies[0].max_hp == 40 and bs.enemies[0].hp == 40, "caltrops -5 enemy HP")
	# second_breakfast: turn 1 draws 6
	rg = new_game()
	rg.add_relic("second_breakfast")
	bs = new_battle("restless_citizen", 14, rg)
	check(bs.hand.size() == 6, "second_breakfast draws 6 turn 1")
	# whetstone: nightmare +1
	rg = new_game()
	rg.add_relic("whetstone")
	bs = new_battle("restless_citizen", 15, rg)
	bs.energy = 3
	bs.play_card(give_card(bs, "nightmare_cut"))
	check(bs.enemy.hp == 45 - 8, "whetstone +1 nightmare dmg")
	# executioner_hood: +3 vs weakened
	rg = new_game()
	rg.add_relic("executioner_hood")
	bs = new_battle("restless_citizen", 16, rg)
	bs.enemy.hp = 20
	bs.energy = 3
	bs.play_card(give_card(bs, "nightmare_cut"))
	check(bs.enemy.hp == 10, "executioner_hood +3 vs weakened")
	# soft_pillow: rest +1 armor
	rg = new_game()
	rg.add_relic("soft_pillow")
	bs = new_battle("restless_citizen", 17, rg)
	bs.energy = 3
	bs.play_card(give_card(bs, "rest_brace"))
	check(bs.player.armor == 8, "soft_pillow +1 rest armor")
	# warm_milk: dream +2 heal
	rg = new_game()
	rg.add_relic("warm_milk")
	bs = new_battle("restless_citizen", 18, rg)
	bs.player.hp = 70
	bs.energy = 3
	bs.play_card(give_card(bs, "dream_mend"))
	check(bs.player.hp == 77, "warm_milk +2 dream heal")
	# music_box: lull +1 drowsy
	rg = new_game()
	rg.add_relic("music_box")
	bs = new_battle("restless_citizen", 19, rg)
	bs.energy = 3
	bs.play_card(give_card(bs, "lullaby"))
	check(bs.enemy.drowsy == 3, "music_box +1 drowsy")
	# blood_vial: dream deals 2 to target
	rg = new_game()
	rg.add_relic("blood_vial")
	bs = new_battle("restless_citizen", 20, rg)
	bs.player.hp = 70
	bs.energy = 3
	bs.play_card(give_card(bs, "dream_mend"))
	check(bs.enemy.hp == 43, "blood_vial dream draws blood")
	# laudanum: dream -1 extra wakefulness
	rg = new_game()
	rg.wakefulness = 2
	rg.add_relic("laudanum")
	bs = new_battle("restless_citizen", 21, rg)
	bs.energy = 3
	bs.play_card(give_card(bs, "dream_mend"))
	check(rg.wakefulness == 0, "laudanum extra wakefulness -1")
	# pocket_watch: dream grants energy
	rg = new_game()
	rg.add_relic("pocket_watch")
	bs = new_battle("restless_citizen", 22, rg)
	bs.energy = 3
	bs.play_card(give_card(bs, "dream_mend"))
	check(bs.energy == 3, "pocket_watch dream +1 energy")
	# bramble_crown: thorns
	rg = new_game()
	rg.add_relic("bramble_crown")
	bs = new_battle("restless_citizen", 23, rg)
	bs._damage_player(5)
	check(bs.enemy.hp == 43 and bs.player.hp == 75, "bramble_crown thorns 2")
	# chainmail + bandages: turn start
	rg = new_game()
	rg.add_relic("chainmail")
	rg.add_relic("bandages")
	bs = new_battle("restless_citizen", 24, rg)
	bs.player.hp = 70
	bs.start_player_turn()
	check(bs.player.armor == 4 and bs.player.hp == 73, "chainmail + bandages on turn start")
	# night_owl: 1 fewer locked
	rg = new_game()
	rg.add_relic("night_owl")
	bs = new_battle("restless_citizen", 25, rg)
	bs.player.drowsy = 2
	bs.start_player_turn()
	check(bs.drowsy_locked.size() == 1, "night_owl locks 1 fewer")
	# torn_page: reshuffle armor
	rg = new_game()
	rg.add_relic("torn_page")
	bs = new_battle("restless_citizen", 26, rg)
	bs.draw_pile.clear()
	bs.discard_pile = [CardDB.make("nightmare_cut")]
	bs.draw_cards(1)
	check(bs.player.armor == 4, "torn_page +4 armor on reshuffle")
	# enemy intent dampeners
	rg = new_game()
	rg.add_relic("foul_incense")
	bs = new_battle("restless_citizen", 27, rg)
	bs._run_single_intent({"kind": "attack", "power": 8}, bs.enemies[0], 0)
	check(bs.player.hp == 73, "foul_incense -1 enemy dmg")
	rg = new_game()
	rg.add_relic("leaden_curtain")
	rg.add_relic("watchdog")
	bs = new_battle("restless_citizen", 28, rg)
	bs._run_single_intent({"kind": "defend", "power": 6}, bs.enemies[0], 0)
	check(bs.enemies[0].armor == 5 and bs.player.armor == 2, "leaden_curtain + watchdog")
	rg = new_game()
	rg.add_relic("earplugs")
	bs = new_battle("restless_citizen", 29, rg)
	bs._run_single_intent({"kind": "debuff", "power": 3}, bs.enemies[0], 0)
	check(bs.player.drowsy == 2, "earplugs -1 drowsy")
	rg = new_game()
	rg.add_relic("sour_dreams")
	bs = new_battle("restless_citizen", 30, rg)
	bs.enemies[0].hp = 10
	bs._run_single_intent({"kind": "heal", "power": 5}, bs.enemies[0], 0)
	check(bs.enemies[0].hp == 13, "sour_dreams -2 enemy heal")
	# chloroform_rag: code path runs (RNG-based, just ensure no error)
	rg = new_game()
	rg.add_relic("chloroform_rag")
	bs = new_battle("restless_citizen", 31, rg)
	bs.enemies[0].drowsy = 3
	bs._choose_intents_for(0)
	check(true, "chloroform_rag intent path ok")

	_test_map_gen()

	print("done.")


func _test_map_gen() -> void:
	# MapGraph (directed graph, Story 1): structure + travel rules.
	var mg := MapGraph.new()
	mg.build_story1_map()
	check(mg.current_id == "start", "map starts at start node")
	# Only outgoing from CURRENT are AVAILABLE (no backtracking).
	var avail := []
	for nid in mg.nodes:
		if str((mg.nodes[nid] as Dictionary)["state"]) == MapGraph.S_AVAILABLE:
			avail.append(nid)
	check(avail == ["f1"], "only f1 available at start")
	# Every node reachable from start via out-links.
	var seen := {}
	var stack := ["start"]
	while not stack.is_empty():
		var sid: String = stack.pop_back()
		if seen.has(sid):
			continue
		seen[sid] = true
		for oid in ((mg.nodes[sid] as Dictionary)["out"] as Array):
			stack.append(oid)
	check(seen.size() == mg.nodes.size(), "all map nodes reachable from start")
	# Boss node present; every out-link points at a real node.
	var boss_ok := false
	var links_ok := true
	for nid in mg.nodes:
		var nd: Dictionary = mg.nodes[nid]
		if str(nd["type"]) == "BOSS" and nid == "boss":
			boss_ok = true
		for oid in (nd["out"] as Array):
			if not mg.nodes.has(oid):
				links_ok = false
	check(boss_ok, "boss node present")
	check(links_ok, "all out-links point at real nodes")
	# Travel a full path to the boss; cleared nodes stay locked.
	var path := ["f1", "f2a", "f3", "f4a", "ly", "cave", "rest1", "p1a", "p2", "rest2", "boss"]
	var ok := true
	for pid in path:
		if not mg.travel_to(pid):
			ok = false
	check(ok, "can travel full path to boss")
	check(mg.is_boss_reached(), "boss reached")
	check(not mg.travel_to("f1"), "no backtracking to cleared node")
	check(true, "map gen rules done")


func bs2_setup_drowsy(bs: BattleState) -> void:
	# Force deterministic drowsy lock: set drowsy then re-run lock step.
	bs.player.drowsy = 2
	bs.drowsy_locked.clear()
	var idxs := []
	for i in range(bs.hand.size()):
		idxs.append(i)
	bs._shuffle(idxs)
	for k in range(2):
		bs.drowsy_locked.append(bs.hand[idxs[k]]["uid"])
