class_name TypeIcon
extends Control
## Small hand-inked card-type glyph: sword (ATTACK), shield (DEFENSE),
## crescent moon (CONTROL), star-cloud (UTILITY). Drawn in _draw, no textures.

var ctype := "ATTACK"
var icon_px := 24.0
## Optional ink override: when alpha > 0 the glyph draws in this color
## instead of the verb color (e.g. white icon on a dark badge).
var ink_override := Color(0, 0, 0, 0)


func _init(p_ctype: String = "ATTACK", p_px: float = 24.0) -> void:
	ctype = p_ctype
	icon_px = p_px
	custom_minimum_size = Vector2(p_px, p_px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var col: Color = CardDB.TYPE_COLORS.get(ctype, UIH.DIM)
	if ink_override.a > 0.0:
		col = ink_override
	var s := icon_px
	var c := Vector2(s * 0.5, s * 0.5)
	match ctype:
		"ATTACK":
			# hand-inked sword, diagonal: tapered blade, crossguard, grip, pommel
			var tip := c + Vector2(s * 0.30, -s * 0.36)
			var base := c + Vector2(-s * 0.08, s * 0.08)
			var dir := (tip - base).normalized()
			var nrm := Vector2(-dir.y, dir.x)
			var blade := PackedVector2Array([
				tip,
				base + nrm * s * 0.075,
				base - nrm * s * 0.075,
			])
			draw_colored_polygon(blade, col)
			# blade shadow edge + fuller line
			draw_line(base + nrm * s * 0.075, tip, col.darkened(0.3), 1.2, true)
			draw_line(base + dir * s * 0.04, tip - dir * s * 0.07, col.darkened(0.35), 1.2, true)
			# crossguard
			draw_line(base + nrm * s * 0.17, base - nrm * s * 0.17, col, 3.5, true)
			# grip
			var grip_end := base - dir * s * 0.24
			draw_line(base, grip_end, col.darkened(0.15), 4.5, true)
			# pommel
			draw_circle(grip_end, s * 0.065, col)
		"DEFENSE":
			# shield outline
			var pts := PackedVector2Array([
				c + Vector2(0, -s * 0.36),
				c + Vector2(s * 0.30, -s * 0.22),
				c + Vector2(s * 0.30, s * 0.08),
				c + Vector2(0, s * 0.36),
				c + Vector2(-s * 0.30, s * 0.08),
				c + Vector2(-s * 0.30, -s * 0.22),
			])
			draw_polyline(pts, col, 3.0, true)
			draw_polyline(pts, col.darkened(0.2), 1.0, true)
			# shield boss dot
			draw_circle(c, 2.2, col)
		"CONTROL":
			# crescent moon: filled disc, paper-colored bite
			draw_circle(c, s * 0.34, col)
			draw_circle(c + Vector2(s * 0.14, -s * 0.08), s * 0.28, UIH.PAPER_LT)
		"UTILITY":
			# little cloud + star sparkle
			draw_circle(c + Vector2(-s * 0.14, s * 0.06), s * 0.16, col)
			draw_circle(c + Vector2(s * 0.02, -s * 0.02), s * 0.20, col)
			draw_circle(c + Vector2(s * 0.18, s * 0.08), s * 0.14, col)
			var sp := c + Vector2(s * 0.30, -s * 0.30)
			draw_line(sp + Vector2(-5, 0), sp + Vector2(5, 0), col, 2.0, true)
			draw_line(sp + Vector2(0, -5), sp + Vector2(0, 5), col, 2.0, true)
			draw_circle(sp, 1.6, col.lightened(0.3))
