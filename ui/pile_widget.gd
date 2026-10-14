class_name PileWidget
extends Control
## Draw/discard pile indicator: little stack of paper cards + big count.
## Prominent, bottom-left of the battle screen.

var _caption := "DRAW"
var _count := 0


func _init(p_caption: String = "DRAW") -> void:
	_caption = p_caption
	custom_minimum_size = Vector2(112, 52)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_count(n: int) -> void:
	_count = n
	queue_redraw()


func _draw() -> void:
	# dark plaque so it reads over the scene
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.78)
	bg.border_color = Color(0.85, 0.80, 0.68, 0.35)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(6)
	draw_style_box(bg, Rect2(0, 0, 112, 52))
	# stack of 3 paper cards, offset
	var paper := UIH.PAPER_DK
	var ink := UIH.INK_SOFT
	for i in range(2, -1, -1):
		var r := Rect2(10 + i * 4, 8 + (2 - i) * 3, 26, 36)
		draw_rect(r, paper)
		draw_rect(r, ink, false, 1.5)
	# big count
	draw_string(UIH.font_bold(), Vector2(52, 32), str(_count),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.97, 0.90))
	# caption
	draw_string(UIH.font_bold(), Vector2(52, 46), _caption,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.92, 0.87, 0.74))
