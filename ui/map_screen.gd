class_name MapScreen
extends Control
## Campaign map: directed graph over a top-down Dong Ho folk map.
## Tap AVAILABLE to preview, then TRAVEL.
## No backtracking: only outgoing from CURRENT are clickable.
## v4.0: node positions are FRACTIONS (0..1) of the map bg image;
## converted to viewport coords via the bg's COVERED rect so nodes sit on
## the painted path at any aspect ratio.

var router = null

## v5.0: one top-down map background per act (procedural maps).
const MAP_BGS := {
	1: "res://assets/art/vl/map-act1.webp",
	2: "res://assets/art/vl/map-act2.webp",
	3: "res://assets/art/vl/map-act3.webp",
}
var _bg_tex: Texture2D

## v3.9.3: node icons are code-drawn red-seal stamps (SealIcon), replacing
## the old blurry emoji glyphs.
const NODE_NAMES := {
	"START": "START", "BATTLE": "BATTLE", "ELITE": "ELITE",
	"EVENT": "EVENT", "SHOP": "SHOP", "REST": "REST",
	"BOSS": "BOSS",
}
const NODE_DESCS := {
	"START": "The forest gate. Your tale begins.",
	"BATTLE": "Beasts and bandits bar the way.",
	"ELITE": "A cunning foe. Drops a relic — may teach a chord.",
	"EVENT": "Something stirs among the trees.",
	"SHOP": "Spend gold on supplies and songbooks.",
	"REST": "Rest, heal, upgrade, or meditate on music.",
	"BOSS": "A demon blocks the path.",
}

var _canvas: MapCanvas
var _preview: PopupPanel = null
var _hud_bar: HBoxContainer


## Mini static seal disc for legend rows / preview headers (v3.9.3).
class SealDisc extends Control:
	var ntype := "BATTLE"
	var state := "AVAILABLE"
	var _r := 16.0

	func _init(p_type: String = "BATTLE", p_state: String = "AVAILABLE", r: float = 16.0) -> void:
		ntype = p_type
		state = p_state
		_r = r
		custom_minimum_size = Vector2(r * 2.0, r * 2.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		MapSeal.draw_node(self, ntype, state, size * 0.5, _r, 0.0)


func _ready() -> void:
	# v5.0: per-act top-down folk map background (COVERED). Node fractions map onto it.
	_bg_tex = load(MAP_BGS.get(Game.act, MAP_BGS[1])) as Texture2D
	var bg := TextureRect.new()
	bg.texture = _bg_tex
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_build_hud()
	_build_corner_buttons()
	_canvas = MapCanvas.new()
	_canvas.screen = self
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_canvas)


## COVERED rect of the map bg in viewport coords (matches the TextureRect).
func _bg_rect() -> Rect2:
	var vp := get_viewport_rect().size
	if _bg_tex == null or vp.x < 10.0:
		return Rect2(Vector2.ZERO, vp)
	var iw := float(_bg_tex.get_width())
	var ih := float(_bg_tex.get_height())
	if iw < 1.0 or ih < 1.0:
		return Rect2(Vector2.ZERO, vp)
	var sc := maxf(vp.x / iw, vp.y / ih)
	return Rect2((vp.x - iw * sc) * 0.5, (vp.y - ih * sc) * 0.5, iw * sc, ih * sc)


## Node fraction (0..1 of bg image) -> viewport position. Aspect-proof.
func node_vp(f: Vector2) -> Vector2:
	var r := _bg_rect()
	return r.position + Vector2(f.x * r.size.x, f.y * r.size.y)


func _build_hud() -> void:
	# Top HUD: silk ribbon + HP | Gold | Act | Chords | Lv | Deck | Hero | Guide
	var rib := UIH.SilkRibbon.new()
	rib.set_anchors_preset(Control.PRESET_TOP_WIDE)
	rib.offset_bottom = 56
	rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rib)
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 56
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 16)
	add_child(bar)
	_hud_bar = bar
	_refresh_hud()


func _refresh_hud() -> void:
	for c in _hud_bar.get_children():
		c.queue_free()
	var g = Game
	var cream := Color("f4ecd8")
	_hud_bar.add_child(UIH.label("HP %d/%d" % [g.hp, g.max_hp], 16, cream))
	_hud_bar.add_child(UIH.label("GOLD %d" % g.gold, 16, Color("e8c34b")))
	_hud_bar.add_child(UIH.label("ACT %d" % g.act, 16, cream))
	# chord count with a small note icon
	var chb := HBoxContainer.new()
	chb.add_theme_constant_override("separation", 4)
	var nic := TextureRect.new()
	nic.texture = UIH.try_tex("res://assets/art/vl/icons/note.webp")
	nic.custom_minimum_size = Vector2(20, 20)
	nic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	nic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chb.add_child(nic)
	chb.add_child(UIH.label("%d" % g.chords.size(), 16, cream))
	_hud_bar.add_child(chb)
	_hud_bar.add_child(UIH.label("LV %d" % g.level, 16, cream))
	_hud_bar.add_child(UIH.label("DECK %d" % g.deck.size(), 16, cream))
	# (v4.0: HERO/GUIDE moved to corner seals, see _build_corner_buttons.)


## v4.0: HERO/GUIDE as two small round red seals stacked at bottom-right.
func _build_corner_buttons() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	vbox.offset_left = -104.0
	vbox.offset_right = -24.0
	vbox.offset_top = -196.0
	vbox.offset_bottom = -24.0
	vbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)
	var hb := _seal_button("HERO")
	hb.pressed.connect(_show_keeper)
	vbox.add_child(hb)
	var gb := _seal_button("GUIDE")
	gb.pressed.connect(_show_legend)
	vbox.add_child(gb)


func _seal_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(80, 80)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.70, 0.15, 0.11, 0.95)
	sb.border_color = Color(0.10, 0.08, 0.07, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(40)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	b.add_theme_stylebox_override("normal", sb)
	var hv := sb.duplicate() as StyleBoxFlat
	hv.bg_color = Color(0.78, 0.20, 0.14, 0.95)
	b.add_theme_stylebox_override("hover", hv)
	var pr := sb.duplicate() as StyleBoxFlat
	pr.bg_color = Color(0.55, 0.12, 0.10, 0.95)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_color_override("font_color", Color(0.96, 0.90, 0.76))
	b.add_theme_font_size_override("font_size", 15)
	return b


func _show_keeper() -> void:
	_hide_preview()
	var pop := PopupPanel.new()
	pop.add_theme_stylebox_override("panel", UIH.paper_style(UIH.INK, 2, 3))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	pop.add_child(vb)
	vb.add_child(UIH.header("THACH SANH", UIH.STAMP, 18))
	vb.add_child(UIH.label("THACH SANH — The Woodcutter.\nPlay Attack/Skill cards in a chord's note order (A/S) to complete it — no need to declare first.\nWrong note snaps the string. Power cards are grace notes.", 14, UIH.DIM))
	var cb := UIH.btn("CLOSE", 120)
	cb.pressed.connect(func(): pop.hide(); pop.queue_free())
	vb.add_child(cb)
	add_child(pop)
	_preview = pop
	pop.popup_centered()


func _show_legend() -> void:
	_hide_preview()
	var pop := PopupPanel.new()
	pop.add_theme_stylebox_override("panel", UIH.paper_style(UIH.INK, 2, 3))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	pop.add_child(vb)
	vb.add_child(UIH.header("LEGEND", UIH.STAMP, 18))
	for t in ["BATTLE", "ELITE", "EVENT", "SHOP", "REST", "BOSS"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(SealDisc.new(t, "AVAILABLE", 16.0))
		row.add_child(UIH.label(NODE_NAMES[t], 14, UIH.INK))
		vb.add_child(row)
	var cb := UIH.btn("CLOSE", 120)
	cb.pressed.connect(func(): pop.hide(); pop.queue_free())
	vb.add_child(cb)
	add_child(pop)
	_preview = pop
	pop.popup_centered()


func _hide_preview() -> void:
	if _preview and is_instance_valid(_preview):
		_preview.hide()
		_preview.queue_free()
	_preview = null


func show_node_preview(id: String) -> void:
	_hide_preview()
	var g: MapGraph = Game.map_graph
	var n: Dictionary = g.get_node(id)
	if n.is_empty():
		return
	var pop := PopupPanel.new()
	pop.add_theme_stylebox_override("panel", UIH.paper_style(UIH.INK, 2, 3))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	pop.add_child(vb)
	var t: String = str(n["type"])
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 10)
	hrow.add_child(SealDisc.new(t, "AVAILABLE", 18.0))
	hrow.add_child(UIH.header(NODE_NAMES.get(t, t), UIH.STAMP, 18))
	vb.add_child(hrow)
	vb.add_child(UIH.label(str(n["loc"]), 14, UIH.LT_TEAL))
	vb.add_child(UIH.label(NODE_DESCS.get(t, ""), 13, UIH.DIM))
	if str(n.get("reward", "")) != "":
		vb.add_child(UIH.label("Reward: %s" % str(n["reward"]), 13, UIH.LT_GOLD))
	var tb := UIH.btn("TRAVEL →", 200)
	tb.pressed.connect(func(): _hide_preview(); _travel(id))
	vb.add_child(tb)
	var cb := UIH.btn("CLOSE", 120)
	cb.pressed.connect(_hide_preview)
	vb.add_child(cb)
	add_child(pop)
	_preview = pop
	pop.popup_centered()


func _travel(id: String) -> void:
	var g: MapGraph = Game.map_graph
	if g == null or not g.travel_to(id):
		return
	var n: Dictionary = g.get_node(id)
	Game.act = int(n.get("act", 1))
	_refresh_hud()
	_canvas.queue_redraw()
	var t: String = str(n["type"])
	match t:
		"BATTLE", "ELITE", "BOSS":
			router.show_battle(Game.resolve_encounter(n, router.rng))
		"SHOP":
			router.show_shop()
		"REST":
			router.show_rest()
		"EVENT":
			router.show_event()
		_:
			pass


class MapCanvas extends Control:
	var screen: MapScreen = null
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			var g: MapGraph = Game.map_graph
			if g == null:
				return
			for id in g.nodes:
				var n: Dictionary = g.nodes[id]
				# v4.0: pos is a fraction of the bg; convert to viewport.
				var pos: Vector2 = screen.node_vp(n["pos"])
				if event.position.distance_to(pos) < 44.0:
					if str(n["state"]) == MapGraph.S_AVAILABLE:
						screen.show_node_preview(id)
					accept_event()
					return

	func _draw() -> void:
		var g: MapGraph = Game.map_graph
		if g == null:
			return
		# --- route lines (v4.0: fractions -> viewport via bg COVERED rect) ---
		for c in g.all_connections():
			var a: Vector2 = screen.node_vp(c["from"])
			var b: Vector2 = screen.node_vp(c["to"])
			var fn: Dictionary = g.nodes[c["from_id"]]
			var tn: Dictionary = g.nodes[c["to_id"]]
			var col := Color(0.55, 0.42, 0.28, 0.25)  # future: faint warm trail
			var w := 2.0
			if str(fn["state"]) == MapGraph.S_CLEARED:
				if str(tn["state"]) == MapGraph.S_CLEARED \
						or str(tn["state"]) == MapGraph.S_CURRENT:
					col = Color(0.50, 0.38, 0.25, 0.7)
				elif str(tn["state"]) == MapGraph.S_AVAILABLE:
					col = Color(0.62, 0.15, 0.12, 1.0)
					w = 3.5
			draw_line(a, b, col, w, true)
			var dir: Vector2 = (b - a).normalized()
			var perp := Vector2(-dir.y, dir.x)
			var tip: Vector2 = b - dir * 14.0
			draw_colored_polygon(
				[tip + dir * 10.0, tip - dir * 4.0 + perp * 6.0,
					tip - dir * 4.0 - perp * 6.0], col)
		# --- nodes: red-seal stamps with carved white icons (v3.9.3) ---
		for id in g.nodes:
			var n: Dictionary = g.nodes[id]
			var pos: Vector2 = screen.node_vp(n["pos"])
			var state: String = str(n["state"])
			var ntype: String = str(n["type"])
			var r := 32.0 if ntype != "BOSS" else 36.0
			MapSeal.draw_node(self, ntype, state, pos, r, t)
			var font := ThemeDB.fallback_font
			if state == MapGraph.S_CURRENT:
				# "YOU ARE HERE" label above the current node — unmissable.
				var lbl := "▼ YOU ARE HERE ▼"
				var ls: Vector2 = font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_CENTER, -1, 15)
				draw_string(font, pos - Vector2(ls.x * 0.5, r + 22),
					lbl, HORIZONTAL_ALIGNMENT_CENTER, -1, 15,
					Color(0.95, 0.82, 0.5, 0.95))
