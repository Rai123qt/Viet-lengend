extends SceneTree
## Simple battle screenshot for v3.4 verification.

var _step := 0
var _router = null
var _Game = null
var _wait_frames := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	_Game = root.get_node("Game")
	_Game.call("new_run", "divine_axe")
	_router = load("res://main.gd").new()
	root.add_child(_router)


func _process(delta: float) -> bool:
	_step += 1
	if _step == 10:
		_router.show_battle(_Game.resolve_encounter(
			{"id": "f1", "act": 1, "kind": "fight", "enemies": [{"id": "wild_boar"}]}, _router.rng))
		print("Battle shown")
	elif _step == 100:
		# Capture after frames have rendered.
		var img := root.get_texture().get_image()
		if img != null:
			img.save_png("/tmp/shots/battle.png")
			print("Saved /tmp/shots/battle.png")
		else:
			print("ERROR: null image")
		print("SCREENSHOT DONE")
		return true
	return false
