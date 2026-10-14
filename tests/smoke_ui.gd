extends SceneTree
## UI smoke test (frame-driven): instantiate every screen, click a card via UI.
## Run: godot --headless --path . --script res://tests/smoke_ui.gd

var step := 0
var main = null
var g = null
var btl = null


func _initialize() -> void:
	var game_node: Node = root.get_node("Game")
	game_node.call("new_run", "divine_axe")
	main = load("res://main.gd").new()
	root.add_child(main)


func _check_no_overlap(ctrl: Control, label: String) -> void:
	# Simple overlap sanity: ensure no two visible top-level children share
	# the exact same rect (a crude proxy for gross layout errors).
	var rects := []
	for ch in ctrl.get_children():
		if ch is Control and (ch as Control).visible:
			var r: Rect2 = (ch as Control).get_rect()
			for e in rects:
				if r == e:
					printerr("SMOKE WARN: duplicate rect in ", label)
			rects.append(r)


func _process(_delta: float) -> bool:
	step += 1
	match step:
		3:
			print("SMOKE: title ok")
			main.show_equipment()
		6:
			print("SMOKE: equipment ok")
			main.show_map()
		9:
			print("SMOKE: map ok")
			main.show_battle("wild_boar")
		12:
			btl = main.current
			btl._refresh()
			print("SMOKE: battle ok hand=", btl.bs.hand.size())
			# v3.8: no compose button — chords auto-detect; tracker must exist
			if btl._chord_str == null:
				printerr("SMOKE FAIL: no chord tracker")
				quit(1)
				return false
			for ch in btl._hand_box.get_children():
				if ch.playable:
					btl._on_card_clicked(ch)  # tap 1: arm (raise for reading)
					if not ch.armed:
						printerr("SMOKE FAIL: card did not arm on first tap")
						quit(1)
						return false
					btl._on_card_clicked(ch)  # tap 2: play
					break
			step = 13
		14:
			# wait for card-play animation, then end turn
			if btl.busy:
				step = 13
			else:
				print("SMOKE: card played via UI")
				for l in btl.bs.log.slice(maxi(0, btl.bs.log.size() - 3)):
					print("   LOG:", l)
				btl._on_end_turn()
				step = 15
		16:
			# wait for enemy-turn animation
			if btl.busy:
				step = 15
			else:
				print("SMOKE: enemy turn done, turn=", btl.bs.turn_count)
				if btl.bs.turn_count != 2:
					printerr("SMOKE FAIL: expected turn 2")
					quit(1)
					return false
				main.show_battle("dai_bang")
				step = 72  # jump ahead
		73:
			print("SMOKE: boss battle ok")
			main.show_reward("chan_tinh", null)
		76:
			print("SMOKE: reward ok")
			main.show_event()
		79:
			print("SMOKE: event ok")
			main.show_shop()
		82:
			print("SMOKE: shop ok")
			main.show_clinic()
		85:
			print("SMOKE: clinic ok")
			_check_no_overlap(main.current, "clinic")
			main.show_victory()
			main.show_gameover()
			print("SMOKE: end screens ok")
			print("SMOKE DONE")
			quit(0)
	return false
