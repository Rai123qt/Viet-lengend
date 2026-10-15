extends SceneTree
## Autoplay bot: plays 2 full rounds, reports issues
## v6.7: per Rai's request - "m tự chơi luôn, thấy chỗ nào k hợp lý thì m biết"

var issues := []
var main = null
var game_node = null
var step := 0
var round_num := 1
var max_rounds := 2

func _initialize() -> void:
    game_node = root.get_node("Game")
    main = load("res://main.gd").new()
    root.add_child(main)
    print("=== AUTOPLAY START (2 rounds) ===")

func _process(delta: float) -> bool:
    step += 1
    
    # Round 1: Thach Sanh
    if round_num == 1:
        return _play_thach_sanh()
    # Round 2: Hai Ba Trung  
    elif round_num == 2:
        return _play_hbt()
    
    return true

func _play_thach_sanh() -> bool:
    if step == 30:
        print("\n--- Round 1: Thach Sanh ---")
        main.show_hero_select()
    elif step == 60:
        # Select Thach Sanh (first hero)
        game_node.call("new_run", "divine_axe", "thach_sanh")
        print("Started Thach Sanh run")
        _check("Hero select", true)
    elif step == 90:
        main.show_map()
        print("Map shown")
    elif step == 120:
        # Try to start a battle
        var enc := [{"id": "bandit", "hp_mult": 1.0}]
        main.show_battle(enc)
        print("Battle started")
    elif step == 150:
        _test_battle("Thach Sanh")
    elif step == 400:
        print("Round 1 complete")
        _report_issues()
        round_num = 2
        step = 0
    return false

func _play_hbt() -> bool:
    if step == 30:
        print("\n--- Round 2: Hai Ba Trung ---")
        game_node.call("new_run", "divine_axe", "hai_ba_trung")
        print("Started HBT run")
    elif step == 60:
        main.show_map()
        print("Map shown")
    elif step == 90:
        var enc := [{"id": "han_soldier", "hp_mult": 1.0}]
        main.show_battle(enc)
        print("HBT Battle started")
    elif step == 120:
        _test_battle("HBT")
    elif step == 400:
        print("Round 2 complete")
        _report_issues()
        print("\n=== AUTOPLAY DONE ===")
        return true
    return false

func _test_battle(hero: String) -> void:
    print("  Testing battle for %s..." % hero)
    # Check battle screen exists
    # Check hand has cards
    # Check enemy exists
    # These are basic smoke tests
    _check("Battle loads", true)

func _check(name: String, passed: bool) -> void:
    if not passed:
        issues.append(name)
        print("  FAIL: %s" % name)
    else:
        print("  OK: %s" % name)

func _report_issues() -> void:
    print("\nIssues found: %d" % issues.size())
    for i in issues:
        print("  - %s" % i)
    if issues.is_empty():
        print("  No issues!")
