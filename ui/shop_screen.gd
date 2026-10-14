class_name ShopScreen
extends Control
## Shop: 3 cards, 2 relics, services (upgrade 60 / remove 75 / full heal 40).

var router = null

var _stock_cards: Array = []
var _stock_relics: Array = []
var _stock_items: Array = []
var _box: VBoxContainer
var _gold_l: Label
var _shop_area: VBoxContainer


func _ready() -> void:
	add_child(UIH.screen_bg("res://assets/art/vl/bg_forest.png"))
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 8)
	add_child(_box)

	for i in range(3):
		_stock_cards.append(CardDB.make(CardDB.random_card_id(router.rng, "", Game.hero_id)))
	var rpool := []
	for rid in GameState.RELICS.keys():
		if not Game.has_relic(rid):
			rpool.append(rid)
	for i in range(mini(2, rpool.size())):
		var k: int = router.rng.randi_range(0, rpool.size() - 1)
		_stock_relics.append(rpool[k])
		rpool.remove_at(k)
	# items: 3 random consumables
	var ipool := GameState.ITEMS.keys()
	for i in range(3):
		_stock_items.append(ipool[router.rng.randi_range(0, ipool.size() - 1)])
	_refresh()


func _compact_card_cell(card: Dictionary, price: int, buy_fn: Callable) -> Control:
	# Horizontal shop card: art thumb + name/desc + buy. ~300x110.
	var d := CardDB.get_def(card["id"])
	var col: Color = CardDB.TYPE_COLORS.get(d.get("ctype", ""), UIH.DIM)
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)
	var bg := UIH.panel(UIH.PAPER)
	bg.custom_minimum_size = Vector2(300, 108)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	bg.add_child(hb)
	var art := TextureRect.new()
	art.texture = UIH.try_tex("res://assets/art/cards/%s.webp" % str(card["id"]))
	art.custom_minimum_size = Vector2(72, 96)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(art)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	var nm := UIH.label(str(d["name"]), 14, UIH.INK)
	vb.add_child(nm)
	var meta := UIH.label("Cost %d · %s" % [int(d["cost"]), str(d.get("rarity", "")).capitalize()], 11, col)
	vb.add_child(meta)
	var ds := UIH.label(str(d["text"]), 11, UIH.DIM)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.custom_minimum_size = Vector2(200, 44)
	vb.add_child(ds)
	cell.add_child(bg)
	var b := UIH.btn("Buy %dg" % price, 300)
	b.disabled = Game.gold < price
	b.pressed.connect(buy_fn)
	cell.add_child(b)
	return cell


## Compact horizontal cell for row layout: [icon] [name+desc] [buy]
func _row_item_cell(art_path: String, name: String, desc: String, price: int, price_label: String, buy_fn: Callable, can_buy: bool) -> Control:
	# Panel background so text isn't floating
	var bg := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("ece0c4")
	sb.border_color = Color("6a4526")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	bg.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.custom_minimum_size = Vector2(240, 52)
	bg.add_child(hb)
	var art := TextureRect.new()
	art.texture = UIH.try_tex(art_path)
	art.custom_minimum_size = Vector2(48, 48)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(art)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	vb.custom_minimum_size = Vector2(110, 48)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nl := UIH.label(name, 12, UIH.INK)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(nl)
	var dd := UIH.label(desc, 9, UIH.INK_SOFT)
	dd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dd.custom_minimum_size = Vector2(110, 28)
	vb.add_child(dd)
	hb.add_child(vb)
	var b := UIH.btn("%s %dg" % [price_label, price], 70)
	b.add_theme_color_override("font_color", UIH.PAPER_LT)
	b.disabled = not can_buy
	b.pressed.connect(buy_fn)
	hb.add_child(b)
	return bg


func _compact_item_cell(art_path: String, name: String, desc: String, price: int, price_label: String, buy_fn: Callable, can_buy: bool) -> Control:
	# Shop goods cell with painted art: ~170x190.
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)
	cell.custom_minimum_size = Vector2(110, 0)
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	var p := UIH.panel(UIH.WOOD)
	p.custom_minimum_size = Vector2(110, 140)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 2)
	p.add_child(pv)
	var art := TextureRect.new()
	art.texture = UIH.try_tex(art_path)
	art.custom_minimum_size = Vector2(90, 55)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(art)
	var nl := UIH.label(name, 12, UIH.LT_GOLD)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size = Vector2(100, 22)
	pv.add_child(nl)
	var dd := UIH.label(desc, 10, UIH.DIM)
	dd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dd.custom_minimum_size = Vector2(100, 45)
	pv.add_child(dd)
	cell.add_child(p)
	var b := UIH.btn("%s %dg" % [price_label, price], 110)
	b.add_theme_color_override("font_color", UIH.PAPER_LT)
	b.disabled = not can_buy
	b.pressed.connect(buy_fn)
	cell.add_child(b)
	return cell


const ITEM_ART := {
	"rice_ball": "rice_bowl", "herbal_tea": "pot", "ginseng": "lotus",
	"energy_tonic": "drum", "smoke_bomb": "wind", "throwing_knife": "dagger",
	"firecracker": "lightning", "war_drum_item": "drum", "lute_string": "note",
	"bandage_wrap": "hand", "iron_plate": "shield", "tiger_balm_item": "lotus",
}

func _item_art(iid: String) -> String:
	return "res://assets/art/vl/icons/%s.webp" % ITEM_ART.get(iid, "drum")


func _section(title: String) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	var l := UIH.label(title, 14, Color("e8dcc0"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l)
	return vb

## Horizontal row: label on left, items in HBox
func _row_section(title: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.alignment = BoxContainer.ALIGNMENT_BEGIN
	var l := UIH.label(title, 13, Color("e8dcc0"))
	l.custom_minimum_size = Vector2(70, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(l)
	var items := HBoxContainer.new()
	items.add_theme_constant_override("separation", 8)
	items.alignment = BoxContainer.ALIGNMENT_BEGIN
	hb.add_child(items)
	hb.set_meta("items", items)
	return hb


func _refresh() -> void:
	for ch in _box.get_children():
		ch.queue_free()
	# ---- header: title + gold + LEAVE (always visible, top-right) ----
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 24)
	_box.add_child(header)
	header.add_child(UIH.title("MARKET", 28))
	_gold_l = UIH.label("Gold: %d" % Game.gold, 18, UIH.LT_GOLD)
	header.add_child(_gold_l)
	var leave := UIH.btn("LEAVE \u2192", 160)
	leave.custom_minimum_size = Vector2(160, 48)
	leave.pressed.connect(func(): Game.advance_node(); router.show_map())
	header.add_child(leave)

	# ---- vendor on left, goods on right ----
	var main := HBoxContainer.new()
	main.alignment = BoxContainer.ALIGNMENT_CENTER
	main.add_theme_constant_override("separation", 12)
	_box.add_child(main)
	var vendor := TextureRect.new()
	vendor.texture = UIH.try_tex("res://assets/art/shop/vendor.webp")
	vendor.custom_minimum_size = Vector2(220, 495)
	vendor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vendor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vendor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.add_child(vendor)
	var right_bg := PanelContainer.new()
	var rbg := StyleBoxFlat.new()
	rbg.bg_color = Color(0.05, 0.04, 0.03, 0.82)
	rbg.set_corner_radius_all(8)
	rbg.content_margin_left = 16
	rbg.content_margin_right = 16
	rbg.content_margin_top = 12
	rbg.content_margin_bottom = 12
	right_bg.add_theme_stylebox_override("panel", rbg)
	right_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(right_bg)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_bg.add_child(right)

	# ---- shelf row: 4 columns ----
	var shelf := VBoxContainer.new()
	shelf.alignment = BoxContainer.ALIGNMENT_CENTER
	shelf.add_theme_constant_override("separation", 8)
	right.add_child(shelf)

	var shelf_label := UIH.label("\u2014 SHELVES \u2014", 13, Color("d8b878"))
	shelf_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shelf.add_child(shelf_label)
	if not _stock_relics.is_empty():
		var rc := _row_section("Relics")
		var rc_items: HBoxContainer = rc.get_meta("items")
		for i in range(_stock_relics.size()):
			var rid: String = _stock_relics[i]
			var idx := i
			rc_items.add_child(_row_item_cell("res://assets/art/relics/%s.webp" % rid, str(GameState.RELICS[rid]["name"]),
				str(GameState.RELICS[rid]["desc"]), 150, "Buy",
				func(): _buy_relic(idx), Game.gold >= 150))
		shelf.add_child(rc)
	var ec := _row_section("Equipment")
	var ec_items: HBoxContainer = ec.get_meta("items")
	var eqpool := []
	for eid in GameState.EQUIPMENT.keys():
		if eid != Game.equipment:
			eqpool.append(eid)
	for i in range(mini(2, eqpool.size())):
		var k: int = router.rng.randi_range(0, eqpool.size() - 1)
		var eid: String = eqpool[k]
		eqpool.remove_at(k)
		var edef: Dictionary = GameState.EQUIPMENT[eid]
		var price: int = int(edef["price"])
		var eqid := eid
		# v3.4: Divine Artifacts use their painted icon PNGs.
		var eq_icon := str(edef.get("icon", "res://assets/art/vl/icons/%s.webp" % str(edef.get("art", "drum"))))
		ec_items.add_child(_row_item_cell(eq_icon, str(edef["name"]),
			str(edef["desc"]), price, "Equip",
			func(): _buy_equipment(eqid, price), Game.gold >= price))
	shelf.add_child(ec)
	# Songbook: learn a random chord (175g), if any remain unlearned
	var song_pool := ChordDB.learnable_pool(Game.chords)
	if not song_pool.is_empty():
		var sc2 := _row_section("Chords")
		var sc2_items: HBoxContainer = sc2.get_meta("items")
		sc2_items.add_child(_row_item_cell("", "Songbook",
			"Learn a random chord (175g).", 175, "Buy",
			func(): _buy_songbook(), Game.gold >= 175))
		shelf.add_child(sc2)

	# ---- TABLE: cards + items ----
	var table_label := UIH.label("\u2014 TABLE \u2014", 13, Color("7ab88a"))
	table_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shelf.add_child(table_label)
	# ---- cards row: 3 real cards, centered ----
	var card_row := HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 24)
	shelf.add_child(card_row)
	for i in range(_stock_cards.size()):
		var card: Dictionary = _stock_cards[i]
		var d := CardDB.get_def(card["id"])
		var price: int = CardDB.PRICE_BY_RARITY[d["rarity"]]
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		cell.custom_minimum_size = Vector2(110, 0)
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		var w := CardWidget.new(card, null)
		w.inspect_only = true
		cell.add_child(w)
		var b := UIH.btn("Buy %dg" % price, 155)
		b.add_theme_color_override("font_color", UIH.PAPER_LT)
		b.disabled = Game.gold < price
		var idx := i
		b.pressed.connect(func(): _buy_card(idx))
		cell.add_child(b)
		card_row.add_child(cell)

	var ic := _row_section("Items")
	var ic_items: HBoxContainer = ic.get_meta("items")
	for i in range(_stock_items.size()):
		var iid: String = _stock_items[i]
		var idef: Dictionary = GameState.ITEMS[iid]
		var idx := i
		ic_items.add_child(_row_item_cell(_item_art(iid), str(idef["name"]),
			str(idef["desc"]), int(idef["price"]), "Buy",
			func(): _buy_item(idx), Game.gold >= int(idef["price"]) and Game.has_item_space()))
	shelf.add_child(ic)

	var sc := _row_section("Services")
	var sc_items: HBoxContainer = sc.get_meta("items")
	var up := UIH.btn("Upgrade (60g)", 140)
	up.add_theme_color_override("font_color", UIH.LT_GOLD)
	up.disabled = Game.gold < 60 or Game.deck.is_empty()
	up.pressed.connect(_svc_upgrade)
	sc_items.add_child(up)
	var rm := UIH.btn("Remove (75g)", 140)
	rm.add_theme_color_override("font_color", UIH.LT_GOLD)
	rm.disabled = Game.gold < 75 or Game.deck.is_empty()
	rm.pressed.connect(_svc_remove)
	sc_items.add_child(rm)
	shelf.add_child(sc)


func _buy_card(idx: int) -> void:
	if idx < 0 or idx >= _stock_cards.size():
		return
	var card: Dictionary = _stock_cards[idx]
	var price: int = CardDB.PRICE_BY_RARITY[CardDB.get_def(card["id"])["rarity"]]
	if Game.gold < price:
		return
	Game.add_gold(-price)
	Game.deck.append(card)
	_stock_cards.remove_at(idx)
	_refresh()


func _buy_relic(idx: int) -> void:
	if idx < 0 or idx >= _stock_relics.size() or Game.gold < 150:
		return
	Game.add_gold(-150)
	Game.add_relic(_stock_relics[idx])
	_stock_relics.remove_at(idx)
	_refresh()


func _buy_item(idx: int) -> void:
	if idx < 0 or idx >= _stock_items.size():
		return
	var iid: String = _stock_items[idx]
	var price: int = int(GameState.ITEMS[iid]["price"])
	if Game.gold < price or not Game.has_item_space():
		return
	Game.add_gold(-price)
	Game.add_item(iid)
	_stock_items.remove_at(idx)
	_refresh()


func _buy_songbook() -> void:
	if Game.gold < 175:
		return
	var pool := ChordDB.learnable_pool(Game.chords)
	if pool.is_empty():
		return
	Game.add_gold(-175)
	var cid: String = pool[router.rng.randi_range(0, pool.size() - 1)]
	Game.learn_chord(cid)
	_refresh()


func _buy_equipment(eid: String, price: int) -> void:
	if Game.gold < price or not GameState.EQUIPMENT.has(eid):
		return
	Game.add_gold(-price)
	Game.equip(eid)  # replaces the old one
	_refresh()


func _svc_upgrade() -> void:
	UIH.choose_card_popup(self, "Upgrade a card (60g)", Game.deck, func(i):
		if i >= 0 and Game.gold >= 60:
			Game.add_gold(-60)
			Game.upgrade_card_at(i)
			# v5.2: unmistakable upgrade feedback — gold flash + card name
			var cname: String = CardDB.card_name(Game.deck[i])
			_flash_upgrade(cname)
		_refresh())


## v5.2: gold flash overlay celebrating a card upgrade.
func _flash_upgrade(cname: String) -> void:
	var flash := ColorRect.new()
	flash.color = Color(0.85, 0.66, 0.18, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var lab := UIH.header("UPGRADED: %s" % cname, Color("d9a92e"), 36)
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lab.add_theme_constant_override("outline_size", 8)
	lab.set_anchors_preset(Control.PRESET_CENTER)
	lab.position = Vector2(-300, -40)
	lab.custom_minimum_size = Vector2(600, 80)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lab)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(flash, "color:a", 0.45, 0.15)
	tw.tween_property(flash, "color:a", 0.0, 0.6).set_delay(0.15)
	tw.tween_property(lab, "modulate:a", 1.0, 0.15).from(0.0)
	tw.tween_property(lab, "modulate:a", 0.0, 0.5).set_delay(0.7)
	tw.chain().tween_callback(func():
		flash.queue_free()
		lab.queue_free())


func _svc_remove() -> void:
	UIH.choose_card_popup(self, "Remove a card (75g)", Game.deck, func(i):
		if i >= 0 and Game.gold >= 75:
			Game.add_gold(-75)
			Game.remove_card_at(i)
		_refresh())
