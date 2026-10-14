class_name TreasureScreen
extends Control
## Treasure node: a hidden Bureau cache. Choose 1 of 3 unowned relics.

var router = null
var _offer: Array = []


func _ready() -> void:
	add_child(UIH.screen_bg("res://assets/art/bg/event.webp"))
	_offer = _roll_offer()
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	add_child(vb)
	vb.add_child(UIH.title("HIDDEN CACHE", 36))
	var sub := UIH.label("A Bureau dead drop, undisturbed for years. Take one relic.", 16, UIH.LT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var hc := HBoxContainer.new()
	hc.alignment = BoxContainer.ALIGNMENT_CENTER
	hc.add_theme_constant_override("separation", 18)
	vb.add_child(hc)
	for rid in _offer:
		hc.add_child(_relic_card(rid))


func _roll_offer() -> Array:
	var pool := []
	for rid in GameState.RELICS.keys():
		if not Game.has_relic(rid):
			pool.append(rid)
	pool.shuffle()
	if pool.is_empty():
		return []
	return pool.slice(0, mini(3, pool.size()))


func _relic_card(rid: String) -> Control:
	var info: Dictionary = GameState.RELICS[rid]
	var p := UIH.panel(UIH.GOLD)
	p.custom_minimum_size = Vector2(300, 330)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	p.add_child(vb)
	# relic illustration (gouache item art)
	var art := TextureRect.new()
	art.texture = UIH.try_tex("res://assets/art/relics/%s.webp" % rid)
	art.custom_minimum_size = Vector2(180, 150)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ac := HBoxContainer.new()
	ac.alignment = BoxContainer.ALIGNMENT_CENTER
	ac.add_child(art)
	vb.add_child(ac)
	var nm := UIH.header(str(info["name"]).to_upper(), UIH.INK, 18)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(nm)
	var ds := UIH.label(str(info["desc"]), 14, UIH.DIM)
	ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(ds)
	var b := UIH.btn("TAKE", 160)
	b.custom_minimum_size = Vector2(160, 48)
	b.pressed.connect(func(): _take(rid))
	var bc := HBoxContainer.new()
	bc.alignment = BoxContainer.ALIGNMENT_CENTER
	bc.add_child(b)
	vb.add_child(bc)
	return p


func _take(rid: String) -> void:
	Sfx.play("ui_click")
	Game.add_relic(rid)
	Game.advance_node()
	router.show_map()
