class_name TitleScreen
extends Control
## Title screen: VIET LEGENDS — Story 1: Thach Sanh.

var router = null


func _ready() -> void:
	add_child(UIH.screen_bg("res://assets/art/vl/bg_forest.png"))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb)
	vb.add_child(UIH.title("VIET LEGENDS", 72))
	var stamp := UIH.label("[ VIETNAMESE FOLKTALES ]", 15, UIH.STAMP)
	stamp.add_theme_font_override("font", UIH.font_bold())
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(stamp)
	var sub := UIH.label("Thach Sanh · Hai Ba Trung", 24, UIH.LT_TEAL)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	vb.add_child(UIH.spacer(20))
	var nb := UIH.btn("NEW RUN", 260)
	nb.custom_minimum_size = Vector2(260, 60)
	nb.pressed.connect(func(): router.show_hero_select())
	var hc := HBoxContainer.new()
	hc.alignment = BoxContainer.ALIGNMENT_CENTER
	hc.add_child(nb)
	vb.add_child(hc)
	var hint := UIH.label("A turn-based deckbuilder roguelite.\nVietnamese folktales, Dong Ho folk art.", 15, UIH.LT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)
