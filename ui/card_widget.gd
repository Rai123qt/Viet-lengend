class_name CardWidget
extends PanelContainer
## Visual playing card. Art loaded from res://assets/art/cards/<id>.webp,
## fallback = type-colored panel with glyph. Emits clicked on gui_input.

signal clicked(w: CardWidget)
## Emitted when the card is dragged upward (dy < -60px): play immediately.
signal drag_play(w: CardWidget)

## Mockup card size. 204 tall so the 582x847 mockup frame maps exactly.
const CARD_W := 140.0
const CARD_H := 204.0
const ART_W := 136.0
const ART_H := 108.0

## v3.3: AI-painted Dong Ho card frame textures (attack/skill/power).
static var _frame_tex := {}


static func frame_tex(ctype: String) -> Texture2D:
	var k := ctype.to_upper()
	if not _frame_tex.has(k):
		var p := "res://assets/art/vl3/cardframe-%s.png" % k.to_lower()
		_frame_tex[k] = load(p) if ResourceLoader.exists(p) else null
	return _frame_tex[k]


## v3.5: full-face AI card art (res://assets/art/vl3/cards/<id>.webp).
## Border + illustration + blank title ribbon are all painted; code only
## overlays name / description / cost / rarity. Falls back to the legacy
## frame path when a face is missing.
static var _face_tex := {}

static func face_tex(card_id: String) -> Texture2D:
	# v5.6: don't cache null — retry on next call (Rai: upgraded cards lost art)
	if _face_tex.has(card_id) and _face_tex[card_id] != null:
		return _face_tex[card_id]
	var p := "res://assets/art/vl3/cards/%s.webp" % card_id
	var tex: Texture2D = load(p) if ResourceLoader.exists(p) else null
	if tex != null:
		_face_tex[card_id] = tex
	return tex

## Banner windows on the full-face art (fractions of card), measured from
## the approved demo: blank ribbon interior ≈ x 0.16–0.84, y 0.775–0.90.
## v3.5.1: widened + lowered min fonts after render test (names clipped,
## desc invisible in v3.5.0). v3.5.2: taller text box + 6pt min so 2-line
## descriptions fit (11 long texts overflowed at 7pt).
## v3.6: v2 faces — illustration top ~60%, bottom ~38% blank paper.
## Name + description sit centered in the empty zone; code draws a divider
## line between them; the type label sits at the bottom of the zone.
const FACE_NAME_WIN := [0.10, 0.625, 0.80, 0.075]
const FACE_TEXT_WIN := [0.10, 0.725, 0.80, 0.165]
const FACE_DIV_Y := 0.712
# v5.6: paper zone is bottom 40% (y 0.60-1.0) after art crop fix
const FACE_TYPE_WIN := [0.10, 0.898, 0.80, 0.040]

static func face_win_rect(which: String, w: float, h: float) -> Rect2:
	var a: Array = FACE_TEXT_WIN
	if which == "name":
		a = FACE_NAME_WIN
	elif which == "type":
		a = FACE_TYPE_WIN
	return Rect2(a[0] * w, a[1] * h, a[2] * w, a[3] * h)


## Type color for the small type label on v2 faces.
static func face_type_color(ctype: String) -> Color:
	match ctype.to_upper():
		"SKILL":
			return Color("4a7a3a")
		"POWER":
			return Color("a87c1c")
		_:
			return Color("b83026")


## Topmost overlay child: unplayable-state stamps. Drawn as the LAST child
## of the PanelContainer so it renders above the art and labels
## (a parent's own _draw is covered by its children).
class StampOverlay extends Control:
	var kind := ""  # "", "locked"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if kind == "" or size.x < 10.0:
			return
		if kind == "locked":
			var p := Vector2(size.x - 28.0, 8.0)
			draw_arc(p + Vector2(8, 9), 6.5, PI, TAU, 16, Color("3a2c1a"), 3.0)
			draw_rect(Rect2(p + Vector2(0, 9), Vector2(16, 13)), Color("3a2c1a"))
			draw_rect(Rect2(p + Vector2(0, 9), Vector2(16, 13)), Color("e9dcc0"), false, 1.5)
			draw_circle(p + Vector2(8, 15), 2.2, Color("e9dcc0"))
			draw_line(p + Vector2(8, 15), p + Vector2(8, 19), Color("e9dcc0"), 2.0)


## Rarity dots for the full-face path (the painted art has no rarity marks).
class RarityDots extends Control:
	var rarity := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var dots := 0
		var dot_color := Color("d9a92e")  # gold default
		var dot_border := Color("8a6a1c")
		if rarity == "uncommon":
			dots = 1
		elif rarity == "rare":
			dots = 3
		elif rarity == "mythic":
			dots = 2
			dot_color = Color("9b59b6")  # purple
			dot_border = Color("5e2a7a")
		elif rarity == "legendary":
			dots = 3
			dot_color = Color("e74c3c")  # red
			dot_border = Color("7a1a0e")
		for i in range(dots):
			var p := Vector2(size.x * 0.5 + (float(i) - float(dots - 1) * 0.5) * 10.0, size.y * 0.5)
			draw_circle(p, 2.8, dot_color)
			draw_arc(p, 2.8, 0, TAU, 12, dot_border, 1.0)



## Card id -> folk icon art (res://assets/art/vl/icons/<icon>.webp).
const CARD_ICONS := {
	"strike": "slash", "defend": "shield", "grace_note": "note",
	"tune_up": "peg", "take_breath": "wind", "deep_breath": "wind",
	"second_wind": "wind", "quick_step": "wind", "wood_axe": "axe",
	"axe_swing": "axe", "heavy_fell": "crossed_axes", "execution": "saber",
	"forest_chop": "tree", "double_cut": "slash", "sweeping_cut": "saber",
	"quick_note": "note", "soft_pluck": "hand", "encore": "note",
	"piercing_melody": "arrow", "thunder_crash": "lightning",
	"rice_meal": "rice_bowl", "magic_rice_pot": "pot",
	"guard_stance": "shield", "brace": "shield", "sturdy_defense": "shield_burst",
	"last_stand": "shield_burst", "iron_bark": "bamboo",
	"battle_shout": "drum", "war_chant": "drum",
	"lullaby_hum": "moon", "sorrowful_tune": "drop", "blood_draw": "drop",
	"victory_song": "flag", "rally": "flag",
	"sturdy_strings": "lute", "divine_lute": "lute",
	"jab": "fist", "heavy_blow": "hammer", "chain_strike": "chain",
	"crippling_blow": "cracked_blade", "pommel_strike": "hilt",
	"sharpen": "dagger", "mark": "eye", "expose": "eye", "focus": "lotus",
	"fortress": "wall",
	"maw": "fangs",
}

## Dong Ho card frame, drawn in code (crisp at any size):
## diep-paper face, ink outer border, type-colored geometric band
## (attack = red triangles, skill = green leaf dots, power = gold double line),
## art window, name plaque zone, divider diamond, rarity dots.
## Layout (140x210): band strips 8..22 | art (26,32,88,68) |
## name y106..126 | divider y132 | text (24,136,92,50) centered | rarity y202.
## v3.1: text box narrowed clear of the side bands (was 12,138,116,58 —
## the old x=12 put the first character on the dark band, unreadable).
class CardFrame extends Control:
	var ctype := "ATTACK"
	var rarity := ""
	## v3.4: Mockup-derived Dong Ho frame windows, measured from the approved
	## mockup PNGs (fractions of the 140x204 card). Frames are the mockup's
	## actual borders: red triangle band (attack), green leaf band (skill),
	## gold band (power, hue-shifted from attack).
	const WIN := {
		"ATTACK": {"name": [0.141, 0.740, 0.718, 0.150], "art": [0.179, 0.211, 0.637, 0.450], "text": [0.141, 0.895, 0.718, 0.090]},
		"SKILL": {"name": [0.141, 0.740, 0.718, 0.150], "art": [0.253, 0.243, 0.539, 0.449], "text": [0.141, 0.895, 0.718, 0.090]},
		"POWER": {"name": [0.141, 0.740, 0.718, 0.150], "art": [0.179, 0.211, 0.637, 0.450], "text": [0.141, 0.895, 0.718, 0.090]},
	}

	func _init(p_ctype: String = "", p_rarity: String = "") -> void:
		ctype = p_ctype.to_upper()
		rarity = p_rarity
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	static func win_rect(ctype: String, which: String, w: float, h: float) -> Rect2:
		var d: Dictionary = WIN.get(ctype.to_upper(), WIN["ATTACK"])
		var a: Array = d[which]
		return Rect2(a[0] * w, a[1] * h, a[2] * w, a[3] * h)

	func _band_color() -> Color:
		match ctype:
			"SKILL":
				return Color("4a7a3a")
			"POWER":
				return Color("d9a92e")
			_:
				return Color("b83026")

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 10.0:
			return
		var ink := UIH.INK
		# v3.3: AI-painted Dong Ho frame texture. Falls back to code drawing.
		var ftex: Texture2D = CardWidget.frame_tex(ctype)
		if ftex != null:
			draw_texture_rect(ftex, Rect2(0, 0, w, h), false)
			# type label: drawn on the mockup's paper strip (y ~0.135)
			var f: Font = UIH.font_bold()
			var ts := f.get_string_size(ctype, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12)
			var tpos := Vector2((w - ts.x) * 0.5, h * 0.135 + ts.y * 0.35)
			draw_string_outline(f, tpos, ctype, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, 3, Color(0, 0, 0, 0.85))
			draw_string(f, tpos, ctype, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, UIH.INK)
			_draw_rarity(w)
			return
		_draw_rarity(w)
		var band := _band_color()
		# paper face
		draw_rect(Rect2(0, 0, w, h), UIH.PAPER)
		# outer ink border
		draw_rect(Rect2(1.5, 1.5, w - 3, h - 3), ink, false, 3.0)
		# type band: 4 strips forming a frame
		var t := 8.0
		var bt := 14.0
		var strips := [
			Rect2(t, t, w - t * 2, bt),
			Rect2(t, h - t - bt, w - t * 2, bt),
			Rect2(t, t + bt, bt, h - t * 2 - bt * 2),
			Rect2(w - t - bt, t + bt, bt, h - t * 2 - bt * 2),
		]
		if ctype == "POWER":
			# gold double line instead of a filled band
			for r: Rect2 in strips:
				draw_rect(r, band, false, 3.0)
				draw_rect(r.grow(-5), band, false, 1.5)
		else:
			for r: Rect2 in strips:
				draw_rect(r, band)
			_pattern(strips, band)
		# type cartouche: cream text on the top band
		var f: Font = UIH.font_bold()
		var tc := UIH.PAPER_LT if ctype != "POWER" else ink
		var ts := f.get_string_size(ctype, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11)
		draw_string(f, Vector2((w - ts.x) * 0.5, t + bt * 0.5 + ts.y * 0.38), ctype,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, tc)
		# art window border
		draw_rect(Rect2(24, 30, 92, 72), ink, false, 2.0)
		# divider diamond under the name
		var dc := Vector2(w * 0.5, 132)
		var dsz := 4.0
		draw_colored_polygon(PackedVector2Array([
			dc + Vector2(0, -dsz), dc + Vector2(dsz, 0),
			dc + Vector2(0, dsz), dc + Vector2(-dsz, 0)]), ink)
		draw_line(Vector2(30, 132), Vector2(dc.x - 8, 132), ink, 1.0)
		draw_line(Vector2(dc.x + 8, 132), Vector2(w - 30, 132), ink, 1.0)
	func _draw_rarity(w: float) -> void:
		var dots := 0
		if rarity == "uncommon":
			dots = 1
		elif rarity == "rare":
			dots = 3
		for i in range(dots):
			var dx := w * 0.5 + (float(i) - float(dots - 1) * 0.5) * 12.0
			draw_circle(Vector2(dx, 202), 3.2, Color("d9a92e"))
			draw_arc(Vector2(dx, 202), 3.2, 0, TAU, 12, Color("8a6a1c"), 1.0)

	func _pattern(strips: Array, band: Color) -> void:
		var ink := UIH.INK
		if ctype == "ATTACK":
			# black triangle zigzag along each strip
			for r: Rect2 in strips:
				var horiz: bool = r.size.x > r.size.y
				var n := int((r.size.x if horiz else r.size.y) / 12.0)
				for i in range(n):
					var t0 := float(i) / float(maxi(n, 1))
					var t1 := float(i + 1) / float(maxi(n, 1))
					if horiz:
						var x0 := r.position.x + t0 * r.size.x
						var x1 := r.position.x + t1 * r.size.x
						var ym := r.position.y + r.size.y * 0.5
						var up := (r.position.y < size.y * 0.5) != (i % 2 == 0)
						var tip := Vector2((x0 + x1) * 0.5, r.position.y + (2.0 if up else r.size.y - 2.0))
						draw_colored_polygon(PackedVector2Array([
							Vector2(x0 + 1, ym), Vector2(x1 - 1, ym), tip]), ink)
					else:
						var y0 := r.position.y + t0 * r.size.y
						var y1 := r.position.y + t1 * r.size.y
						var xm := r.position.x + r.size.x * 0.5
						var left := (r.position.x < size.x * 0.5) != (i % 2 == 0)
						var tip2 := Vector2(r.position.x + (2.0 if left else r.size.x - 2.0), (y0 + y1) * 0.5)
						draw_colored_polygon(PackedVector2Array([
							Vector2(xm, y0 + 1), Vector2(xm, y1 - 1), tip2]), ink)
		else:
			# leaf dots: dark green circles spaced along each strip
			var dot := band.darkened(0.35)
			for r: Rect2 in strips:
				var horiz: bool = r.size.x > r.size.y
				var n := int((r.size.x if horiz else r.size.y) / 14.0)
				for i in range(n + 1):
					var t0 := float(i) / float(maxi(n, 1))
					var p := Vector2(
						r.position.x + (t0 * r.size.x if horiz else r.size.x * 0.5),
						r.position.y + (r.size.y * 0.5 if horiz else t0 * r.size.y))
					draw_circle(p, 2.6, dot)


## Gold coin cost (dong tien): dark rim, gold face, black number.
class CostDisc extends Control:
	var cost := 0
	var num_color := Color.BLACK

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(34, 34)

	func set_cost(v: int, energy_ok: bool) -> void:
		cost = v
		num_color = Color.BLACK if energy_ok else Color("a02828")
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 1.0
		# dark rim + gold face + inner ring, like an old coin
		draw_circle(c, r, Color("5a4416"))
		draw_circle(c, r - 2.5, Color("d9a92e"))
		draw_arc(c, r - 6.0, 0, TAU, 32, Color("a87c1c"), 1.5)
		draw_arc(c, r - 3.0, PI * 0.7, PI * 1.7, 24, Color("f2d675"), 2.0)
		var f: Font = UIH.font_bold()
		var t := "—" if cost < 0 else str(cost)
		var ts := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 19)
		draw_string(f, c + Vector2(-ts.x * 0.5, ts.y * 0.38), t,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 19, num_color)

var card: Dictionary = {}
var bs: BattleState = null
var playable := true
var play_reason := ""
## When true the widget is a zoom/inspect clone: no input handling, no hover.
var inspect_only := false
## Tap-to-inspect: first tap lifts + enlarges the card for reading;
## tapping it again plays it.
var armed := false
var _base_y := -1.0
## Unplayable-state overlay kind: "", "locked".
var _ov := ""
var _overlay: StampOverlay = null

var _art_rect: TextureRect
var _name_l: RichTextLabel
var _cost_disc: CostDisc
var _text_l: RichTextLabel

# long-press-to-zoom tracking
var _lp_down := false
var _lp_pos := Vector2.ZERO
var _lp_gen := 0
var _lp_zoomed := false
var _zoom_layer: Control = null
const LP_HOLD := 0.5
const LP_SLOP := 20.0
# drag-to-play tracking: drag upward fast = play immediately
var _drag_d := Vector2.ZERO
var _dragged := false
var _dragging := false
const DRAG_UP := -60.0
const DRAG_LIFT := -20.0
# armed (tap-to-inspect) gold border highlight
var _sb: StyleBoxFlat = null
var _base_border := Color.BLACK

## One-line glossary for keywords that may appear in card text, with the real
## numbers from battle_state.gd. The zoom view lists only the keywords
## actually present on the card.
const GLOSSARY := [
	["WEAK", "Weak: deals 25% less attack damage. Loses 1 each turn."],
	["VULNERABLE", "Vulnerable: takes 50% more attack damage. Loses 1 each turn."],
	["BLOCK", "Block: absorbs damage first. Fades at end of turn."],
	["STRENGTH", "Strength: +1 damage on every attack. Lasts the battle."],
	["CHORD", "Chord: play Attack/Skill cards and your note string builds automatically (red = Attack, green = Skill). Complete a known chord's note order for a bonus (max 1 per turn). A wrong note snaps the string."],
	["GRACE NOTE", "Grace note: Power cards never advance nor break your chord."],
	["ENERGY", "Energy: spend to play cards; refills each turn."],
]

## Keywords highlighted bold + colored in the description (BBCode).
const KEYWORD_COLORS := {
	"WEAK": "6a6a7a",
	"VULNERABLE": "b83026",
	"BLOCK": "3b6ea5",
	"STRENGTH": "b83026",
	"CHORD": "a87c1c",
	"GRACE NOTE": "6a5a9a",
	"ENERGY": "a87c1c",
}
const KEYWORD_PATTERNS := [
	["\\bWeak\\b", "WEAK"],
	["\\bVulnerable\\b", "VULNERABLE"],
	["\\bBlock\\b", "BLOCK"],
	["\\bStrength\\b", "STRENGTH"],
	["\\bchord\\b", "CHORD"],
	["\\bgrace note\\b", "GRACE NOTE"],
	["\\bEnergy\\b", "ENERGY"],
]


func _init(p_card: Dictionary = {}, p_bs: BattleState = null) -> void:
	card = p_card
	bs = p_bs
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	size = Vector2(CARD_W, CARD_H)
	size_flags_horizontal = Control.SIZE_FILL
	size_flags_vertical = Control.SIZE_FILL
	mouse_filter = MOUSE_FILTER_STOP


func _ready() -> void:
	var d := CardDB.get_def(card.get("id", ""))
	var ctype: String = d.get("ctype", "")
	# === Dong Ho frame layout (see CardFrame for geometry) ===
	# Card definition: drop shadow so it pops from the bg
	var clear_sb := StyleBoxFlat.new()
	clear_sb.bg_color = Color(0, 0, 0, 0)
	clear_sb.set_border_width_all(0)
	clear_sb.shadow_color = Color(0, 0, 0, 0.7)
	clear_sb.shadow_size = 10
	clear_sb.shadow_offset = Vector2(0, 4)
	add_theme_stylebox_override("panel", clear_sb)
	# Wrapper: plain Control so PanelContainer doesn't auto-resize children
	var root := Control.new()
	root.position = Vector2.ZERO
	root.size = Vector2(CARD_W, CARD_H)
	root.custom_minimum_size = Vector2(CARD_W, CARD_H)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# Background: v3.5 full-face AI art when available, else legacy frame.
	var face: Texture2D = face_tex(card.get("id", ""))
	var use_face := face != null
	if use_face:
		var face_rect := TextureRect.new()
		face_rect.texture = face
		face_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face_rect.stretch_mode = TextureRect.STRETCH_SCALE
		face_rect.position = Vector2.ZERO
		face_rect.custom_minimum_size = Vector2(CARD_W, CARD_H)
		face_rect.size = Vector2(CARD_W, CARD_H)
		face_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(face_rect)
		_art_rect = null
	else:
		# Background: Dong Ho frame drawn in code (type band, art window, divider)
		var bg := CardFrame.new(ctype, str(d.get("rarity", "")))
		bg.position = Vector2.ZERO
		bg.size = Vector2(CARD_W, CARD_H)
		bg.custom_minimum_size = Vector2(CARD_W, CARD_H)
		root.add_child(bg)

		# Art: folk icon inside the AI frame's art window (per-type, v3.3)
		var awin: Rect2 = CardFrame.win_rect(ctype, "art", CARD_W, CARD_H)
		_art_rect = TextureRect.new()
		_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_art_rect.position = awin.position + Vector2(3, 3)
		_art_rect.custom_minimum_size = awin.size - Vector2(6, 6)
		_art_rect.size = awin.size - Vector2(6, 6)
		_art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tex := UIH.try_tex("res://assets/art/cards/%s.webp" % card.get("id", ""))
		if tex == null:
			tex = _card_icon(card.get("id", ""), ctype)
		_art_rect.texture = tex
		root.add_child(_art_rect)

	# Cost: gold coin top-left, overlapping the corner like the mockup
	_cost_disc = CostDisc.new()
	_cost_disc.position = Vector2(2, 2)
	_cost_disc.set_cost(d.get("cost", 0), true)
	root.add_child(_cost_disc)

	# Name + description: on the painted ribbon (face path) or the frame
	# windows (legacy path).
	var nwin: Rect2
	var twin: Rect2
	if use_face:
		nwin = face_win_rect("name", CARD_W, CARD_H)
		twin = face_win_rect("text", CARD_W, CARD_H)
	else:
		nwin = CardFrame.win_rect(ctype, "name", CARD_W, CARD_H)
		twin = CardFrame.win_rect(ctype, "text", CARD_W, CARD_H)
	# v3.5: name as RichTextLabel (Label clamps to its min line-height and
	# overlaps the desc on the small painted ribbon; RTL respects set size).
	_name_l = RichTextLabel.new()
	_name_l.bbcode_enabled = true
	_name_l.scroll_active = false
	_name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	_name_l.position = nwin.position
	_name_l.custom_minimum_size = nwin.size
	_name_l.size = nwin.size
	_name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# v3.6: Squada One display font for the card name (mockup match).
	_name_l.add_theme_font_override("normal_font", UIH.font_title())
	_name_l.add_theme_font_override("bold_font", UIH.font_title())
	_name_l.add_theme_font_size_override("normal_font_size", 13)
	_name_l.add_theme_font_size_override("bold_font_size", 13)
	_name_l.add_theme_color_override("default_color", UIH.INK if use_face else UIH.PAPER_LT)
	if not use_face:
		_name_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_name_l.add_theme_constant_override("outline_size", 3)
	_name_l.text = "[center]" + CardDB.card_name(card) + "[/center]"
	root.add_child(_name_l)
	_fit_name()

	# Description: ink on paper, centered in the text window.
	_text_l = RichTextLabel.new()
	_text_l.bbcode_enabled = true
	_text_l.scroll_active = false
	_text_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_l.position = twin.position + Vector2(4, 1)
	_text_l.custom_minimum_size = twin.size - Vector2(8, 2)
	_text_l.size = twin.size - Vector2(8, 2)
	_text_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_l.add_theme_font_override("normal_font", UIH.font_reg())
	_text_l.add_theme_font_override("bold_font", UIH.font_bold())
	_text_l.add_theme_font_size_override("normal_font_size", 10)
	_text_l.add_theme_font_size_override("bold_font_size", 10)
	_text_l.add_theme_color_override("default_color", UIH.INK_SOFT)
	# subtle light outline keeps desc readable over the ribbon's trim
	_text_l.add_theme_color_override("font_outline_color", Color(0.96, 0.92, 0.80, 0.9))
	_text_l.add_theme_constant_override("outline_size", 2)
	# v5.6: paper backing behind text for face path (Rai: art covers text on some cards)
	if use_face:
		var tsb := StyleBoxFlat.new()
		tsb.bg_color = Color(0.96, 0.92, 0.80, 0.85)
		tsb.set_corner_radius_all(4)
		_text_l.add_theme_stylebox_override("normal", tsb)
		var nsb := StyleBoxFlat.new()
		nsb.bg_color = Color(0.96, 0.92, 0.80, 0.85)
		nsb.set_corner_radius_all(4)
		_name_l.add_theme_stylebox_override("normal", nsb)
	root.add_child(_text_l)
	_fit_text()

	# v3.6: on v2 faces, draw a divider line between name and description,
	# plus a small type label at the bottom of the empty zone.
	if use_face:
		var div := ColorRect.new()
		div.color = Color(UIH.INK, 0.7)
		var div_w := CARD_W * 0.60
		div.position = Vector2((CARD_W - div_w) * 0.5, CARD_H * FACE_DIV_Y)
		div.custom_minimum_size = Vector2(div_w, 2)
		div.size = Vector2(div_w, 2)
		div.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(div)
		var tywin := face_win_rect("type", CARD_W, CARD_H)
		var tlabel := Label.new()
		tlabel.text = ctype
		tlabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tlabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tlabel.position = tywin.position
		tlabel.custom_minimum_size = tywin.size
		tlabel.size = tywin.size
		tlabel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tlabel.add_theme_font_override("font", UIH.font_title())
		tlabel.add_theme_font_size_override("font_size", 10)
		tlabel.add_theme_color_override("font_color", face_type_color(ctype))
		root.add_child(tlabel)

	# Rarity dots: drawn by the legacy frame itself; for the face path add
	# a small overlay near the bottom of the text zone (v3.6: below type).
	if use_face:
		var rdots := RarityDots.new()
		rdots.rarity = str(d.get("rarity", ""))
		rdots.position = Vector2(0, CARD_H * 0.955)
		rdots.custom_minimum_size = Vector2(CARD_W, 8)
		rdots.size = Vector2(CARD_W, 8)
		root.add_child(rdots)

	# Foil shine for rares (animated sweep)
	if str(d.get("rarity", "")) == "rare":
		clip_contents = true
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 0))
		grad.set_color(1, Color(1, 1, 1, 0))
		grad.add_point(0.5, Color(1, 1, 1, 0.35))
		var gtex := GradientTexture2D.new()
		gtex.gradient = grad
		gtex.fill_from = Vector2(0.35, 0)
		gtex.fill_to = Vector2(0.65, 0)
		gtex.width = 256
		gtex.height = 256
		var shine := TextureRect.new()
		shine.texture = gtex
		shine.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shine.stretch_mode = TextureRect.STRETCH_SCALE
		shine.custom_minimum_size = Vector2(CARD_W * 2.2, CARD_H * 1.4)
		shine.rotation = 0.45
		shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shine.modulate.a = 0.0
		root.add_child(shine)
		shine.position = Vector2(-CARD_W * 1.4, -20)
		var tw := create_tween().set_loops()
		tw.tween_interval(1.2)
		tw.tween_property(shine, "modulate:a", 1.0, 0.25)
		tw.tween_property(shine, "position:x", CARD_W * 0.9, 1.1).set_trans(Tween.TRANS_SINE)
		tw.tween_property(shine, "modulate:a", 0.0, 0.35)
		tw.tween_callback(func(): shine.position = Vector2(-CARD_W * 1.4, -20))

	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	# topmost overlay child for unplayable-state stamps (drawn above art+labels)
	_overlay = StampOverlay.new()
	add_child(_overlay)
	# v5.2: gold "+" badge for upgraded cards — unmistakable at a glance
	if card.get("upgraded", false):
		var badge := PanelContainer.new()
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = Color("d9a92e")
		bsb.set_corner_radius_all(12)
		bsb.border_color = Color("7a5a1a")
		bsb.set_border_width_all(2)
		badge.add_theme_stylebox_override("panel", bsb)
		var blab := Label.new()
		blab.text = "+"
		blab.add_theme_font_override("font", UIH.font_bold())
		blab.add_theme_font_size_override("font_size", 20)
		blab.add_theme_color_override("font_color", Color("2e2013"))
		blab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		blab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(blab)
		badge.custom_minimum_size = Vector2(28, 28)
		badge.size = Vector2(28, 28)
		badge.position = Vector2(CARD_W - 34, 6)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(badge)
	refresh_state()


## Wrap keywords in bold + color BBCode.
func _rich_text(plain: String) -> String:
	var out := plain
	var rx := RegEx.new()
	for p in KEYWORD_PATTERNS:
		rx.compile("(?i)" + p[0])
		out = rx.sub(out, "[b][color=#" + KEYWORD_COLORS[p[1]] + "]$0[/color][/b]", true)
	return out


## Shrink card name font (13 -> 8 min) so long names fit the v2 text zone.
## Fits BOTH width and height — RichTextLabel does not clip overflow, so
## an oversized name would bleed into the description. v3.6 measures with
## the Squada One title font.
## Called in _ready after the name label is built.
func _fit_name() -> void:
	var f: Font = UIH.font_title()
	var txt := CardDB.card_name(card)
	var fs := 13
	var maxw := _name_l.size.x - 4.0
	var maxh := _name_l.size.y
	while fs > 8:
		var sz := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
		if sz.x <= maxw and sz.y <= maxh:
			break
		fs -= 1
	_name_l.add_theme_font_size_override("normal_font_size", fs)
	_name_l.add_theme_font_size_override("bold_font_size", fs)


## Shrink card description font (10 -> 6 min) so 2-line texts fit the
## painted ribbon; centered for even alignment with the name. Full text
## always readable via tap-to-inspect zoom.
func _fit_text() -> void:
	const MAX_FS := 10
	const MIN_FS := 6
	var f: Font = UIH.font_reg()
	var plain := CardDB.card_text(card)
	# v3.5: fit inside the painted ribbon's text area
	var avail_w := _text_l.size.x
	var avail_h := _text_l.size.y
	var fs := MAX_FS
	while fs > MIN_FS:
		var sz := f.get_multiline_string_size(plain, HORIZONTAL_ALIGNMENT_CENTER, avail_w, fs)
		if sz.y <= avail_h:
			break
		fs -= 1
	_text_l.add_theme_font_size_override("normal_font_size", fs)
	_text_l.add_theme_font_size_override("bold_font_size", fs)
	_text_l.text = "[center]" + _rich_text(plain) + "[/center]"


func _on_hover(hovered: bool) -> void:
	if inspect_only or not playable or armed or _dragging:
		return
	pivot_offset = Vector2(size.x * 0.5, size.y)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(1.07, 1.07) if hovered else Vector2.ONE, 0.12)


## Tap-to-inspect: lift the card and scale 1.3x around the bottom-center pivot
## so its text is readable on phones, with a gold border highlight and raised
## z-index above the other cards. Tap again (handled by the battle screen)
## to play it. Dragging upward applies the same lift.
func set_armed(v: bool) -> void:
	if armed == v or inspect_only:
		return
	armed = v
	_update_lift()


func _set_dragging(v: bool) -> void:
	if _dragging == v or inspect_only:
		return
	_dragging = v
	_update_lift()


func _update_lift() -> void:
	var lift := armed or _dragging
	if _base_y < 0.0:
		_base_y = position.y
	pivot_offset = Vector2(size.x * 0.5, size.y)
	if _sb:
		_sb.border_color = Color(1.0, 0.80, 0.28) if armed else _base_border
		_sb.set_border_width_all(4 if armed else 3)
	z_index = 5 if lift else 0
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", _base_y - (20.0 if lift else 0.0), 0.15)
	tw.tween_property(self, "scale", Vector2(1.3, 1.3) if lift else Vector2.ONE, 0.15)


## State overlays are drawn by the StampOverlay child (topmost), not here:
## a Control's own _draw is covered by its children (e.g. the art TextureRect).
func _draw() -> void:
	pass


func _eff_cost() -> int:
	if bs:
		return bs.card_cost(card)
	return CardDB.get_def(card.get("id", "")).get("cost", 0)


## Folk icon for a card: generated Dong Ho icon, then the type art,
## then a code-drawn paper wash as a last resort.
func _card_icon(card_id: String, ctype: String) -> Texture2D:
	var icon: String = CARD_ICONS.get(card_id, "")
	if icon != "":
		var tex := UIH.try_tex("res://assets/art/vl/icons/%s.webp" % icon)
		if tex:
			return tex
	var tex2 := UIH.try_tex("res://assets/art/vl/card_art_%s.webp" % ctype.to_lower())
	if tex2:
		return tex2
	# Code-drawn placeholder: aged paper with a type-colored wash.
	var col: Color = CardDB.TYPE_COLORS.get(ctype, UIH.DIM)
	var img := Image.create(int(ART_W), int(ART_H), false, Image.FORMAT_RGBA8)
	img.fill(Color("d9c9a6"))
	for y in range(int(ART_H)):
		for x in range(int(ART_W)):
			var dx := (x - ART_W * 0.5) / (ART_W * 0.5)
			var dy := (y - ART_H * 0.5) / (ART_H * 0.5)
			var d := sqrt(dx * dx + dy * dy)
			var g := clampf(1.0 - d, 0.0, 1.0) * 0.45
			var c := Color("d9c9a6").lerp(col, g * 0.55)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func refresh_state() -> void:
	if bs == null or card.is_empty():
		return
	var r: Dictionary = bs.can_play(_hand_index())
	playable = r["ok"]
	play_reason = r["reason"]
	var reason: String = r["reason"]
	# gold cost disc; number turns red when energy is the blocker
	_cost_disc.set_cost(_eff_cost(), reason != "Not enough energy.")
	# unplayable-state overlays (dossier stamps)
	_ov = ""
	modulate = Color(1, 1, 1, 1) if playable else Color(0.55, 0.55, 0.6, 1)
	tooltip_text = "" if playable else play_reason
	if _overlay:
		_overlay.kind = _ov
		_overlay.queue_redraw()


func _hand_index() -> int:
	if bs == null:
		return -1
	for i in range(bs.hand.size()):
		if bs.hand[i].get("uid", -1) == card.get("uid", -2):
			return i
	return -1


func _input(event: InputEvent) -> void:
	if inspect_only or not is_inside_tree():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			if get_global_rect().has_point(mb.global_position):
				_lp_down = true
				_lp_pos = mb.global_position
				_drag_d = Vector2.ZERO
				_dragged = false
				_lp_gen += 1
				var g := _lp_gen
				await get_tree().create_timer(LP_HOLD).timeout
				if _lp_gen == g and _lp_down:
					_lp_down = false
					_set_dragging(false)
					_show_zoom()
		else:
			if _dragged:
				# drag-play already fired; swallow the release
				_dragged = false
				_drag_d = Vector2.ZERO
				_set_dragging(false)
				accept_event()
			elif _lp_zoomed:
				_hide_zoom()
				accept_event()
			elif _lp_down:
				_lp_down = false
				_lp_gen += 1
				_set_dragging(false)
				clicked.emit(self)
				accept_event()
	elif event is InputEventMouseMotion and _lp_down:
		var mm := event as InputEventMouseMotion
		_drag_d += mm.relative
		if _drag_d.y < DRAG_UP and not _dragged:
			# dragged upward: play immediately, cancel tap/long-press
			_dragged = true
			_lp_down = false
			_lp_gen += 1
			_set_dragging(false)
			drag_play.emit(self)
			accept_event()
		elif _drag_d.y < DRAG_LIFT and not _dragging and not _dragged:
			# lifting: enlarge the card while the finger travels up
			_set_dragging(true)
		elif (mm.global_position - _lp_pos).length() > LP_SLOP and _drag_d.y >= DRAG_UP:
			_lp_down = false
			_lp_gen += 1
			_set_dragging(false)


func _on_gui_input(_event: InputEvent) -> void:
	pass


func _show_zoom() -> void:
	if _lp_zoomed:
		return
	_lp_zoomed = true
	_zoom_layer = Control.new()
	_zoom_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_zoom_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zoom_layer.add_child(dim)
	var big := CardWidget.new(card, null)
	big.inspect_only = true
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	big.scale = Vector2(2.2, 2.2)
	# center in the widget's own viewport (logical 1280x720 with stretch)
	var vsz := get_viewport_rect().size
	big.position = (vsz - Vector2(CARD_W, CARD_H) * 2.2) * 0.5
	big.modulate.a = 0.0
	_zoom_layer.add_child(big)
	get_tree().root.add_child(_zoom_layer)
	_add_glossary(vsz, big.position)
	var tw := big.create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	tw.tween_property(big, "modulate:a", 1.0, 0.18)
	tw.tween_property(big, "scale", Vector2(2.3, 2.3), 0.18)


## Keyword glossary strip under the zoomed card: explains the buffs/debuffs
## and terms named on this card, one line each. Only shown when the card
## text actually mentions the keyword.
func _add_glossary(vsz: Vector2, card_pos: Vector2) -> void:
	var lines := _glossary_for(card)
	if lines.is_empty():
		return
	var gp := PanelContainer.new()
	gp.add_theme_stylebox_override("panel", UIH.paper_style(UIH.INK, 2, 3))
	gp.custom_minimum_size = Vector2(440, 0)
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 2)
	gp.add_child(gv)
	var gh := UIH.label("KEYWORDS", 12, UIH.DIM)
	gh.add_theme_font_override("font", UIH.font_bold())
	gv.add_child(gh)
	for line in lines:
		var gl := UIH.label(line, 11, Color("2a2318"))
		gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gl.custom_minimum_size = Vector2(420, 0)
		gv.add_child(gl)
	_zoom_layer.add_child(gp)
	var card_bottom := card_pos.y + CARD_H * 2.2
	gp.position = Vector2((vsz.x - 440.0) * 0.5, minf(card_bottom + 10.0, vsz.y - 60.0))


func _glossary_for(p_card: Dictionary) -> Array:
	var out := []
	var text := CardDB.card_text(p_card).to_upper()
	for kw in GLOSSARY:
		if text.contains(kw[0]):
			out.append(kw[1])
	return out


func _hide_zoom() -> void:
	_lp_zoomed = false
	if _zoom_layer and is_instance_valid(_zoom_layer):
		_zoom_layer.queue_free()
	_zoom_layer = null


func _exit_tree() -> void:
	_hide_zoom()
