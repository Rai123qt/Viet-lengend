class_name CollectionScreen
extends Control
## Collection / Library: browse all cards, relics, items.
## v6.7: added per Rai's request - "tủ sách" showing unlocked content.
## For now shows ALL (no unlock progression yet).

var router = null
var _hero_id := "thach_sanh"
var _tab := "CARDS"  # CARDS, RELICS, ITEMS
var _grid: GridContainer
var _scroll: ScrollContainer

func _ready() -> void:
	add_child(UIH.screen_bg("res://assets/art/vl/bg_forest.png"))
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 12)
	add_child(vb)
	
	# Title
	var title := UIH.title("COLLECTION", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	
	# Hero tabs
	var hero_hb := HBoxContainer.new()
	hero_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_hb.add_theme_constant_override("separation", 12)
	vb.add_child(hero_hb)
	for hid in ["thach_sanh", "hai_ba_trung"]:
		var b := UIH.btn("THACH SANH" if hid == "thach_sanh" else "HAI BA TRUNG", 200)
		b.pressed.connect(func(): _hero_id = hid; _refresh())
		hero_hb.add_child(b)
	
	# Content tabs
	var tab_hb := HBoxContainer.new()
	tab_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_hb.add_theme_constant_override("separation", 12)
	vb.add_child(tab_hb)
	for t in ["CARDS", "RELICS", "ITEMS"]:
		var b := UIH.btn(t, 160)
		b.pressed.connect(func(): _tab = t; _refresh())
		tab_hb.add_child(b)
	
	# Scrollable grid
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	_scroll.add_child(_grid)
	
	# Back button
	var back := UIH.btn("BACK", 200)
	back.pressed.connect(func(): router.show_title())
	var back_hb := HBoxContainer.new()
	back_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	back_hb.add_child(back)
	vb.add_child(back_hb)

func _refresh() -> void:
	# Clear grid
	for c in _grid.get_children():
		c.queue_free()
	
	if _tab == "CARDS":
		_refresh_cards()
	elif _tab == "RELICS":
		_refresh_relics()
	else:
		_refresh_items()

func _refresh_cards() -> void:
	var db = get_node("/root/CardDB")
	var cards: Array = db.cards_for_hero(_hero_id)
	cards.sort()
	for cid in cards:
		var card: Dictionary = db.CARDS[cid]
		var widget := _make_card_entry(cid, card)
		_grid.add_child(widget)

func _make_card_entry(cid: String, card: Dictionary) -> Control:
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(180, 260)
	
	# Card art
	var art_path := "res://assets/art/vl3/cards/%s.webp" % cid
	var tex := load(art_path) as Texture2D
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(180, 180)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if tex:
		rect.texture = tex
	vb.add_child(rect)
	
	# Name
	var name_label := UIH.label(card.get("name", cid), 14, UIH.LT_GOLD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(name_label)
	
	# Cost + type
	var info := UIH.label("%d | %s" % [card.get("cost", 0), card.get("ctype", "")], 12, UIH.LT_DIM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(info)
	
	return vb

func _refresh_relics() -> void:
	var label := UIH.label("Relics coming soon", 18, UIH.LT_DIM)
	_grid.add_child(label)

func _refresh_items() -> void:
	var label := UIH.label("Items coming soon", 18, UIH.LT_DIM)
	_grid.add_child(label)
