extends SceneTree
## Tests for the 30 new cards + EXPOSED debuff (v28).
## Run: Godot --headless --path . --script res://tests/run_tests_newcards.gd

var passed := 0
var failed := 0


func _init() -> void:
	_run_all()
	print("==== NEWCARD TESTS: %d passed, %d failed ====" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(cond: bool, name: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: " + name)


func new_game() -> GameState:
	var g := GameState.new()
	g.new_run("sandman_hourglass")
	return g


func new_battle(p_encounter = "restless_citizen", seed := 12345, game: GameState = null) -> BattleState:
	if game == null:
		game = new_game()
	var bs := BattleState.new()
	bs.setup(game.deck.duplicate(true), p_encounter, game, seed)
	bs.start_player_turn()
	return bs


func give_card(bs: BattleState, card_id: String, upgraded := false) -> int:
	var c := CardDB.make(card_id, upgraded)
	bs.hand.append(c)
	return bs.hand.size() - 1


func play(bs: BattleState, card_id: String) -> void:
	bs.energy = 10
	var idx := give_card(bs, card_id)
	var r: Dictionary = bs.can_play(idx)
	check(r["ok"], "can play " + card_id + " (" + str(r.get("reason", "")) + ")")
	bs.play_card(idx)


func _run_all() -> void:
	# ============ ATTACK ============
	var bs := new_battle()
	var hp0: int = bs.enemy.hp
	play(bs, "jab")
	check(hp0 - bs.enemy.hp == 3, "jab deals 3 (got %d)" % (hp0 - bs.enemy.hp))

	bs = new_battle()
	bs.enemy.drowsy = 1
	hp0 = bs.enemy.hp
	play(bs, "drowsy_blow")
	check(hp0 - bs.enemy.hp == 12, "drowsy_blow 8 x1.5 drowsy = 12 (got %d)" % (hp0 - bs.enemy.hp))
	bs = new_battle()
	hp0 = bs.enemy.hp
	play(bs, "drowsy_blow")
	check(hp0 - bs.enemy.hp == 5, "drowsy_blow 5 no drowsy (got %d)" % (hp0 - bs.enemy.hp))

	bs = new_battle()
	hp0 = bs.enemy.hp
	play(bs, "double_cut")
	check(hp0 - bs.enemy.hp == 6, "double_cut 3+3 (got %d)" % (hp0 - bs.enemy.hp))

	bs = new_battle()
	hp0 = bs.enemy.hp
	play(bs, "heavy_swing")
	check(hp0 - bs.enemy.hp == 11, "heavy_swing 11 (got %d)" % (hp0 - bs.enemy.hp))

	bs = new_battle()
	bs.player.drowsy = 2
	hp0 = bs.enemy.hp
	play(bs, "wake_up_call")
	check(hp0 - bs.enemy.hp == 6, "wake_up_call 6 (got %d)" % (hp0 - bs.enemy.hp))
	check(bs.player.drowsy == 1, "wake_up_call removes 1 drowsy")

	bs = new_battle()
	bs.enemy.drowsy = 2
	hp0 = bs.enemy.hp
	play(bs, "nightmare_feast")
	check(hp0 - bs.enemy.hp == 12, "nightmare_feast 4x2=8 x1.5 drowsy = 12 (got %d)" % (hp0 - bs.enemy.hp))

	bs = new_battle()
	bs.enemy.exposed = 1
	hp0 = bs.enemy.hp
	play(bs, "exposed_nerve")
	check(hp0 - bs.enemy.hp == 18, "exposed_nerve 12 x1.5=18 (got %d)" % (hp0 - bs.enemy.hp))
	bs = new_battle()
	hp0 = bs.enemy.hp
	play(bs, "exposed_nerve")
	check(hp0 - bs.enemy.hp == 8, "exposed_nerve 8 no exposed (got %d)" % (hp0 - bs.enemy.hp))

	# EXPOSED debuff: +50% attack damage
	bs = new_battle()
	bs.enemy.exposed = 2
	hp0 = bs.enemy.hp
	play(bs, "jab")
	var dmg_exp: int = hp0 - bs.enemy.hp
	check(dmg_exp > 3, "exposed boosts damage 3 -> %d" % dmg_exp)

	bs = new_battle()
	bs.enemy.hp = 4
	bs.energy = 3
	var idx := give_card(bs, "chain_strike")
	bs.play_card(idx)
	check(bs.enemy.hp <= 0, "chain_strike kills")
	check(bs.energy == 3, "chain_strike +1 energy on kill (got %d)" % bs.energy)

	bs = new_battle()
	bs.enemy.hp = bs.enemy.max_hp - 10
	hp0 = bs.enemy.hp
	play(bs, "reap")
	check(hp0 - bs.enemy.hp == 10, "reap = missing hp (got %d)" % (hp0 - bs.enemy.hp))

	bs = new_battle()
	bs.player.hp = 50
	hp0 = bs.enemy.hp
	play(bs, "maw")
	check(hp0 - bs.enemy.hp == 18, "maw 18 (got %d)" % (hp0 - bs.enemy.hp))
	check(bs.player.hp == 59, "maw heals 9 (got %d)" % bs.player.hp)

	# ============ DEFENSE ============
	bs = new_battle()
	play(bs, "brace")
	check(bs.player.armor == 3, "brace 3 armor")

	bs = new_battle()
	bs.player.drowsy = 2
	play(bs, "turtle_dream")
	check(bs.player.armor == 18, "turtle_dream (5+4)x2 drowsy armor double (got %d)" % bs.player.armor)

	bs = new_battle()
	var hand0: int = bs.hand.size()
	play(bs, "padding")
	check(bs.player.armor == 4, "padding 4 armor")
	check(bs.hand.size() == hand0 + 1, "padding draws 1 (net +1)")

	bs = new_battle()
	bs.game.wakefulness = 3
	play(bs, "bastion")
	check(bs.player.armor == 14, "bastion 14 at wake 3 (got %d)" % bs.player.armor)
	bs = new_battle()
	bs.game.wakefulness = 0
	play(bs, "bastion")
	check(bs.player.armor == 10, "bastion 10 at wake 0")

	bs = new_battle()
	play(bs, "shroud")
	check(bs.player.armor == 8, "shroud 8 armor")
	check(bs.enemy.exposed == 1, "shroud applies 1 exposed")

	bs = new_battle()
	bs.player.hp = 60
	play(bs, "last_stand")
	check(bs.player.armor == 12, "last_stand capped 12 (got %d)" % bs.player.armor)

	bs = new_battle()
	play(bs, "fortress")
	check(bs.player.armor == 20, "fortress 20 armor")

	# ============ CONTROL ============
	bs = new_battle()
	play(bs, "mark")
	check(bs.enemy.exposed == 1, "mark 1 exposed")

	bs = new_battle()
	play(bs, "drowsy_mist")
	var all_drowsy := true
	for e in bs.enemies:
		if e.hp > 0 and e.drowsy < 1:
			all_drowsy = false
	check(all_drowsy, "drowsy_mist hits all enemies")

	bs = new_battle()
	var atk_power := -1
	for it in bs.intents:
		if it["kind"] == "attack":
			atk_power = int(it["power"])
			break
	if atk_power >= 0:
		play(bs, "slow_hours")
		var atk_power2 := -1
		for it in bs.intents:
			if it["kind"] == "attack":
				atk_power2 = int(it["power"])
				break
		check(atk_power2 == maxi(0, atk_power - 2), "slow_hours -2 attack power")
	else:
		check(true, "slow_hours: no attack intent this roll, skipped")

	bs = new_battle()
	play(bs, "mark_prey")
	check(bs.enemy.exposed == 2, "mark_prey 2 exposed")

	bs = new_battle()
	bs.enemy.armor = 5
	play(bs, "paranoia")
	check(bs.enemy.exposed == 2, "paranoia 2 exposed")
	check(bs.enemy.armor == 1, "paranoia -4 armor (got %d)" % bs.enemy.armor)

	bs = new_battle()
	play(bs, "mass_hysteria")
	var ok := true
	for e in bs.enemies:
		if e.hp > 0 and (e.drowsy < 1 or e.exposed < 1):
			ok = false
	check(ok, "mass_hysteria all enemies drowsy+exposed")

	bs = new_battle()
	play(bs, "sleep_paralysis")
	check(bs.enemy.drowsy == 3 and bs.enemy.exposed == 2, "sleep_paralysis 3 drowsy 2 exposed")

	bs = new_battle()
	play(bs, "nightmare_realm")
	ok = true
	for e in bs.enemies:
		if e.hp > 0 and (e.drowsy < 2 or e.exposed < 2):
			ok = false
	check(ok, "nightmare_realm all enemies 2/2")

	# exposed decays each enemy turn
	bs = new_battle()
	bs.enemy.exposed = 3
	bs.end_player_turn()
	check(bs.enemy.exposed == 2, "exposed decays 3->2 (got %d)" % bs.enemy.exposed)

	# ============ UTILITY ============
	bs = new_battle()
	hand0 = bs.hand.size()
	play(bs, "echo_sniff")
	check(bs.hand.size() == hand0 + 1, "echo_sniff draw 1 (net +1)")

	bs = new_battle()
	bs.player.hp = 50
	bs.player.drowsy = 2
	play(bs, "power_nap")
	check(bs.player.hp == 54, "power_nap heal 4")
	check(bs.player.drowsy == 1, "power_nap -1 drowsy")

	bs = new_battle()
	bs.player.hp = 50
	bs.game.wakefulness = 3
	play(bs, "deep_rest")
	check(bs.player.hp == 58, "deep_rest heal 8")
	check(bs.game.wakefulness == 1, "deep_rest wake -2 (got %d)" % bs.game.wakefulness)

	bs = new_battle()
	hand0 = bs.hand.size()
	var php0: int = bs.player.hp
	play(bs, "blood_draw")
	check(bs.hand.size() == hand0 + 3, "blood_draw net +3 cards")
	check(bs.player.hp == php0 - 3, "blood_draw -3 hp")

	bs = new_battle()
	hand0 = bs.hand.size()
	play(bs, "somnambulate")
	check(bs.hand.size() == hand0 + 2, "somnambulate net +2 cards")
	var has_hallu := false
	for c in bs.draw_pile:
		if c["id"] == "hallucination":
			has_hallu = true
	check(has_hallu, "somnambulate shuffles hallucination")

	# ============ card DB sanity ============
	var count := 0
	for id in CardDB.CARDS:
		if not CardDB.CARDS[id].get("bearer", false) and id != "hallucination" and id != "echo_of_sleep":
			count += 1
	check(count == 60, "playable pool == 60 (got %d)" % count)
	var rarities := {"common": 0, "uncommon": 0, "rare": 0}
	for id in CardDB.CARDS:
		var r: String = str(CardDB.CARDS[id].get("rarity", "common"))
		if rarities.has(r):
			rarities[r] += 1
	check(rarities["rare"] < rarities["common"], "rares fewer than commons")
	print("rarities: ", rarities)
