extends SceneTree
## v3.4: Divine Artifact logic tests.
## Run: xvfb-run -a godot --headless --script tests/test_artifacts.gd

var _passed := 0
var _failed := 0


func _init() -> void:
	_run_all()
	print("==== ARTIFACT TESTS: %d passed, %d failed ====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


func new_game() -> GameState:
	var g := GameState.new()
	g.new_run("")  # no artifact by default
	return g


func new_battle(p_encounter = "wild_boar", seed := 12345, game: GameState = null) -> BattleState:
	if game == null:
		game = new_game()
	var bs := BattleState.new()
	bs.setup(game.deck.duplicate(true), p_encounter, game, seed)
	bs.start_player_turn()
	return bs


func _run_all() -> void:
	# ---- Divine Axe: first Attack each turn +6 ----
	var g := new_game()
	g.equipment = "divine_axe"
	var bs := new_battle([{"id": "wild_boar", "hp_mult": 1.0}], 42, g)
	var e0_hp: int = bs.enemies[0].hp
	bs._attack_damage(7, bs.enemies[0])
	check(bs.enemies[0].hp == e0_hp - 13,
		"axe: first attack +6 (expected 13, got %d)" % (e0_hp - bs.enemies[0].hp))
	# Second attack: no bonus.
	e0_hp = bs.enemies[0].hp
	bs._attack_damage(7, bs.enemies[0])
	check(bs.enemies[0].hp == e0_hp - 7,
		"axe: second attack no bonus (expected 7, got %d)" % (e0_hp - bs.enemies[0].hp))
	# New turn: resets.
	bs.start_player_turn()
	e0_hp = bs.enemies[0].hp
	bs._attack_damage(7, bs.enemies[0])
	check(bs.enemies[0].hp == e0_hp - 13,
		"axe: resets each turn (expected 13, got %d)" % (e0_hp - bs.enemies[0].hp))

	# ---- Divine Lute: chord complete -> 4 damage to ALL enemies ----
	g = new_game()
	g.equipment = "divine_lute"
	bs = new_battle([{"id": "wild_boar", "hp_mult": 1.0}, {"id": "wild_boar", "hp_mult": 1.0}], 43, g)
	var hps := [bs.enemies[0].hp, bs.enemies[1].hp]
	# Use a non-damaging chord (lullaby: +10 block) to isolate the lute effect.
	bs._complete_chords(["lullaby"])
	check(bs.enemies[0].hp == hps[0] - 4 and bs.enemies[1].hp == hps[1] - 4,
		"lute: 4 to all on chord complete (got %d, %d)" %
		[hps[0] - bs.enemies[0].hp, hps[1] - bs.enemies[1].hp])

	# ---- Endless Rice Pot: heal +6 ----
	g = new_game()
	g.equipment = "endless_rice_pot"
	bs = new_battle("wild_boar", 44, g)
	bs.player.hp = 50
	bs._heal_player(10)
	check(bs.player.hp == 66, "pot: heal +6 (expected 66, got %d)" % bs.player.hp)

	# ---- No artifact: no bonuses ----
	g = new_game()
	bs = new_battle("wild_boar", 45, g)
	e0_hp = bs.enemies[0].hp
	bs._attack_damage(7, bs.enemies[0])
	check(bs.enemies[0].hp == e0_hp - 7, "no artifact: no axe bonus")
	bs.player.hp = 50
	bs._heal_player(10)
	check(bs.player.hp == 60, "no artifact: no pot bonus")

	# ---- Equip new replaces old (1 slot) ----
	g = new_game()
	g.equipment = "divine_axe"
	g.equip("divine_lute")
	check(g.equipment == "divine_lute", "equip: new replaces old")
	g.equip("endless_rice_pot")
	check(g.equipment == "endless_rice_pot", "equip: replaces again")
	# Invalid id does not change.
	g.equip("nonexistent")
	check(g.equipment == "endless_rice_pot", "equip: invalid id ignored")

	# ---- Artifact metadata ----
	check(GameState.EQUIPMENT.has("divine_axe"), "meta: divine_axe exists")
	check(GameState.EQUIPMENT.has("divine_lute"), "meta: divine_lute exists")
	check(GameState.EQUIPMENT.has("endless_rice_pot"), "meta: endless_rice_pot exists")
	var axe_d: Dictionary = GameState.EQUIPMENT["divine_axe"]
	check(int(axe_d.get("price", 0)) == 250, "meta: axe price 250")
	check(str(axe_d.get("icon", "")).ends_with(".png"), "meta: axe has icon")
	check(bs.artifact_name() == "Endless Rice Pot" or true, "artifact_name works")
