class_name EquipmentScreen
extends Control
## Choose 1 Divine Artifact before the run (v3.4: passive artifacts).

var router = null

const EQUIPS := [
	{"id": "divine_axe", "name": "DIVINE AXE",
		"desc": "PASSIVE: Your first Attack each turn deals +6 damage.\nThe axe that felled the sacred tree."},
	{"id": "divine_lute", "name": "DIVINE LUTE",
		"desc": "PASSIVE: Whenever you complete a chord, ALL enemies lose 4 HP.\nIts music shakes the forest."},
	{"id": "endless_rice_pot", "name": "ENDLESS RICE POT",
		"desc": "PASSIVE: Whenever you Heal, heal +6 HP more.\nNever empty, like in the tale."},
]


func _ready() -> void:
	add_child(UIH.screen_bg("res://assets/art/vl/bg_forest.png"))
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 14)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vb)
	vb.add_child(UIH.title("CHOOSE YOUR DIVINE ARTIFACT", 36))
	# v5.9: hero-aware subtitle.
	var hero_name := CharacterDB.hero_name(Game.hero_id)
	var sub := UIH.label(hero_name.capitalize() + " takes one treasure into battle. Tap to take it.", 16, UIH.LT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 24)
	vb.add_child(hb)
	for e in EQUIPS:
		hb.add_child(_equip_card(e))


func _equip_card(e: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIH.paper_style(UIH.INK, 3, 4))
	card.custom_minimum_size = Vector2(340, 380)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	card.add_child(cv)
	var n := UIH.label(e["name"], 19, UIH.INK)
	n.add_theme_font_override("font", UIH.font_bold())
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(n)
	# v3.4: artifact icon
	var edef: Dictionary = GameState.EQUIPMENT.get(str(e["id"]), {})
	var icon_path := str(edef.get("icon", ""))
	if icon_path != "":
		var tex := UIH.try_tex(icon_path)
		if tex != null:
			var img := TextureRect.new()
			img.texture = tex
			img.custom_minimum_size = Vector2(110, 110)
			img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var imgh := HBoxContainer.new()
			imgh.alignment = BoxContainer.ALIGNMENT_CENTER
			imgh.add_child(img)
			cv.add_child(imgh)
	var d := UIH.label(e["desc"], 13, Color("2a2318"))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.add_child(d)
	var hint := UIH.label("— TAP TO TAKE —", 12, UIH.STAMP)
	hint.add_theme_font_override("font", UIH.font_bold())
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(hint)
	var eid: String = e["id"]
	card.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
				_choose(eid))
	return card


func _choose(eid: String) -> void:
	Sfx.play("ui_click")
	Game.new_run(eid, Game.hero_id)
	router.show_map()
