extends SceneTree
## Close-up of 3 cards (Attack red, Skill green, Power gold) for mockup comparison.

var _step := 0
var _router = null
var _Game = null


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	_Game = root.get_node("Game")
	_Game.call("new_run", "divine_axe")
	_Game.set_meta("_tutorial_done", true)  # skip tutorial
	_router = load("res://main.gd").new()
	root.add_child(_router)


func _process(delta: float) -> bool:
	_step += 1
	if _step == 10:
		# Show a battle, then we'll manually add cards.
		_router.show_battle(_Game.resolve_encounter(
			{"id": "f1", "act": 1, "kind": "fight", "enemies": [{"id": "wild_boar"}]}, _router.rng))
		print("Battle shown")
	elif _step == 50:
		var btl = _router.current
		# Clear hand and add 3 specific cards: attack, skill, power.
		for ch in btl._hand_box.get_children():
			ch.queue_free()
		await _router.create_timer(0.5).timeout
		var ids := ["wood_axe", "defend", "sturdy_strings"]  # attack, skill, power
		for cid in ids:
			var w = load("res://ui/card_widget.gd").new(CardDB.make(cid), btl.bs)
			btl._hand_box.add_child(w)
		# Force layout.
		btl._layout_hand()
		print("Cards added")
	elif _step == 100:
		var img := root.get_texture().get_image()
		if img != null:
			img.save_png("/tmp/shots/cards_full.png")
			print("Saved /tmp/shots/cards_full.png")
		else:
			print("ERROR: null image")
		print("DONE")
		return true
	return false
