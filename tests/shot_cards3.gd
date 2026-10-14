extends SceneTree
## Card close-up viewer: 3 large cards (Attack, Skill, Power).

var _step := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	var bg := ColorRect.new()
	bg.color = Color("2a2018")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 40)
	center.add_child(hb)
	# 3 cards at 2x size: attack (red), skill (green), power (gold)
	var ids := ["wood_axe", "defend", "sturdy_strings"]
	for cid in ids:
		var w = load("res://ui/card_widget.gd").new(CardDB.make(cid), null)
		w.custom_minimum_size = Vector2(280, 408)
		hb.add_child(w)
	print("Cards created")


func _process(delta: float) -> bool:
	_step += 1
	if _step == 60:
		var img := root.get_texture().get_image()
		if img != null:
			img.save_png("/tmp/shots/cards_3up.png")
			print("Saved /tmp/shots/cards_3up.png")
		print("DONE")
		return true
	return false
