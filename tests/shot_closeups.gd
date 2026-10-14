extends SceneTree
## v3.6: 6 card close-ups at 2x (2 per type) for the delivery report.

var _step := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	var bg := ColorRect.new()
	bg.color = Color("1a1410")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var ids := ["wood_axe", "thunder_crash", "defend", "rice_meal",
		"sturdy_strings", "divine_lute"]
	for i in range(ids.size()):
		var w = load("res://ui/card_widget.gd").new(CardDB.make(ids[i]), null)
		w.inspect_only = true
		w.scale = Vector2(2.0, 2.0)
		w.position = Vector2(20 + (i % 3) * 300, 20 + (i / 3) * 428)
		root.add_child(w)
	print("rendering 6 close-ups")


func _process(_delta: float) -> bool:
	_step += 1
	if _step == 30:
		var img := root.get_texture().get_image()
		if img != null:
			img.save_png("/tmp/shots/closeups_v36.png")
			print("Saved /tmp/shots/closeups_v36.png")
		print("DONE")
		return true
	return false
