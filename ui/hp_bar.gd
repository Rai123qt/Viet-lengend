class_name HpBar
extends Control
## Dong Ho bamboo HP bar: bamboo casing, red fill, ghost trail,
## carved numbers, seal-dot icon, armor under-bar.

var _maxv := 1
var _cur := 1
var _ghost := 1.0
var _armor := 0
var _bucket := -1
var _fill_tex: Texture2D = null
var _text_l: Label = null

const BAR_H := 26.0
const WIDGET_H := 46.0
const HEART := Color("d6455a")
const GHOST := Color(1, 1, 1, 0.55)


func setup(w: float) -> void:
	custom_minimum_size = Vector2(w, WIDGET_H)
	_text_l = Label.new()
	_text_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text_l.add_theme_font_size_override("font_size", 15)
	_text_l.add_theme_color_override("font_color", Color("2a1f14"))
	_text_l.add_theme_color_override("font_shadow_color", Color("f4ecd8"))
	_text_l.add_theme_constant_override("shadow_offset_x", 1)
	_text_l.add_theme_constant_override("shadow_offset_y", 1)
	_text_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text_l)
	_layout_text()


func _layout_text() -> void:
	if _text_l == null:
		return
	var w := size.x if size.x > 0 else custom_minimum_size.x
	_text_l.position = Vector2(38, 4)
	_text_l.size = Vector2(maxf(w - 44, 40), BAR_H)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_text()
		queue_redraw()


func set_hp(cur: int, maxv: int, armor_v: int) -> void:
	_maxv = maxi(maxv, 1)
	if cur > _cur:
		_ghost = float(cur)  # heal: snap ghost up, no trail
	_cur = cur
	_armor = maxi(armor_v, 0)
	_text_l.text = "%d / %d" % [_cur, _maxv]
	_regen_fill()
	queue_redraw()


func _frac() -> float:
	return clampf(float(_cur) / float(_maxv), 0.0, 1.0)


func _base_color(f: float) -> Color:
	if f > 0.5:
		return Color("e8c34b").lerp(Color("58b368"), (f - 0.5) * 2.0)
	return Color("d64545").lerp(Color("e8c34b"), f * 2.0)


func _regen_fill() -> void:
	var b := int(_frac() * 24.0)
	if b == _bucket and _fill_tex != null:
		return
	_bucket = b
	var base := _base_color(_frac())
	_fill_tex = UIH._rounded_vgrad(96, int(BAR_H), base.lightened(0.22), base.darkened(0.28), 9)


func _process(delta: float) -> void:
	if _ghost > float(_cur):
		_ghost = maxf(float(_cur), _ghost - delta * float(_maxv) * 0.5)
		queue_redraw()


func _draw() -> void:
	var w := size.x if size.x > 0 else custom_minimum_size.x
	var bx := 38.0
	var bw := w - bx - 6.0
	# heart icon
	var hc := Vector2(17, 15)
	draw_circle(hc + Vector2(-5, -2), 7.0, HEART.darkened(0.35))
	draw_circle(hc + Vector2(5, -2), 7.0, HEART.darkened(0.35))
	draw_colored_polygon(PackedVector2Array([hc + Vector2(-11.2, 0.5), hc + Vector2(11.2, 0.5), hc + Vector2(0, 13)]), HEART.darkened(0.35))
	draw_circle(hc + Vector2(-5, -2), 6.0, HEART)
	draw_circle(hc + Vector2(5, -2), 6.0, HEART)
	draw_colored_polygon(PackedVector2Array([hc + Vector2(-10, 0), hc + Vector2(10, 0), hc + Vector2(0, 11.5)]), HEART)
	# bar track
	var track := Rect2(bx, 4, bw, BAR_H)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("8a6a3a")
	bg.set_corner_radius_all(9)
	draw_style_box(bg, track)
	# ghost (damage trail)
	var gf := clampf(_ghost / float(_maxv), 0.0, 1.0)
	if gf > 0.001:
		var gs := StyleBoxFlat.new()
		gs.bg_color = GHOST
		gs.set_corner_radius_all(9)
		draw_style_box(gs, Rect2(bx, 4, bw * gf, BAR_H))
	# fill
	var f := _frac()
	if f > 0.001 and _fill_tex != null:
		var fs := StyleBoxTexture.new()
		fs.texture = _fill_tex
		draw_style_box(fs, Rect2(bx, 4, bw * f, BAR_H))
		# top gloss
		var gl := StyleBoxFlat.new()
		gl.bg_color = Color(1, 1, 1, 0.10)
		gl.set_corner_radius_all(9)
		draw_style_box(gl, Rect2(bx + 2, 6, maxf(bw * f - 4, 1.0), BAR_H * 0.42))
	# border
	var bd := StyleBoxFlat.new()
	bd.draw_center = false
	bd.border_color = Color("2a1f14")
	bd.set_border_width_all(2)
	bd.set_corner_radius_all(9)
	draw_style_box(bd, track)
	# armor under-bar
	if _armor > 0:
		var af := clampf(float(_armor) / float(_maxv), 0.0, 1.0)
		var ar := Rect2(bx, 36, bw, 8)
		var abg := StyleBoxFlat.new()
		abg.bg_color = Color("8a6a3a")
		abg.set_corner_radius_all(4)
		draw_style_box(abg, ar)
		var atx := UIH._rounded_vgrad(64, 8, Color("6fa8dc").lightened(0.2), Color("3b6ea5").darkened(0.2), 4)
		var asb := StyleBoxTexture.new()
		asb.texture = atx
		draw_style_box(asb, Rect2(bx, 36, bw * af, 8))
		# tiny shield + number
		var sp := Vector2(bx + 8, 40)
		draw_colored_polygon(PackedVector2Array([
			sp + Vector2(0, -6), sp + Vector2(5, -3.5), sp + Vector2(5, 2.5),
			sp + Vector2(0, 6.5), sp + Vector2(-5, 2.5), sp + Vector2(-5, -3.5)]), Color("9db8dd"))
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(bx + 17, 44), str(_armor), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("cfe2f5"))
