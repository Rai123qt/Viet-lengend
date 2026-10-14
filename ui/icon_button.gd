class_name IconButton
extends Button
## Round icon button with a corner badge and a long-press tooltip popup.
## Short tap emits `tapped`; press-and-hold (>= 0.55s) shows name + description.

signal tapped

const LP_TIME := 0.55

var tip_title := ""
var tip_desc := ""
var _lp_fired := false
var _lp_pressed := false
var _lp_gen := 0
var _tip_pop: PopupPanel = null


func _init(tex: Texture2D = null, size: float = 88.0) -> void:
	custom_minimum_size = Vector2(size, size)
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if tex:
		icon = tex
	var rad := int(size * 0.5)
	# paper seal: cream disc, ink ring
	var n := StyleBoxFlat.new()
	n.bg_color = UIH.PAPER
	n.border_color = UIH.INK
	n.set_border_width_all(2)
	n.set_corner_radius_all(rad)
	n.shadow_color = Color(0, 0, 0, 0.5)
	n.shadow_size = 8
	n.shadow_offset = Vector2(0, 3)
	add_theme_stylebox_override("normal", n)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = UIH.PAPER_DK
	h.border_color = UIH.STAMP
	add_theme_stylebox_override("hover", h)
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = UIH.PAPER_DK
	add_theme_stylebox_override("pressed", p)
	var d := n.duplicate() as StyleBoxFlat
	d.bg_color = Color("cfc2a2")
	d.border_color = Color("8a8069")
	add_theme_stylebox_override("disabled", d)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button_down.connect(_on_down)
	button_up.connect(_on_up)


func set_badge_text(t: String) -> void:
	UIH.set_badge(self, t)


func _on_down() -> void:
	if not is_inside_tree():
		return
	_lp_pressed = true
	_lp_fired = false
	_lp_gen += 1
	var g := _lp_gen
	await get_tree().create_timer(LP_TIME).timeout
	if _lp_gen == g and _lp_pressed and not _lp_fired:
		_lp_fired = true
		_show_tip()


func _on_up() -> void:
	_lp_pressed = false
	if _lp_fired:
		_lp_fired = false
		_hide_tip()
	else:
		tapped.emit()


func _show_tip() -> void:
	_hide_tip()
	_tip_pop = PopupPanel.new()
	var psb := UIH.paper_style(UIH.INK, 2, 3)
	_tip_pop.add_theme_stylebox_override("panel", psb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_tip_pop.add_child(vb)
	var t := UIH.header(tip_title, UIH.AMBER, 15)
	vb.add_child(t)
	var d := UIH.label(tip_desc, 15)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(300, 0)
	vb.add_child(d)
	_tip_pop.size = Vector2(340, 120)
	get_tree().root.add_child(_tip_pop)
	var gp := get_global_rect()
	var vsz := get_viewport_rect().size
	var px: float = clampf(gp.position.x + gp.size.x + 12, 8, vsz.x - 350)
	var py: float = clampf(gp.position.y - 20, 8, vsz.y - 160)
	_tip_pop.position = Vector2(px, py)
	_tip_pop.popup()


func _hide_tip() -> void:
	if _tip_pop and is_instance_valid(_tip_pop):
		_tip_pop.hide()
		_tip_pop.queue_free()
	_tip_pop = null


func _exit_tree() -> void:
	_hide_tip()
