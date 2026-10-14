class_name MapSeal
extends RefCounted
## Red-seal stamp node icons for the campaign map. Code-drawn white carved
## icons on a vermilion seal disc — crisp at any size, consistent across
## node types. Replaces the old blurry emoji glyphs (v3.9.3).

const SEAL_RED := Color(0.70, 0.15, 0.11, 0.95)
const SEAL_RED_DIM := Color(0.45, 0.12, 0.10, 0.9)
const SEAL_GRAY := Color(0.38, 0.34, 0.30, 0.9)
const INK := Color(0.10, 0.08, 0.07, 1.0)
const CREAM := Color(0.96, 0.90, 0.76, 1.0)
const GOLD := Color(0.95, 0.80, 0.40, 1.0)
const CARVE := Color(0.97, 0.93, 0.84, 1.0)  # carved white icon


## Full node: seal disc + carved icon + state styling.
## state: "LOCKED" | "AVAILABLE" | "CLEARED" | "CURRENT"
static func draw_node(ci: CanvasItem, ntype: String, state: String,
		c: Vector2, r: float, t: float = 0.0) -> void:
	var bg_col := SEAL_RED
	var line_col := INK
	var alpha := 1.0
	match state:
		"LOCKED":
			alpha = 0.55
			bg_col = SEAL_RED_DIM
		"AVAILABLE":
			line_col = GOLD
		"CLEARED":
			alpha = 0.6
			bg_col = SEAL_GRAY
		"CURRENT":
			line_col = GOLD
	var pr := r
	if state == "CURRENT":
		pr = r + 4.0 * (0.5 + 0.5 * sin(t * 4.0))
		ci.draw_arc(c, pr + 6.0, 0, TAU, 32, Color(GOLD, 0.6 * alpha), 2.0, true)
	# seal disc
	ci.draw_circle(c, pr, Color(bg_col, alpha))
	var border_w := 2.5
	if ntype == "ELITE":
		border_w = 4.5  # elite: bolder carved border
	ci.draw_arc(c, pr, 0, TAU, 40, Color(line_col, alpha), border_w, true)
	if ntype == "ELITE":
		ci.draw_arc(c, pr - 4.0, 0, TAU, 40, Color(line_col, alpha * 0.8), 1.5, true)
	# thin cream inner ring — seal-stamp feel
	ci.draw_arc(c, pr - 7.0, 0, TAU, 40, Color(CREAM, 0.85 * alpha), 1.5, true)
	# carved icon
	draw_icon(ci, ntype, c, pr * 0.70, Color(CARVE, alpha))
	if state == "CLEARED":
		var f := ThemeDB.fallback_font
		ci.draw_string(f, c + Vector2(pr * 0.55, -pr * 0.55), "✓",
			HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color(0.5, 0.85, 0.5, 0.9))
	if ntype == "BOSS":
		ci.draw_arc(c, pr + 10.0, 0, TAU, 44,
			Color(0.62, 0.15, 0.12, 0.8 * alpha), 3.0, true)


## White carved icon per node type. s ≈ half-size of the icon area.
static func draw_icon(ci: CanvasItem, kind: String, c: Vector2, s: float, col: Color) -> void:
	match kind:
		"BATTLE", "ELITE":
			_draw_axes(ci, c, s, col)
		"SHOP":
			# ancient cash coin: ring + square hole
			ci.draw_arc(c, s * 0.62, 0, TAU, 32, col, s * 0.22, true)
			var q := s * 0.32
			ci.draw_rect(Rect2(c - Vector2(q, q), Vector2(q * 2.0, q * 2.0)), col, false, s * 0.14)
		"EVENT":
			var f := ThemeDB.fallback_font
			var fs := int(s * 1.6)
			var ts: Vector2 = f.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var ascent := f.get_ascent(fs)
			var descent := f.get_descent(fs)
			var pos := Vector2(c.x - ts.x * 0.5, c.y + (ascent - descent) * 0.5)
			ci.draw_string(f, pos, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		"REST":
			# rice bowl: bowl arc + rim + rice mound + chopsticks
			ci.draw_arc(c + Vector2(0, s * 0.18), s * 0.62, 0.12 * PI, 0.88 * PI, 24, col, s * 0.20, true)
			ci.draw_line(c + Vector2(-s * 0.60, s * 0.18), c + Vector2(s * 0.60, s * 0.18), col, s * 0.20, true)
			ci.draw_arc(c + Vector2(0, s * 0.10), s * 0.32, PI, TAU, 16, col, s * 0.15, true)
			ci.draw_line(c + Vector2(s * 0.08, -s * 0.78), c + Vector2(s * 0.40, -s * 0.02), col, s * 0.11, true)
			ci.draw_line(c + Vector2(s * 0.30, -s * 0.78), c + Vector2(s * 0.58, -s * 0.02), col, s * 0.11, true)
		"BOSS":
			_draw_demon(ci, c, s, col)
		"START":
			# village gate: two posts + double lintel
			ci.draw_line(c + Vector2(-s * 0.45, s * 0.58), c + Vector2(-s * 0.45, -s * 0.34), col, s * 0.20, true)
			ci.draw_line(c + Vector2(s * 0.45, s * 0.58), c + Vector2(s * 0.45, -s * 0.34), col, s * 0.20, true)
			ci.draw_line(c + Vector2(-s * 0.68, -s * 0.44), c + Vector2(s * 0.68, -s * 0.44), col, s * 0.22, true)
			ci.draw_line(c + Vector2(-s * 0.56, -s * 0.14), c + Vector2(s * 0.56, -s * 0.14), col, s * 0.15, true)
		"CLINIC":
			# medicine cross
			ci.draw_line(c + Vector2(-s * 0.48, 0), c + Vector2(s * 0.48, 0), col, s * 0.28, true)
			ci.draw_line(c + Vector2(0, -s * 0.48), c + Vector2(0, s * 0.48), col, s * 0.28, true)
		_:
			ci.draw_circle(c, s * 0.18, col)


## Crossed woodcutter axes.
static func _draw_axes(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	for sgn in [-1.0, 1.0]:
		var dir := Vector2(sgn * 0.55, -0.55).normalized()
		var base := c - dir * s * 0.58
		var top := c + dir * s * 0.58
		ci.draw_line(base, top, col, s * 0.22, true)
		# axe head: wedge blade at the top end
		var perp := Vector2(-dir.y, dir.x)
		var p1 := top + perp * s * 0.44 - dir * s * 0.06
		var p2 := top - perp * s * 0.10 + dir * s * 0.10
		var p3 := top + dir * s * 0.34 + perp * s * 0.17
		ci.draw_colored_polygon(PackedVector2Array([p1, p2, p3]), col)


## Stylized demon/oni face for the boss seal.
static func _draw_demon(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	# face outline
	ci.draw_arc(c, s * 0.60, 0, TAU, 28, col, s * 0.18, true)
	# horns
	for sgn in [-1.0, 1.0]:
		var bx: float = c.x + sgn * s * 0.40
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(bx - sgn * s * 0.17, c.y - s * 0.50),
			Vector2(bx + sgn * s * 0.17, c.y - s * 0.50),
			Vector2(bx + sgn * s * 0.04, c.y - s * 0.96)]), col)
	# angry eyes
	ci.draw_line(c + Vector2(-s * 0.38, -s * 0.10), c + Vector2(-s * 0.08, -s * 0.26), col, s * 0.16, true)
	ci.draw_line(c + Vector2(s * 0.38, -s * 0.10), c + Vector2(s * 0.08, -s * 0.26), col, s * 0.16, true)
	# grinning mouth
	ci.draw_arc(c + Vector2(0, s * 0.06), s * 0.38, 0.22 * PI, 0.78 * PI, 20, col, s * 0.13, true)
	# fangs
	for sgn in [-1.0, 1.0]:
		var fx: float = c.x + sgn * s * 0.22
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(fx - s * 0.10, c.y + s * 0.34),
			Vector2(fx + s * 0.10, c.y + s * 0.34),
			Vector2(fx, c.y + s * 0.60)]), col)
