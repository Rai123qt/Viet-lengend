class_name HeroSelectScreen
extends Control
## v5.9: Choose your hero before the run. Dong Ho style, all text English.

var router = null


func _ready() -> void:
	add_child(UIH.screen_bg("res://assets/art/vl/bg_forest.png"))
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 10)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vb)
	vb.add_child(UIH.title("CHOOSE YOUR HERO", 36))
	var sub := UIH.label("Two legends. Two ways to fight. Tap to choose.", 14, UIH.LT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	# v6.8: ScrollContainer for small screens (was fixed 420x520 cards getting cut off)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 480)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 20)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(hb)
	for hid in CharacterDB.ORDER:
		hb.add_child(_hero_card(str(hid)))


func _hero_card(hero_id: String) -> Control:
	var h: Dictionary = CharacterDB.get_hero(hero_id)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIH.paper_style(UIH.INK, 3, 6))
	card.custom_minimum_size = Vector2(360, 460)  # v6.8: shrunk from 420x520 for small screens
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	card.add_child(cv)
	# portrait
	var ppath := str(h.get("portrait", ""))
	var tex = UIH.try_tex(ppath) if ppath != "" else null
	if tex != null:
		var img := TextureRect.new()
		img.texture = tex
		img.custom_minimum_size = Vector2(320, 200)  # v6.8: shrunk from 380x240
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var imgh := HBoxContainer.new()
		imgh.alignment = BoxContainer.ALIGNMENT_CENTER
		imgh.add_child(img)
		cv.add_child(imgh)
	# name + title
	var n := UIH.label(str(h.get("name", "HERO")), 24, UIH.INK)
	n.add_theme_font_override("font", UIH.font_bold())
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(n)
	var t := UIH.label(str(h.get("title", "")), 15, UIH.STAMP)
	t.add_theme_font_override("font", UIH.font_bold())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(t)
	# trait + playstyle
	var trait_l := UIH.label(str(h.get("trait", "")), 14, UIH.INK)
	trait_l.add_theme_font_override("font", UIH.font_bold())
	trait_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trait_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(trait_l)
	var ps := UIH.label(str(h.get("playstyle", "")), 13, Color("2a2318"))
	ps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(ps)
	# passive
	var pn := UIH.label("PASSIVE: " + str(h.get("passive_name", "")), 13, UIH.STAMP)
	pn.add_theme_font_override("font", UIH.font_bold())
	pn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(pn)
	var pd := UIH.label(str(h.get("passive_desc", "")), 12, Color("2a2318"))
	pd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pd.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.add_child(pd)
	# HP + tap hint
	var hp := UIH.label("HP: %d" % int(h.get("hp", 80)), 14, UIH.INK)
	hp.add_theme_font_override("font", UIH.font_bold())
	hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(hp)
	var hint := UIH.label("— TAP TO CHOOSE —", 13, UIH.STAMP)
	hint.add_theme_font_override("font", UIH.font_bold())
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(hint)
	var hid: String = hero_id
	card.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
				_choose(hid))
	return card


func _choose(hero_id: String) -> void:
	Sfx.play("ui_click")
	Game.hero_id = hero_id
	router.show_equipment()
