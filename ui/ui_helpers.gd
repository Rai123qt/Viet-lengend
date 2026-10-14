class_name UIH
extends RefCounted
## Shared UI theme: DONG HO FOLK WOODBLOCK.
## Aged diep paper, ink outlines, vermilion red / turmeric yellow /
## leaf green on warm wood. All screens build through these helpers
## so the look stays consistent.

# --- Dong Ho palette ---
const BG := Color("241a10")                # warm dark fallback
const INK := Color("2a1f14")               # ink brown-black
const INK_SOFT := Color("5a4a34")          # faded ink
const PAPER := Color("ece0c4")             # diep paper
const PAPER_DK := Color("d9c9a4")          # aged paper edge
const PAPER_LT := Color("f4ecd8")          # fresh paper
const STAMP := Color("b83026")             # vermilion red (son)
const STAMP_DK := Color("8a231b")
const LEAF := Color("4a7a3a")              # leaf green
const LEAF_DK := Color("35602c")
const TURMERIC := Color("d9a92e")          # turmeric yellow
const TURMERIC_DK := Color("a87c1c")
const WOOD := Color("6a4526")              # carved wood
const WOOD_DK := Color("4a2f18")
const WOOD_LT := Color("8a5f36")
const BAMBOO := Color("c8a86a")
const BAMBOO_DK := Color("8a6a3a")
# legacy accents (kept for compat, remapped to folk tones)
const PANEL := Color("ece0c4")
const PANEL_LINE := Color("6a4526")
const PANEL2 := Color("d9c9a4")
const TEXT := INK
const DIM := INK_SOFT
const TEAL := LEAF
const TEAL_DIM := LEAF_DK
const GOLD := TURMERIC_DK
const AMBER := STAMP
const RED := STAMP
const GREEN := LEAF
# light variants for text over art backgrounds
const LT := Color("f4ecd8")
const LT_DIM := Color("c9b98e")
const LT_TEAL := Color("9dc98e")
const LT_GOLD := Color("e8c34b")
const LT_GREEN := Color("9dc98e")

const FONT_REG := "res://assets/fonts/CourierPrime-Regular.ttf"
const FONT_BOLD := "res://assets/fonts/CourierPrime-Bold.ttf"
## v3.6: Squada One — display font for card names + type labels (mockup match).
const FONT_TITLE := "res://assets/fonts/SquadaOne-Regular.ttf"

static var _f_reg: Font = null
static var _f_bold: Font = null
static var _f_title: Font = null
static var _grain_tex: ImageTexture = null
static var _paper_tex: ImageTexture = null


static func font_reg() -> Font:
	if _f_reg == null:
		if ResourceLoader.exists(FONT_REG):
			_f_reg = load(FONT_REG)
		else:
			_f_reg = ThemeDB.fallback_font
	return _f_reg


static func font_bold() -> Font:
	if _f_bold == null:
		if ResourceLoader.exists(FONT_BOLD):
			_f_bold = load(FONT_BOLD)
		else:
			_f_bold = ThemeDB.fallback_font
	return _f_bold


## v3.6: Squada One display font (card names, type labels). Falls back to
## bold when the TTF is missing.
static func font_title() -> Font:
	if _f_title == null:
		if ResourceLoader.exists(FONT_TITLE):
			_f_title = load(FONT_TITLE)
		else:
			_f_title = font_bold()
	return _f_title


## Tileable monochrome grain (kept for compat; Dong Ho uses paper fiber).
static func grain_tex() -> ImageTexture:
	if _grain_tex != null:
		return _grain_tex
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for y in range(s):
		for x in range(s):
			var n := rng.randf()
			var v := 0.5 + (n - 0.5) * 0.5
			img.set_pixel(x, y, Color(v, v, v, 0.05))
	_grain_tex = ImageTexture.create_from_image(img)
	return _grain_tex


## Tileable diep paper with fibers and age spots.
static func paper_tex() -> ImageTexture:
	if _paper_tex != null:
		return _paper_tex
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	img.fill(PAPER)
	for y in range(s):
		for x in range(s):
			var n := rng.randf()
			var d := (n - 0.5) * 0.055
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(clampf(c.r + d, 0.0, 1.0), clampf(c.g + d, 0.0, 1.0), clampf(c.b + d, 0.0, 1.0), 1.0))
	# fibers: short dark strokes
	for i in range(90):
		var x := rng.randi_range(0, s - 1)
		var y := rng.randi_range(0, s - 1)
		var ln := rng.randi_range(2, 7)
		var ang := rng.randf() * TAU
		for k in range(ln):
			var px := x + int(cos(ang) * k)
			var py := y + int(sin(ang) * k)
			if px >= 0 and px < s and py >= 0 and py < s:
				var c := img.get_pixel(px, py)
				img.set_pixel(px, py, c.darkened(0.06))
	# age spots
	for i in range(7):
		var cx := rng.randf() * s
		var cy := rng.randf() * s
		var r := rng.randf_range(6.0, 20.0)
		for y in range(s):
			for x in range(s):
				var dd := Vector2(x - cx, y - cy).length()
				if dd < r:
					var c := img.get_pixel(x, y)
					var t := 1.0 - dd / r
					img.set_pixel(x, y, c.lerp(Color("c9b384"), t * 0.16))
	_paper_tex = ImageTexture.create_from_image(img)
	return _paper_tex


## Diep-paper StyleBox with ink border.
static func paper_style(border: Color = INK, bw: int = 2, radius: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PAPER
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 3)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


## Small dark wood plaque (fighter name plates, v3.9.2): dark stained wood
## with a lighter carved rim — white text reads on any background.
static func wood_plaque_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("2e2013")
	s.border_color = Color("8a6a3a")
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 2)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	return s


## Wood-framed paper panel (the standard Dong Ho container).
static func style(bg: Color, border: Color, bw: int = 1, radius: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 3)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


## Carved-wood button: warm wood face, cream carved lettering.
static func btn(text: String, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	var n := StyleBoxFlat.new()
	n.bg_color = WOOD
	n.border_color = WOOD_DK
	n.set_border_width_all(2)
	n.set_corner_radius_all(4)
	n.shadow_color = Color(0, 0, 0, 0.45)
	n.shadow_size = 6
	n.shadow_offset = Vector2(0, 3)
	n.content_margin_left = 14
	n.content_margin_right = 14
	n.content_margin_top = 8
	n.content_margin_bottom = 8
	b.add_theme_stylebox_override("normal", n)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = WOOD_LT
	b.add_theme_stylebox_override("hover", h)
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = WOOD_DK
	b.add_theme_stylebox_override("pressed", p)
	var d := n.duplicate() as StyleBoxFlat
	d.bg_color = Color("7a6a52")
	d.border_color = Color("5a4c38")
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", PAPER_LT)
	b.add_theme_color_override("font_hover_color", Color("fff6dd"))
	b.add_theme_color_override("font_pressed_color", TURMERIC)
	b.add_theme_color_override("font_disabled_color", Color("b8a888"))
	b.add_theme_font_override("font", font_bold())
	b.add_theme_font_size_override("font_size", 17)
	if min_w > 0:
		b.custom_minimum_size.x = min_w
	return b


## Big wooden action button.
static func big_btn(text: String, min_w: float = 0.0) -> Button:
	var b := btn(text, min_w)
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size.y = 60
	return b


## Red seal button (END TURN): solid vermilion con dau, cream lettering,
## slight tilt like a hand-stamped seal.
static func stamp_btn(text: String, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	var n := StyleBoxFlat.new()
	n.bg_color = STAMP
	n.border_color = STAMP_DK
	n.set_border_width_all(4)
	n.set_corner_radius_all(3)
	n.shadow_color = Color(0, 0, 0, 0.5)
	n.shadow_size = 8
	n.shadow_offset = Vector2(0, 3)
	n.content_margin_left = 16
	n.content_margin_right = 16
	n.content_margin_top = 10
	n.content_margin_bottom = 10
	b.add_theme_stylebox_override("normal", n)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = STAMP.lightened(0.12)
	b.add_theme_stylebox_override("hover", h)
	var pr := n.duplicate() as StyleBoxFlat
	pr.bg_color = STAMP_DK
	b.add_theme_stylebox_override("pressed", pr)
	var d := n.duplicate() as StyleBoxFlat
	d.bg_color = Color("6a5a4a")
	d.border_color = Color("4a3e32")
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", font_bold())
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", PAPER_LT)
	b.add_theme_color_override("font_hover_color", Color("fff6dd"))
	b.add_theme_color_override("font_pressed_color", TURMERIC)
	b.add_theme_color_override("font_disabled_color", Color("a89880"))
	b.rotation = -0.045
	if min_w > 0:
		b.custom_minimum_size.x = min_w
	return b


## v3.4: Red seal stamp button (Dong Ho style) using the painted seal PNG.
## Square — the seal texture is 1:1, so keep the button square to avoid distortion.
static func seal_btn(text: String, size_px: float = 110.0) -> Button:
	var b := Button.new()
	b.text = text
	var tex := try_tex("res://assets/art/vl3/btn-red-seal.png")
	if tex != null:
		for state in ["normal", "hover", "pressed"]:
			var sb := StyleBoxTexture.new()
			sb.texture = tex
			sb.content_margin_left = 10
			sb.content_margin_right = 10
			sb.content_margin_top = 10
			sb.content_margin_bottom = 10
			b.add_theme_stylebox_override(state, sb)
		var dsb := StyleBoxTexture.new()
		dsb.texture = tex
		dsb.modulate_color = Color(0.55, 0.55, 0.58)
		b.add_theme_stylebox_override("disabled", dsb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", font_bold())
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", PAPER_LT)
	b.add_theme_color_override("font_hover_color", Color("fff6dd"))
	b.add_theme_color_override("font_pressed_color", TURMERIC)
	b.add_theme_color_override("font_disabled_color", Color("a89880"))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	b.add_theme_constant_override("outline_size", 4)
	b.custom_minimum_size = Vector2(size_px, size_px)
	return b


## v3.4: Carved wood plaque button (Dong Ho style) using btn-wood-plaque.png.
## The plaque texture is 3:1, so the button should be ~3:1 (e.g. 180x60).
static func wood_btn(text: String, w_px: float = 180.0, h_px: float = 60.0) -> Button:
	var b := Button.new()
	b.text = text
	var tex := try_tex("res://assets/art/vl3/btn-wood-plaque.png")
	if tex != null:
		for state in ["normal", "hover", "pressed"]:
			var sb := StyleBoxTexture.new()
			sb.texture = tex
			sb.content_margin_left = 14
			sb.content_margin_right = 14
			sb.content_margin_top = 8
			sb.content_margin_bottom = 8
			b.add_theme_stylebox_override(state, sb)
		var dsb := StyleBoxTexture.new()
		dsb.texture = tex
		dsb.modulate_color = Color(0.55, 0.55, 0.58)
		b.add_theme_stylebox_override("disabled", dsb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", font_bold())
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color("ffe9b0"))
	b.add_theme_color_override("font_hover_color", Color("fff6dd"))
	b.add_theme_color_override("font_pressed_color", TURMERIC)
	b.add_theme_color_override("font_disabled_color", Color("a89880"))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	b.add_theme_constant_override("outline_size", 3)
	b.custom_minimum_size = Vector2(w_px, h_px)
	return b


static func label(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_reg())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Woodblock header: uppercase, bold, vermilion by default.
static func header(text: String, color: Color = STAMP_DK, size: int = 13) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", font_bold())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func title(text: String, size: int = 40) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_bold())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", STAMP_DK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Wood-framed paper panel.
static func panel(border: Color = WOOD) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := paper_style(border, 3, 4)
	p.add_theme_stylebox_override("panel", sb)
	return p


static func spacer(min_h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(1, min_h)
	return c


# --- HP bar with baked vertical gradient + rounded corners (legacy) ---

static func _rounded_vgrad(w: int, h: int, top: Color, bot: Color, radius: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var a := 1.0
			# rounded-rect mask
			var cx: float = clampf(x, radius, w - 1 - radius)
			var cy: float = clampf(y, radius, h - 1 - radius)
			var dd: float = Vector2(x - cx, y - cy).length()
			if dd > radius:
				a = 0.0
			elif dd > radius - 1.0:
				a = radius - dd
			var t := float(y) / float(maxi(h - 1, 1))
			var c := top.lerp(bot, t)
			# top gloss highlight
			if y < 3:
				c = c.lerp(Color.WHITE, 0.14 * (1.0 - float(y) / 3.0))
			c.a = a
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func hp_bar(w: float, h: float = 22.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(w, h)
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = BAMBOO_DK
	bg.border_color = INK
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("background", bg)
	set_hp_bar(bar, 1, 1)
	return bar


static func set_hp_bar(bar: ProgressBar, cur: int, maxv: int) -> void:
	bar.max_value = maxv
	bar.value = cur
	var h: int = int(bar.custom_minimum_size.y)
	var frac := float(cur) / float(maxi(maxv, 1))
	var base := Color("b83026").lerp(Color("d9a92e"), clampf(frac - 0.25, 0.0, 1.0))
	var sb := StyleBoxTexture.new()
	sb.texture = _rounded_vgrad(64, h, base.lightened(0.28), base.darkened(0.22), 8)
	bar.add_theme_stylebox_override("fill", sb)


const KIND_TO_CTYPE := {"attack": "ATTACK", "defend": "SKILL", "debuff": "SKILL", "heal": "SKILL", "steal": "SKILL", "evade": "SKILL", "buff": "ATTACK"}

## Intent badge (v5.2): compact Slay-the-Spire style — icon + number, no big
## text labels. The telegraphed number (final, after modifiers) stays the
## most readable element on the enemy side.
## `it` = {kind, power, failed, debuff?, shown?} — `shown` is the final
## number after all modifiers (computed by the caller); falls back to power.
static func intent_badge(it: Dictionary) -> PanelContainer:
	var kind: String = it.get("kind", "attack")
	var panel := PanelContainer.new()
	var sb := StyleBoxEmpty.new()
	panel.add_theme_stylebox_override("panel", sb)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	# icon kind + number color per intent type
	var icon_kind := "ATTACK"
	var num := 0
	var num_col := INK
	match kind:
		"attack":
			icon_kind = "ATTACK"
			num = int(it.get("shown", it.get("power", 0)))
			num_col = Color("b8301e")
		"defend":
			icon_kind = "DEFENSE"
			num = int(it.get("power", 0))
			num_col = Color("2e6b8a")
		"debuff":
			icon_kind = "CONTROL"
			num = int(it.get("power", 0))
			num_col = Color("6a4a9e")
		"buff":
			icon_kind = "UTILITY"
			num = int(it.get("power", 0))
			num_col = Color("2e7b3a")
		_:
			icon_kind = "ATTACK"
			num = int(it.get("shown", it.get("power", 0)))
	# compact seal (40px, was 56)
	var seal := SealIcon.new(icon_kind, 40.0)
	box.add_child(seal)
	# number label — compact, outlined for readability
	var lab := header("", num_col, 26)
	lab.add_theme_font_override("font", font_bold())
	lab.add_theme_color_override("font_outline_color", PAPER_LT)
	lab.add_theme_constant_override("outline_size", 6)
	lab.text = str(num)
	box.add_child(lab)
	# v5.6: removed text tags — icon + number only (Rai: text looked ugly)
	if kind == "steal":
		var tag2 := label("STEAL", 11, DIM)
		box.add_child(tag2)
	elif kind == "evade":
		var tag3 := label("EVADE", 11, DIM)
		box.add_child(tag3)
	return panel


## Red silk ribbon with forked ends and gold edge (banners, top bars).
class SilkRibbon extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 10.0:
			return
		var fork := h * 0.32
		var mid := h * 0.5
		var pts := PackedVector2Array([
			Vector2(0, 4), Vector2(fork, mid), Vector2(0, h - 4),
			Vector2(12, h - 4), Vector2(w - 12, h - 4), Vector2(w, h - 4),
			Vector2(w - fork, mid), Vector2(w, 4),
			Vector2(w - 12, 4), Vector2(12, 4),
		])
		draw_colored_polygon(pts, UIH.STAMP)
		var n := pts.size()
		for i in range(n):
			draw_line(pts[i], pts[(i + 1) % n], Color("d9a92e"), 2.0)
		var pts2 := PackedVector2Array()
		for pt in pts:
			pts2.append(pt * 0.94 + Vector2(w, h) * 0.03)
		var m2 := pts2.size()
		for i in range(m2):
			draw_line(pts2[i], pts2[(i + 1) % m2], Color(1, 1, 1, 0.35), 1.0)


## Vermilion seal square with a white type glyph (for intent badges).
class SealIcon extends Control:
	var ctype := "ATTACK"
	var icon_px := 56.0
	var ink_override := Color(1, 1, 1)

	func _init(p_ctype: String = "ATTACK", px: float = 56.0) -> void:
		ctype = p_ctype
		icon_px = px
		custom_minimum_size = Vector2(px, px)
		size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# glyph child created once (never in _draw)
		var ti := TypeIcon.new(ctype, px * 0.62)
		ti.ink_override = ink_override
		ti.position = Vector2(px * 0.19, px * 0.19)
		ti.custom_minimum_size = Vector2(px * 0.62, px * 0.62)
		ti.size = Vector2(px * 0.62, px * 0.62)
		add_child(ti)

	func _draw() -> void:
		var s := icon_px
		var c := Vector2(s/2, s/2)
		var r := s/2 - 2
		# v5.7.4: circular vermilion seal (Rai: square didn't fit folk art)
		draw_circle(c, r, UIH.STAMP)
		draw_arc(c, r, 0, TAU, 32, UIH.STAMP_DK, 3.0)
		draw_arc(c, r - 6, 0, TAU, 32, Color(1, 1, 1, 0.35), 1.5)


# --- full-screen atmosphere ---

## Soft warm vignette over the whole screen.
static func vignette() -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0.25, 0.12, 0.05, 0.45))
	g.add_point(0.62, Color(0, 0, 0, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.46)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	var r := TextureRect.new()
	r.texture = t
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## No-op kept for compat: the noir film grain is gone in the Dong Ho theme.
static func grain() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Warm gradient rising from the bottom (behind the card tray).
static func bottom_shade(h: float = 320.0) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0.20, 0.10, 0.04, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_LINEAR
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	t.width = 16
	t.height = 128
	var r := TextureRect.new()
	r.texture = t
	r.anchor_left = 0.0
	r.anchor_right = 1.0
	r.anchor_top = 1.0
	r.anchor_bottom = 1.0
	r.offset_top = -h
	r.offset_left = 0
	r.offset_right = 0
	r.offset_bottom = 0
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Soft elliptical ground shadow to seat a sprite in the scene.
static func ground_shadow(w: float = 230.0, h: float = 46.0) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.85))
	g.set_color(1, Color(0, 0, 0, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	# NOTE: keep the gradient texture SQUARE (128x128). A non-square
	# GradientTexture2D silently fails to render under show_behind_parent.
	t.width = 128
	t.height = 128
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.custom_minimum_size = Vector2(w, h)
	r.size = Vector2(w, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Standard Dong Ho screen background: art + warm vignette (no grain).
static func screen_bg(art_path: String, darken: float = 0.88) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := try_tex(art_path)
	if tex:
		var t := TextureRect.new()
		t.texture = tex
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.modulate = Color(darken, darken, darken * 1.02)
		root.add_child(t)
	else:
		var c := ColorRect.new()
		c.color = PAPER_DK
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(c)
	root.add_child(vignette())
	return root


# --- icon button with badge ---

## Round icon button. Badge text drawn as a small child label (bottom-right).
static func icon_btn(tex: Texture2D, tip: String, size: float = 88.0) -> IconButton:
	var b := IconButton.new(tex, size)
	b.tooltip_text = tip
	return b


static func set_badge(b: Button, text: String) -> void:
	var badge: Label = b.get_node_or_null("Badge")
	if badge == null:
		badge = Label.new()
		badge.name = "Badge"
		badge.add_theme_font_override("font", font_bold())
		badge.add_theme_font_size_override("font_size", 15)
		badge.add_theme_color_override("font_color", PAPER_LT)
		badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		var bg := StyleBoxFlat.new()
		bg.bg_color = STAMP
		bg.set_corner_radius_all(9)
		bg.content_margin_left = 7
		bg.content_margin_right = 7
		bg.content_margin_top = 2
		bg.content_margin_bottom = 2
		badge.add_theme_stylebox_override("normal", bg)
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.position = Vector2(-6, 6)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(badge)
	badge.text = text
	badge.visible = text != ""


## Tries to load art, returns null if missing.
static func try_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var t := load(path)
		if t is Texture2D:
			return t
	return null


## Wood-framed folk print for portraits.
static func photo_frame(tex: Texture2D, w: float, h: float, caption: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER_LT
	sb.border_color = WOOD
	sb.set_border_width_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(2, 3)
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5 if caption == "" else 2
	p.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	p.add_child(vb)
	var t := TextureRect.new()
	t.texture = tex
	t.custom_minimum_size = Vector2(w, h)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	vb.add_child(t)
	if caption != "":
		var c := label(caption, 10, INK_SOFT)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(c)
	return p


## Small carved-wood chip with initials + tooltip (used for relics row).
static func relic_chip(initials: String, tip: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = WOOD
	sb.border_color = WOOD_DK
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	var l := header(initials, PAPER_LT, 12)
	p.add_child(l)
	p.tooltip_text = tip
	return p


## Popup grid to pick one card from a list. cb(index) or cb(-1) on cancel.
static func choose_card_popup(parent: Control, title: String, cards: Array, cb: Callable) -> void:
	var pop := PopupPanel.new()
	pop.title = title
	# v5.6: Grid of real CardWidgets with scroll (Rai: cards were hidden in list)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pop.add_child(vb)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(900, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	for i in range(cards.size()):
		var c: Dictionary = cards[i]
		var w := CardWidget.new(c, null)
		w.custom_minimum_size = Vector2(160, 224)
		w.size = Vector2(160, 224)
		var idx := i
		w.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: pop.hide(); cb.call(idx))
		grid.add_child(w)
	var cancel_b := btn("Cancel", 200)
	cancel_b.pressed.connect(func(): pop.hide(); cb.call(-1))
	var hc := HBoxContainer.new()
	hc.alignment = BoxContainer.ALIGNMENT_CENTER
	hc.add_child(cancel_b)
	vb.add_child(hc)
	parent.add_child(pop)
	pop.popup_centered()
