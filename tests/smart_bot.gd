extends SceneTree
## Smarter bot vs boss only: checks if Keeper of Sleep is beatable with
## reasonable play (guard vs big hits, silence big attacks, heal when hurt).

var wins := 0
var total := 0


func _initialize() -> void:
	total = 60
	for i in range(total):
		if _run_boss(9000 + i):
			wins += 1
	print("==== SMART BOT vs KEEPER: %d/%d wins ====" % [wins, total])
	quit(0)


func _run_boss(seed: int) -> bool:
	var g := GameState.new()
	g.new_run("silence_anchor")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# Realistic END-GAME deck: starter + earned, key cards upgraded.
	for c in ["night_terror", "barricade", "deep_slumber", "soothing_hum", "iron_vessel",
			"sleepwalkers_edge", "counting_sheep", "hollow_echo", "containment", "second_wind"]:
		g.add_card(c)
	for i in [0, 2, 6, 10]:  # upgrade some
		g.upgrade_card_at(i)
	for r in ["coffee_thermos", "dreamcatcher", "echo_cage_fragment", "lexicon_badge", "alarm_clock"]:
		g.add_relic(r)
	for p in ["nightmare_dmg", "rest_armor", "catch_cd", "hp_up", "energy_t1"]:
		g.apply_perk(p)
	var bs := BattleState.new()
	bs.setup(g.deck.duplicate(true), "keeper_of_sleep", g, seed)
	bs.start_player_turn()
	var turns := 0
	while not bs.battle_over and turns < 200:
		turns += 1
		_smart_turn(bs, rng)
	return bs.result == "win"


func _incoming_attack(bs: BattleState) -> int:
	var t := 0
	for it in bs.intents:
		if it["kind"] == "attack":
			t += it["power"]
	return t


func _play_first(bs: BattleState, verb: String) -> bool:
	for i in range(bs.hand.size()):
		var c: Dictionary = bs.hand[i]
		if CardDB.get_def(c["id"]).get("ctype", "") == verb and bs.can_play(i)["ok"]:
			bs.play_card(i)
			return true
	return false


func _smart_turn(bs: BattleState, rng: RandomNumberGenerator) -> void:
	if bs.battle_over:
		return
	# v3.4: Divine Artifacts are passive — no activation needed.
	var guard := 0
	while not bs.battle_over and guard < 40:
		guard += 1
		var atk := _incoming_attack(bs)
		var played := false
		if atk > bs.player.armor + 8:
			played = _play_first(bs, "DEFENSE")
		if not played and bs.player.hp < bs.player.max_hp * 0.55:
			played = _play_first(bs, "UTILITY")
		if not played and bs.enemy.drowsy == 0:
			played = _play_first(bs, "CONTROL")
		if not played:
			played = _play_first(bs, "ATTACK")
		if not played:
			# play anything playable
			for i in range(bs.hand.size()):
				if bs.can_play(i)["ok"]:
					# don't waste heal at full HP
					var c: Dictionary = bs.hand[i]
					if CardDB.get_def(c["id"]).get("ctype", "") == "UTILITY" and bs.player.hp >= bs.player.max_hp:
						continue
					bs.play_card(i)
					played = true
					break
		if not played:
			break
	if not bs.battle_over:
		bs.end_player_turn()
		bs.start_player_turn()
