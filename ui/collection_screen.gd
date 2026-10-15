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
var _page := 0  # v6.8: pagination to fix lag (was loading 85 textures at once)
var _page_label: Label
const PAGE_SIZE := 20

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
		b.pressed.connect(func(): _hero_id = hid; _page = 0; _refresh())
		hero_hb.add_child(b)
	
	# Content tabs
	var tab_hb := HBoxContainer.new()
	tab_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_hb.add_theme_constant_override("separation", 12)
	vb.add_child(tab_hb)
	for t in ["CARDS", "RELICS", "ITEMS"]:
		var b := UIH.btn(t, 160)
		b.pressed.connect(func(): _tab = t; _page = 0; _refresh())
		tab_hb.add_child(b)
	
	# Pagination controls (v6.8)
	var page_hb := HBoxContainer.new()
	page_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	page_hb.add_theme_constant_override("separation", 12)
	vb.add_child(page_hb)
	var prev_btn := UIH.btn("< PREV", 120)
	prev_btn.pressed.connect(func(): _page = maxi(0, _page - 1); _refresh())
	page_hb.add_child(prev_btn)
	_page_label = UIH.label("", 16, UIH.LT_GOLD)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.custom_minimum_size = Vector2(150, 30)
	page_hb.add_child(_page_label)
	var next_btn := UIH.btn("NEXT >", 120)
	next_btn.pressed.connect(func(): _page += 1; _refresh())
	page_hb.add_child(next_btn)
	
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
	var cards: Array = CardDB.cards_for_hero(_hero_id)
	cards.sort()
	# v6.8: pagination (20 per page)
	var total_pages := maxi(1, int(ceil(cards.size() / float(PAGE_SIZE))))
	_page = clampi(_page, 0, total_pages - 1)
	var start := _page * PAGE_SIZE
	var end := mini(start + PAGE_SIZE, cards.size())
	if _page_label:
		_page_label.text = "Page %d / %d" % [_page + 1, total_pages]
	for i in range(start, end):
		var cid: String = cards[i]
		var card: Dictionary = CardDB.CARDS[cid]
		var widget := _make_card_entry(cid, card)
		_grid.add_child(widget)

func _make_card_entry(cid: String, card: Dictionary) -> Control:
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(180, 280)
	vb.add_theme_constant_override("separation", 4)
	
	# Card frame (wood border)
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.13, 0.09, 1.0)
	sb.border_color = Color(0.55, 0.42, 0.28)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	frame.add_theme_stylebox_override("panel", sb)
	vb.add_child(frame)
	
	# Card art (fixed 168x168, centered)
	var art_path := "res://assets/art/vl3/cards/%s.webp" % cid
	var tex := load(art_path) as Texture2D
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(168, 168)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # v6.8: was COVERED (cropped)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex:
		rect.texture = tex
	else:
		# Placeholder if art missing
		rect.modulate = Color(0.3, 0.3, 0.3)
	frame.add_child(rect)
	
	# Name
	var name_label := UIH.label(card.get("name", cid), 13, UIH.LT_GOLD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(180, 36)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(name_label)
	
	# Cost + type
	var info := UIH.label("%d Energy | %s" % [card.get("cost", 0), card.get("ctype", "")], 11, UIH.LT_DIM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(info)
	
	# Card text (truncated)
	var desc := str(card.get("text", ""))
	if desc.length() > 60:
		desc = desc.substr(0, 57) + "..."
	var desc_label := UIH.label(desc, 10, Color(0.85, 0.82, 0.75))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(180, 40)
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(desc_label)
	
	return vb

func _refresh_relics() -> void:
	var label := UIH.label("Relics coming soon", 18, UIH.LT_DIM)
	_grid.add_child(label)

func _refresh_items() -> void:
	var label := UIH.label("Items coming soon", 18, UIH.LT_DIM)
	_grid.add_child(label)
