class_name StatChip
extends Control
## Small floating status chip: icon + count. Dark translucent, no paper.
## kinds: "weak" (down arrow), "vulnerable" (cracked target),
## "strength" (sword), "armor" (shield). Hidden when value is 0.
## Emits tapped(kind) when the user taps the chip.

signal tapped(kind: String)

var _value := 0
var _kind := "drowsy"

const MOON := Color("8a7ab0")
const SHIELD := Color("7fa8c9")


func setup(kind: String) -> void:
	_kind = kind
	# width auto-fits content in set_value(); start narrow
	custom_minimum_size = Vector2(40, 26)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(_kind)
		accept_event()


func set_value(v: int) -> void:
	_value = v
	visible = v > 0
	# Hug the content: icon (left 26px) + number width + padding. No empty box.
	var tw := UIH.font_bold().get_string_size(str(v), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	custom_minimum_size = Vector2(26.0 + tw + 10.0, 26)
	queue_redraw()


func _draw() -> void:
	if _value <= 0:
		return
	var w := size.x
	var h := size.y
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.border_color = Color(1, 1, 1, 0.18)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(5)
	draw_style_box(bg, Rect2(0, 0, w, h))
	var ic := Vector2(14, h * 0.5)
	if _kind == "armor":
		# little shield outline
		var s := 9.0
		var pts := PackedVector2Array([
			ic + Vector2(0, -s), ic + Vector2(s * 0.8, -s * 0.55),
			ic + Vector2(s * 0.8, s * 0.25), ic + Vector2(0, s),
			ic + Vector2(-s * 0.8, s * 0.25), ic + Vector2(-s * 0.8, -s * 0.55),
		])
		draw_polyline(pts, SHIELD, 2.2, true)
	elif _kind == "armor_gain":
		# shield with a plus: armor gains boosted
		var s := 9.0
		var pts := PackedVector2Array([
			ic + Vector2(0, -s), ic + Vector2(s * 0.8, -s * 0.55),
			ic + Vector2(s * 0.8, s * 0.25), ic + Vector2(0, s),
			ic + Vector2(-s * 0.8, s * 0.25), ic + Vector2(-s * 0.8, -s * 0.55),
		])
		draw_polyline(pts, Color(0.55, 0.85, 0.6), 2.2, true)
		draw_line(ic + Vector2(-3.5, 0), ic + Vector2(3.5, 0), Color(0.55, 0.85, 0.6), 2.0, true)
		draw_line(ic + Vector2(0, -3.5), ic + Vector2(0, 3.5), Color(0.55, 0.85, 0.6), 2.0, true)
	elif _kind == "vulnerable" or _kind == "exposed":
		# cracked target: concentric circles with a crack
		draw_arc(ic, 7.5, 0, TAU, 24, Color(1.0, 0.55, 0.35), 2.2, true)
		draw_arc(ic, 3.5, 0, TAU, 16, Color(1.0, 0.55, 0.35), 2.0, true)
		draw_line(ic + Vector2(-6, -6), ic + Vector2(6, 6), Color(1.0, 0.55, 0.35), 1.6, true)
	elif _kind == "weak":
		# down arrow: weakened
		draw_line(ic + Vector2(0, -7), ic + Vector2(0, 5), Color(0.65, 0.65, 0.75), 2.6, true)
		draw_line(ic + Vector2(0, 5), ic + Vector2(-4.5, 0.5), Color(0.65, 0.65, 0.75), 2.6, true)
		draw_line(ic + Vector2(0, 5), ic + Vector2(4.5, 0.5), Color(0.65, 0.65, 0.75), 2.6, true)
	elif _kind == "strength":
		# flexed arm / sword: simple upward sword
		var s := 8.0
		draw_line(ic + Vector2(0, s), ic + Vector2(0, -s), Color(1.0, 0.45, 0.35), 3.0, true)
		draw_line(ic + Vector2(-5, -s + 3), ic + Vector2(5, -s + 3), Color(1.0, 0.45, 0.35), 2.5, true)
		draw_line(ic + Vector2(-4, s - 2), ic + Vector2(4, s - 2), Color(0.9, 0.85, 0.7), 2.0, true)
	else:
		# crescent moon: filled disc with a dark bite taken out
		draw_circle(ic, 7.5, MOON)
		draw_circle(ic + Vector2(3.2, -2.2), 6.0, Color(0.03, 0.03, 0.05, 0.9))
	draw_string(UIH.font_bold(), Vector2(26, h * 0.5 + 5), str(_value),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.96, 0.93, 0.86))
