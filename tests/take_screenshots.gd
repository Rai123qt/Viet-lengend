extends SceneTree
## Take gameplay screenshots for Rai.

var step := 0
var main = null
var game_node = null

func _initialize() -> void:
	game_node = root.get_node("Game")
	main = load("res://main.gd").new()
	root.add_child(main)
	print("Screenshot script started")

func _process(delta: float) -> bool:
	step += 1
	if step == 30:
		main.show_hero_select()
		print("Hero select shown")
	elif step == 100:
		_shot("/home/hatch/workspace/tmp-godot/shot-hero.png")
		print("Hero shot taken")
	elif step == 120:
		# Start Hai Ba Trung battle
		game_node.call("new_run", "divine_axe", "hai_ba_trung")
		var enc := [{"id": "han_soldier", "hp_mult": 1.0}]
		main.show_battle(enc)
		print("HBT Battle started")
	elif step == 240:
		_shot("/home/hatch/workspace/tmp-godot/shot-battle.png")
	elif step == 260:
		main.show_map()
		print("Map shown")
	elif step == 340:
		_shot("/home/hatch/workspace/tmp-godot/shot-map.png")
	elif step == 360:
		print("Screenshots done")
		return true
	return false

func _shot(path: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("Saved: ", path)
