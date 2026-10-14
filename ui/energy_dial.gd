class_name EnergyDial
extends Control
## Archival noir energy gauge: a round clock face with a needle.
## The needle sweeps as energy is spent; typewriter numerals around the rim.

var energy := 0
var max_energy := 3


func _init() -> void:
	custom_minimum_size = Vector2(116, 140)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_energy(e: int, m: int) -> void:
	energy = e
	max_energy = maxi(m, 1)
	queue_redraw()


func _draw() -> void:
	var cx := 58.0
	var cy := 58.0
	var r := 52.0
	var ink := UIH.INK
	var paper := UIH.PAPER_LT
	var stamp := UIH.STAMP
	# outer ring + face
	draw_circle(Vector2(cx, cy), r + 4, ink)
	draw_circle(Vector2(cx, cy), r, paper)
	draw_arc(Vector2(cx, cy), r - 6, 0, TAU, 48, ink, 1.5)
	# tick marks: one per energy pip
	var font := UIH.font_reg()
	for i in range(max_energy):
		var a := -PI * 0.75 + (float(i) / float(maxi(max_energy - 1, 1))) * PI * 1.5
		var p1 := Vector2(cx, cy) + Vector2(cos(a), sin(a)) * (r - 14)
		var p2 := Vector2(cx, cy) + Vector2(cos(a), sin(a)) * (r - 7)
		draw_line(p1, p2, ink, 2.0)
		var num := str(i + 1)
		var np := Vector2(cx, cy) + Vector2(cos(a), sin(a)) * (r - 24)
		draw_string(font, np + Vector2(-5, 5), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
	# needle: points at current energy (0 energy -> far left, like a dead gauge)
	var frac := float(energy) / float(max_energy)
	var na := -PI * 0.75 + frac * PI * 1.5
	var tip := Vector2(cx, cy) + Vector2(cos(na), sin(na)) * (r - 16)
	draw_line(Vector2(cx, cy), tip, stamp, 3.0)
	draw_line(Vector2(cx, cy), tip, stamp.lightened(0.25), 1.0)
	draw_circle(Vector2(cx, cy), 5.0, ink)
	draw_circle(Vector2(cx, cy), 2.5, stamp)
	# caption
	var bf := UIH.font_bold()
	draw_string(bf, Vector2(cx - 34, 128), "ENERGY", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
