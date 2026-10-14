extends SceneTree
## Tap/drag card-play flow test (frame-driven).
## - tap 1: arms the card (no play, busy stays false, card stays in hand)
## - tap 2 on the armed card: plays it
## - drag up (dy < -60): plays immediately
## - synthetic press+release on a card emits `clicked` (no drag, no zoom)
## Run: godot --headless --path . --script res://tests/tap_flow_test.gd

var step := 0
var main = null
var btl = null
var ch = null
var hand0 := 0
var drag_fired := false
var clicked_fired := false
var fails := 0


func check(cond: bool, name: String) -> void:
	if cond:
		print("  ok: " + name)
	else:
		fails += 1
		printerr("  FAIL: " + name)


func _initialize() -> void:
	var game_node: Node = root.get_node("Game")
	game_node.call("new_run", "silence_anchor")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _first_playable():
	for c in btl._hand_box.get_children():
		if c.playable:
			return c
	return null


func _press_at(w: CardWidget) -> InputEventMouseButton:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.global_position = w.get_global_rect().get_center()
	return mb


func _release_at(w: CardWidget) -> InputEventMouseButton:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = false
	mb.global_position = w.get_global_rect().get_center()
	return mb


func _motion(d: Vector2, at: Vector2) -> InputEventMouseMotion:
	var mm := InputEventMouseMotion.new()
	mm.relative = d
	mm.global_position = at
	return mm


func _process(_delta: float) -> bool:
	step += 1
	match step:
		5:
			main.show_battle("restless_citizen")
		15:
			print("== tap flow ==")
			btl = main.current
			ch = _first_playable()
			check(ch != null, "have a playable card")
			hand0 = btl.bs.hand.size()
			# tap 1: arm only
			btl._on_card_clicked(ch)
			check(btl._armed_w == ch, "tap 1 arms the card")
			check(not btl.busy, "tap 1 does not start playing (busy false)")
			check(btl.bs.hand.size() == hand0, "tap 1 keeps card in hand")
			check(ch.armed, "card shows armed state")
		25:
			# tap 2 on the armed card: plays it
			btl._on_card_clicked(ch)
			check(btl.busy, "tap 2 starts playing (busy true)")
		35:
			if btl.busy:
				step = 34  # wait for the animation to finish
			else:
				check(btl.bs.hand.size() == hand0 - 1, "tap 2 removed the card from hand")
				check(btl._armed_w == null, "armed cleared after play")
				print("== drag flow ==")
				ch = _first_playable()
				hand0 = btl.bs.hand.size()
				check(ch != null, "have another playable card")
				ch.drag_play.connect(func(_w): drag_fired = true)
				ch.clicked.connect(func(_w): clicked_fired = true)
				# synthetic drag: press, move up 70px, release
				ch._input(_press_at(ch))
				ch._input(_motion(Vector2(0, -70), ch.get_global_rect().get_center()))
				check(drag_fired, "drag up 70px fires drag_play")
				check(not clicked_fired, "drag does not fire clicked")
				ch._input(_release_at(ch))
				check(not clicked_fired, "release after drag does not fire clicked")
		45:
			print("== synthetic quick tap ==")
			ch = _first_playable()
			if ch == null:
				check(false, "have a card for tap test")
			else:
				ch.drag_play.connect(func(_w): drag_fired = true)
				ch.clicked.connect(func(_w): clicked_fired = true)
				drag_fired = false
				clicked_fired = false
				ch._input(_press_at(ch))
				ch._input(_release_at(ch))
				check(clicked_fired, "quick press+release fires clicked")
				check(not drag_fired, "quick tap does not fire drag_play")
		55:
			print("==== TAP FLOW: %s ====" % ("PASS" if fails == 0 else "FAIL(%d)" % fails))
			return true
	return false
