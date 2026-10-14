extends SceneTree
## v5.0: screenshot each act's generated map.

var _step := 0
var _router = null
var _Game = null
var _act := 1


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	_Game = root.get_node("Game")


func _ready_router() -> void:
	if _router != null:
		_router.queue_free()
	_router = load("res://main.gd").new()
	root.add_child(_router)
	_router.set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> bool:
	_step += 1
	# ensure router fills the real window size (root.size is 0 at _initialize)
	if _router != null and _router.size.x < 100.0 and root.size.x > 100.0:
		_router.size = root.size
	if _step == 10:
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		_Game.call("new_run", "divine_axe", rng)
		_ready_router()
		_router.show_map()
		print("act 1 map shown")
	elif _step == 100:
		_save("map_act1")
		# advance to act 2
		_Game.act = 2
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = 777
		_Game.map_graph = MapGen.generate(2, rng2)
		_ready_router()
		_router.show_map()
		print("act 2 map shown")
	elif _step == 190:
		_save("map_act2")
		_Game.act = 3
		var rng3 := RandomNumberGenerator.new()
		rng3.seed = 999
		_Game.map_graph = MapGen.generate(3, rng3)
		_ready_router()
		_router.show_map()
		print("act 3 map shown")
	elif _step == 280:
		_save("map_act3")
		print("SCREENSHOT DONE")
		return true
	return false


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	if img != null:
		img.save_png("/tmp/shots/%s.png" % name)
		print("Saved /tmp/shots/%s.png" % name)
	else:
		print("ERROR: null image for ", name)
