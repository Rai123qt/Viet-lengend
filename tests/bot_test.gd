extends SceneTree
## Viet Legends autoplay bot: chord-aware play + full Story 1 campaign sims.
## Run: godot --headless --path . --script res://tests/bot_test.gd
## Pass: 0 stalls. Reports win rates per enemy + campaign win rate.

const ENEMIES := ["wild_boar", "forest_viper", "timber_bandit",
	"ly_thong", "chan_tinh", "dai_bang"]
const EQUIPS := ["divine_axe", "divine_lute", "endless_rice_pot"]

var battles := 0
var wins := 0
var stalls := 0
var per_enemy := {}
var campaigns := 0
var campaign_wins := 0


func _initialize() -> void:
	for id in ENEMIES:
		per_enemy[id] = {"n": 0, "w": 0}
	per_enemy["duo"] = {"n": 0, "w": 0}
	var total := 120
	for i in range(total):
		_run_battle_enc([{"id": ENEMIES[i % ENEMIES.size()], "hp_mult": 1.0}], 1000 + i, ENEMIES[i % ENEMIES.size()])
	var mrng := RandomNumberGenerator.new()
	mrng.seed = 777
	var pool := ["wild_boar", "forest_viper", "timber_bandit"]
	for i in range(40):
		var duo := [
			{"id": pool[mrng.randi_range(0, 2)], "hp_mult": 0.8},
			{"id": pool[mrng.randi_range(0, 2)], "hp_mult": 0.8},
		]
		_run_battle_enc(duo, 2000 + i, "duo")
	for i in range(10):
		_run_campaign(5000 + i)
	print("==== BOT: %d battles, %d wins, %d stalls ====" % [battles, wins, stalls])
	for id in ENEMIES + ["duo"]:
		var e: Dictionary = per_enemy[id]
		var pct: float = 0.0 if e["n"] == 0 else 100.0 * e["w"] / e["n"]
		print("  %s: %d/%d (%.0f%%)" % [id, e["w"], e["n"], pct])
	print("==== CAMPAIGNS: %d/%d won (%.0f%%) ====" % [campaign_wins, campaigns,
		(100.0 * campaign_wins / maxi(1, campaigns))])
	if stalls > 0:
		printerr("BOT FAIL: stalls detected")
		quit(1)
	else:
		quit(0)


func _run_battle_enc(enc: Array, seed: int, label: String) -> void:
	var g := GameState.new()
	g.new_run(EQUIPS[seed % EQUIPS.size()])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# Mid-run-ish deck: add a few extra cards so it's not pure starter.
	for c in ["wood_axe", "tune_up", "guard_stance", "quick_note", "soft_pluck"]:
		if rng.randf() < 0.7:
			g.add_card(c)
	var bs := BattleState.new()
	bs.setup(g.deck.duplicate(true), enc, g, seed)
	bs.start_player_turn()
	var turns := 0
	while not bs.battle_over and turns < 200:
		turns += 1
		_bot_turn(bs, rng)
	battles += 1
	per_enemy[label]["n"] += 1
	if bs.result == "win":
		wins += 1
		per_enemy[label]["w"] += 1
	if turns >= 200 and not bs.battle_over:
		stalls += 1
		printerr("STALL: %s seed %d" % [label, seed])


func _ctype_of(bs: BattleState, i: int) -> String:
	return str(CardDB.get_def(bs.hand[i]["id"]).get("ctype", ""))


func _find_playable_type(bs: BattleState, want: String) -> int:
	# want: "A" or "S". Prefer cheapest.
	var best := -1
	var best_cost := 99
	for i in range(bs.hand.size()):
		if not bs.can_play(i)["ok"]:
			continue
		var t := _ctype_of(bs, i)
		var ok := (want == "A" and t == "ATTACK") or (want == "S" and t == "SKILL")
		if ok:
			var c := bs.card_cost(bs.hand[i])
			if c < best_cost:
				best_cost = c
				best = i
	return best


func _count_playable_type(bs: BattleState, want: String) -> int:
	var n := 0
	for i in range(bs.hand.size()):
		if not bs.can_play(i)["ok"]:
			continue
		var t := _ctype_of(bs, i)
		if (want == "A" and t == "ATTACK") or (want == "S" and t == "SKILL"):
			n += 1
	return n


func _is_block_card(card_id: String) -> bool:
	return card_id in ["defend", "guard_stance", "iron_bark", "soft_pluck",
		"deep_breath", "sturdy_defense", "brace", "second_wind", "fortress", "last_stand"]


func _bot_pick(bs: BattleState, incoming: int) -> int:
	var evading: bool = bs.enemies[bs.target_idx].evading
	# Strength scaling first (snowball).
	for i in range(bs.hand.size()):
		if bs.can_play(i)["ok"] and bs.hand[i]["id"] in ["battle_shout", "sharpen", "focus", "war_chant"]:
			return i
	# If incoming damage threatens, play block cards first.
	if incoming > bs.player.armor + 4:
		for i in range(bs.hand.size()):
			if bs.can_play(i)["ok"] and _is_block_card(bs.hand[i]["id"]):
				return i
	# Otherwise: 0-cost, then attacks (not into evade), then anything.
	for i in range(bs.hand.size()):
		if bs.can_play(i)["ok"] and bs.card_cost(bs.hand[i]) == 0:
			return i
	for i in range(bs.hand.size()):
		if bs.can_play(i)["ok"] and _ctype_of(bs, i) == "ATTACK" and not evading:
			return i
	for i in range(bs.hand.size()):
		if bs.can_play(i)["ok"] and not (_ctype_of(bs, i) == "ATTACK" and evading):
			return i
	return -1


func _bot_turn(bs: BattleState, rng: RandomNumberGenerator) -> void:
	if bs.battle_over:
		return
	# v3.8: chords auto-detect — no compose step.
	# 1) Build toward the longest known chord we can fully play.
	var guard := 0
	while not bs.battle_over and not bs.chord_completed and guard < 12:
		guard += 1
		# pick the longest known chord extending the current string
		var want := ""
		var best_len := -1
		for cid in bs.game.chords:
			var seq: Array = ChordDB.seq(cid)
			if seq.size() <= bs.chord_seq.size():
				continue
			var ok := true
			for i in range(bs.chord_seq.size()):
				if str(seq[i]) != str(bs.chord_seq[i]):
					ok = false
					break
			if not ok:
				continue
			var need_a := 0
			var need_s := 0
			for i in range(bs.chord_seq.size(), seq.size()):
				if str(seq[i]) == "A":
					need_a += 1
				else:
					need_s += 1
			if _count_playable_type(bs, "A") >= need_a \
					and _count_playable_type(bs, "S") >= need_s \
					and seq.size() > best_len:
				best_len = seq.size()
				want = str(seq[bs.chord_seq.size()])
		if want == "":
			break  # nothing to build toward
		if want == "A" and bs.enemies[bs.target_idx].evading:
			break  # don't waste attacks into evade
		var idx := _find_playable_type(bs, want)
		if idx < 0:
			break
		bs.play_card(idx)
	# 3) Play remaining cards. Block first when big damage is incoming.
	var incoming := 0
	for i in range(bs.enemies.size()):
		if bs.enemies[i].hp > 0:
			for it in bs.intent_summary_for(i):
				if str(it["kind"]) == "attack":
					incoming += int(it["power"]) + bs.enemies[i].strength
	guard = 0
	while not bs.battle_over and guard < 40:
		guard += 1
		var idx := _bot_pick(bs, incoming)
		if idx < 0:
			break
		var was_block := _is_block_card(bs.hand[idx]["id"])
		bs.play_card(idx)
		if was_block:
			incoming = maxi(0, incoming - 8)
	if not bs.battle_over:
		bs.end_player_turn()
		if not bs.battle_over:
			bs.start_player_turn()


func _run_campaign(seed: int) -> void:
	var g := GameState.new()
	g.new_run(EQUIPS[seed % EQUIPS.size()])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var graph: MapGraph = g.map_graph
	var steps := 0
	while steps < 40:
		steps += 1
		var avail := []
		for id in graph.nodes:
			if str((graph.nodes[id] as Dictionary)["state"]) == MapGraph.S_AVAILABLE:
				avail.append(id)
		if avail.is_empty():
			break
		var nid: String = avail[rng.randi_range(0, avail.size() - 1)]
		graph.travel_to(nid)
		var n: Dictionary = graph.get_node(nid)
		g.act = int(n.get("act", 1))
		var t: String = str(n["type"])
		if t in ["BATTLE", "ELITE", "BOSS"]:
			var enc: Array = g.resolve_encounter(n, rng)
			var bs := BattleState.new()
			bs.setup(g.deck.duplicate(true), enc, g, rng.randi())
			bs.start_player_turn()
			var turns := 0
			while not bs.battle_over and turns < 200:
				turns += 1
				_bot_turn(bs, rng)
			if turns >= 200:
				stalls += 1
				printerr("CAMPAIGN STALL seed %d node %s" % [seed, nid])
				return
			if bs.result != "win":
				campaigns += 1
				return  # campaign lost
			g.hp = bs.player.hp
			g.add_gold(60)
			g.add_exp(25)
			var draft_pool := ["wood_axe", "forest_chop", "guard_stance", "iron_bark",
				"tune_up", "battle_shout", "quick_note", "deep_breath", "heavy_fell",
				"double_cut", "sharpen", "soft_pluck"]
			g.add_card(draft_pool[rng.randi_range(0, draft_pool.size() - 1)])
			var eid0: String = str(enc[0].get("id", ""))
			if eid0 == "chan_tinh":
				var pool := ChordDB.learnable_pool(g.chords, 4)
				if not pool.is_empty():
					g.learn_chord(pool[rng.randi_range(0, pool.size() - 1)])
			if eid0 == "ly_thong" and rng.randf() < 0.35:
				var pool2 := ChordDB.learnable_pool(g.chords, 4)
				if not pool2.is_empty():
					g.learn_chord(pool2[rng.randi_range(0, pool2.size() - 1)])
			if eid0 == "dai_bang":
				campaigns += 1
				campaign_wins += 1
				return  # campaign won!
		elif t == "REST":
			g.heal(int(g.max_hp * 0.5))
		elif t == "SHOP":
			var pool := ChordDB.learnable_pool(g.chords)
			if g.gold >= 175 and not pool.is_empty():
				g.add_gold(-175)
				g.learn_chord(pool[rng.randi_range(0, pool.size() - 1)])
			else:
				var draft_pool2 := ["wood_axe", "forest_chop", "guard_stance", "iron_bark",
					"tune_up", "battle_shout"]
				g.add_card(draft_pool2[rng.randi_range(0, draft_pool2.size() - 1)])
		elif t == "EVENT":
			g.heal(10)
	campaigns += 1  # ran out of nodes without finishing = loss
