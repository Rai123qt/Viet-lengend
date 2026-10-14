class_name HpStrip
extends Control
## Floating HP bar above a sprite's head — NO background panel.
## Red bar + "80 / 80" text. Ghost bar drains after damage.
## bar_w is instance-settable: enemy strips shrink when 2-3 enemies share
## the right side (160/130px) so bars never touch each other.

var bar_w := 200.0
const BAR_H := 18.0

var _maxv := 1
var _cur := 1
var _armor := 0
## Displayed HP (tweens smoothly toward _cur).
var _display_cur := 1.0
var _display_tw: Tween = null
## Armor shield side: -1 = left of bar (enemies), +1 = right of bar (player).
var armor_side := -1.0
## Ghost fraction: drains toward _frac() after damage (white trail).
var _ghost_frac := 1.0
var _ghost_tw: Tween = null


var _preview := 0
var _blink := 0.0

## v3.3: AI-painted bamboo tube shell (transparent PNG). Cached per class.
static var _tube_tex: Texture2D = null


static func tube_tex() -> Texture2D:
	if _tube_tex == null:
		if ResourceLoader.exists("res://assets/art/vl3/hp-bamboo-tube.png"):
			_tube_tex = load("res://assets/art/vl3/hp-bamboo-tube.png")
	return _tube_tex


## Map a horizontal texture-fraction inside the tube's straight middle section
## (caps are drawn unstretched) to a drawn x within trect.
static func _tube_fx_to_x(trect: Rect2, capw: float, fx: float) -> float:
	var cf := 0.16
	return trect.position.x + capw + (fx - cf) / (1.0 - 2.0 * cf) * (trect.size.x - 2.0 * capw)


func _init() -> void:
	custom_minimum_size = Vector2(bar_w, 40)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(_name_text: String = "") -> void:
	queue_redraw()


## Incoming HP loss preview (after armor). 0 = no preview.
func set_preview(will_lose: int) -> void:
	_preview = maxi(will_lose, 0)
	queue_redraw()


func _process(delta: float) -> void:
	if _preview > 0:
		_blink += delta
		queue_redraw()
	# Redraw while the HP bar is animating toward its target.
	if absf(_display_cur - float(_cur)) > 0.05:
		queue_redraw()


func set_hp(cur: int, maxv: int, armor_v: int = 0) -> void:
	var old_max := maxi(_maxv, 1)
	var old_frac := clampf(float(_cur) / float(old_max), 0.0, 1.0)
	_maxv = maxi(maxv, 1)
	_cur = cur
	_armor = maxi(armor_v, 0)
	# Smooth tween for main bar
	if _display_tw and _display_tw.is_valid():
		_display_tw.kill()
	if is_inside_tree():
		_display_tw = create_tween()
		_display_tw.tween_property(self, '_display_cur', float(_cur), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_display_cur = float(_cur)
	var f := _frac()
	if f < old_frac - 0.001:
		# damaged: ghost drains down after a beat
		_ghost_frac = maxf(_ghost_frac, old_frac)
		if _ghost_tw and _ghost_tw.is_valid():
			_ghost_tw.kill()
		if is_inside_tree():
			_ghost_tw = create_tween()
			_ghost_tw.tween_interval(0.4)
			_ghost_tw.tween_property(self, "_ghost_frac", f, 0.7)
			_ghost_tw.tween_callback(queue_redraw)
		else:
			_ghost_frac = f
	elif f > _ghost_frac:
		# healed: snap ghost up, no trail
		_ghost_frac = f
	queue_redraw()


func _frac() -> float:
	return clampf(float(_cur) / float(maxi(_maxv, 1)), 0.0, 1.0)


## Animated fraction used for the visible red fill (smooth tween).
func _display_frac() -> float:
	return clampf(float(_display_cur) / float(maxi(_maxv, 1)), 0.0, 1.0)


func _draw() -> void:
	# Bamboo HP tube floating over the scene (no background panel).
	var bx := 0.0
	var bw := bar_w
	var yc := 10.0
	var tube_h := 32.0
	var f := _frac()
	var df := _display_frac()
	var ink := UIH.INK
	var bamboo := UIH.BAMBOO
	var bamboo_dk := UIH.BAMBOO_DK
	var red := Color("9e1a10")
	# v3.3: AI-painted bamboo casing, drawn in 3 parts (caps unstretched so
	# the node rings don't squash; middle stretched). Fill goes inside the
	# measured hollow interior: texture x [0.165, 0.84], y [0.36, 0.66].
	var tex := tube_tex()
	var inner: Rect2
	if tex != null:
		var trect := Rect2(bx - 4, yc - 17.0, bw + 8, 34.0)
		var tw := float(tex.get_width())
		var th := float(tex.get_height())
		var cf := 0.16
		var capw := 30.0
		draw_texture_rect_region(tex, Rect2(trect.position, Vector2(capw, 34.0)),
			Rect2(0, 0, tw * cf, th))
		draw_texture_rect_region(tex,
			Rect2(trect.position + Vector2(capw, 0), Vector2(trect.size.x - 2.0 * capw, 34.0)),
			Rect2(tw * cf, 0, tw * (1.0 - 2.0 * cf), th))
		draw_texture_rect_region(tex,
			Rect2(trect.position + Vector2(trect.size.x - capw, 0), Vector2(capw, 34.0)),
			Rect2(tw * (1.0 - cf), 0, tw * cf, th))
		var ix0 := _tube_fx_to_x(trect, capw, 0.165)
		var ix1 := _tube_fx_to_x(trect, capw, 0.84)
		inner = Rect2(ix0, trect.position.y + 34.0 * 0.36, ix1 - ix0, 34.0 * 0.30)
	else:
		# fallback: code-drawn casing
		var casing := Rect2(bx - 4, yc - tube_h * 0.5, bw + 8, tube_h)
		draw_rect(casing, bamboo)
		draw_rect(casing, ink, false, 2.0)
		inner = Rect2(bx, yc - tube_h * 0.5 + 4, bw, tube_h - 8)
		draw_rect(inner, Color(0.16, 0.10, 0.05, 0.92))
	# ghost trail (pale, drains after damage)
	if _ghost_frac > f + 0.005:
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * _ghost_frac, inner.size.y)), Color(1, 1, 1, 0.30))
	# red fill (animated: follows the smooth tween)
	if df > 0.0:
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * df, inner.size.y)), red)
		draw_rect(Rect2(inner.position + Vector2(0, 1), Vector2(inner.size.x * df, 3.0)), Color(1, 1, 1, 0.22))
	# incoming-damage preview: diagonal stripes + "-N" label over the HP about to be lost
	if _preview > 0 and _maxv > 0:
		var lose_f := clampf(float(_preview) / float(_maxv), 0.0, f)
		var pr := Rect2(inner.position + Vector2(inner.size.x * (f - lose_f), 0), Vector2(inner.size.x * lose_f, inner.size.y))
		var pulse := 0.5 + 0.5 * sin(_blink * 7.0)
		var pc := Color(1.0, 0.38, 0.32, 0.35 + 0.35 * pulse)
		draw_rect(pr, pc)
		# diagonal hazard stripes
		var sc := Color(1.0, 0.85, 0.8, 0.5 + 0.3 * pulse)
		var x := pr.position.x - pr.size.y
		while x < pr.position.x + pr.size.x:
			var p1 := Vector2(maxf(x, pr.position.x), pr.position.y + pr.size.y)
			var p2 := Vector2(minf(x + pr.size.y, pr.position.x + pr.size.x), pr.position.y)
			# clip the stripe segment to the preview rect
			if p2.x > pr.position.x and p1.x < pr.position.x + pr.size.x:
				draw_line(p1, p2, sc, 2.0)
			x += 7.0
		# "-N" label centered on the preview segment
		var nfont := UIH.font_bold()
		var ntxt := "-%d" % _preview
		var nsz := nfont.get_string_size(ntxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		var nx := pr.position.x + (pr.size.x - nsz.x) * 0.5
		if pr.size.x > nsz.x + 6.0:
			draw_string_outline(nfont, Vector2(nx, yc + 5), ntxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.8))
			draw_string(nfont, Vector2(nx, yc + 5), ntxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.92, 0.88))
	# armor shield: flush against the tube, armor number drawn INSIDE.
	# Enemies: left side (armor_side=-1). Player: right side (armor_side=+1).
	if _armor > 0:
		var sh := tube_h * 0.5
		var shc := Vector2(bx - sh * 0.9 - 4, yc) if armor_side < 0.0 else Vector2(bx + bw + sh * 0.9 + 4, yc)
		var pts := PackedVector2Array([
			shc + Vector2(-sh * 0.9, -sh), shc + Vector2(sh * 0.9, -sh),
			shc + Vector2(sh * 0.9, sh * 0.2), shc + Vector2(0, sh),
			shc + Vector2(-sh * 0.9, sh * 0.2),
		])
		draw_colored_polygon(pts, Color("5a8ab5"))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[0]]), Color("dcebf5"), 1.5)
		var afont := UIH.font_bold()
		var atxt := str(_armor)
		var asz := afont.get_string_size(atxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		var ap := shc + Vector2(-asz.x * 0.5, 4.0)
		draw_string_outline(afont, ap, atxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color(0, 0, 0, 0.85))
		draw_string(afont, ap, atxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1))
	# HP numbers carved on the tube, centered — v3.9.1: bigger, white with
	# black outline for readability on the busy bg.
	var font := UIH.font_bold()
	var txt := "%d / %d" % [_cur, _maxv]
	var tsz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	var tp := Vector2(bx + (bw - tsz.x) * 0.5, yc + 6.0)
	draw_string_outline(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, 0.9))
	draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.96, 0.9))
