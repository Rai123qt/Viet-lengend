extends SceneTree
## v3.1 layout test: hard stage/tray split + symmetry + card text geometry.
## - No hand card may intersect any HP strip / name / chip row (both sides).
## - Player and enemy stacks mirror: same strip width, same element heights,
##   enemy group centered on the mirror of HERO_CX (x=990).
## - Every card's description sits clear of the side bands, centered, and fits.
## Run: godot --headless --path . --script res://tests/layout_test.gd

const TRAY_TOP := 500.0  # v3.7: mirrors battle_screen.gd (was 452)

var step := 0
var main = null
var btl = null
var fails := 0
var phase := 0


func _initialize() -> void:
	var game_node: Node = root.get_node("Game")
	game_node.call("new_run", "thach_sanh")
	main = load("res://main.gd").new()
	root.add_child(main)


func _fail(msg: String) -> void:
	fails += 1
	printerr("LAYOUT FAIL: ", msg)


func _ok(msg: String) -> void:
	print("LAYOUT OK: ", msg)


func _gr(c: Control) -> Rect2:
	return c.get_global_rect()


func _check_battle(tag: String, expect_w: float) -> void:
	btl._refresh()
	# --- collect stage rects ---
	var p_strip := _gr(btl._player_strip)
	var p_name := _gr(btl._p_name_l)
	var p_chips := _gr(btl._p_chips)
	var stage_rects: Array = [p_strip, p_name, p_chips]
	if btl._enemy_strips.is_empty():
		_fail(tag + ": no enemy strips")
		return
	for i in range(btl._enemy_strips.size()):
		stage_rects.append(_gr(btl._enemy_strips[i]))
		stage_rects.append(_gr(btl._enemy_names[i]))
		stage_rects.append(_gr(btl._enemy_chips[i]))
	# every stage element must end above TRAY_TOP
	for r in stage_rects:
		if r.end.y > TRAY_TOP + 0.5:
			_fail("%s: stage element crosses TRAY_TOP: %s" % [tag, r])
	# --- symmetry: same heights as the player stack; same strip width for
	# single enemy (multi-enemy strips are narrower by design so they fit) ---
	var single: bool = btl._enemy_strips.size() == 1
	for i in range(btl._enemy_strips.size()):
		var e_strip := _gr(btl._enemy_strips[i])
		var e_name := _gr(btl._enemy_names[i])
		var e_chips := _gr(btl._enemy_chips[i])
		if single and absf(p_strip.size.x - e_strip.size.x) > 0.5:
			_fail("%s: strip widths differ p=%s e=%s" % [tag, p_strip.size.x, e_strip.size.x])
		if absf(p_strip.position.y - e_strip.position.y) > 0.5:
			_fail("%s: strip heights differ" % tag)
		if absf(p_name.position.y - e_name.position.y) > 0.5:
			_fail("%s: name heights differ" % tag)
		if absf(p_chips.position.y - e_chips.position.y) > 0.5:
			_fail("%s: chip heights differ" % tag)
		if absf(e_strip.size.x - expect_w) > 0.5:
			_fail("%s: enemy strip w=%s, expected %s" % [tag, e_strip.size.x, expect_w])
	# enemy group mirrored around x=990 (mirror of HERO_CX=290)
	var cx_sum := 0.0
	for s in btl._enemy_strips:
		cx_sum += _gr(s).get_center().x
	var group_cx := cx_sum / float(btl._enemy_strips.size())
	if absf(group_cx - 990.0) > 1.0:
		_fail("%s: enemy group cx=%s, expected 990 (mirror)" % [tag, group_cx])
	if absf(p_strip.get_center().x - 290.0) > 1.0:
		_fail("%s: hero strip cx=%s, expected 290" % [tag, p_strip.get_center().x])
	# --- no card touches any stage element ---
	for cw in btl._hand_box.get_children():
		var cr := _gr(cw)
		for r in stage_rects:
			if cr.intersects(r):
				_fail("%s: card %s intersects stage rect %s" % [tag, cr, r])
	# --- card text geometry (v3.5 full-face art: painted border ≈14px each
	# side; text must sit on the blank ribbon, clear of the border) ---
	for cw in btl._hand_box.get_children():
		var tl: RichTextLabel = cw.get("_text_l")
		var nl: RichTextLabel = cw.get("_name_l")
		# text box must clear the painted side borders
		if tl.position.x < 16.0:
			_fail("%s: card text too close to left border: x=%s" % [tag, tl.position.x])
		if tl.position.x + tl.size.x > 124.0:
			_fail("%s: card text too close to right border" % tag)
		if tl.position.y + tl.size.y > 200.0:
			_fail("%s: card text too low (hits bottom border)" % tag)
		var nfs: int = nl.get_theme_font_size("normal_font_size")
		var f: Font = nl.get_theme_font("normal_font")
		var nw := f.get_string_size(CardDB.card_name(cw.card), HORIZONTAL_ALIGNMENT_LEFT, -1.0, nfs).x
		if nw > 100.0:
			_fail("%s: card name overflows: '%s' w=%s" % [tag, CardDB.card_name(cw.card), nw])
		# name must not overlap the description text below it
		if nl.position.y + nl.size.y > tl.position.y + 1.0:
			_fail("%s: card name overlaps description text" % tag)
	_ok("%s: %d cards, no stage overlap, symmetric" % [tag, btl._hand_box.get_child_count()])


func _check_v32(tag: String) -> void:
	# v3.2: unified command panel + chord book placement.
	if btl._cmd_panel == null:
		_fail(tag + ": no command panel")
		return
	var pr := _gr(btl._cmd_panel)
	# v3.3: compact 2-row panel sits bottom-left, clear of the hand's left margin (x>=416)
	if pr.position.x < 8.0 or pr.end.x > 416.0:
		_fail("%s: command panel out of left zone: %s" % [tag, pr])
	if pr.position.y < 520.0 or pr.end.y > 712.0:
		_fail("%s: command panel out of bottom band: %s" % [tag, pr])
	# every command control must sit inside the panel
	# v3.8: compose button removed (chords auto-detect)
	var inside: Array = [btl._note_energy, btl._equip_btn]
	for b in btl._item_btns:
		inside.append(b)
	for c in inside:
		var cr := _gr(c)
		if not pr.encloses(cr):
			_fail("%s: control %s not inside command panel %s" % [tag, cr, pr])
	# CHORD BOOK: bottom-right, right of x=1024; v3.7 compact right column —
	# below the fighter chip band (ends y=498), above END TURN (starts y=572).
	var cb := _gr(btl._chordbook_btn)
	if cb.position.x < 1024.0:
		_fail("%s: chord book too far left: %s" % [tag, cb])
	if cb.position.y < 500.0:
		_fail("%s: chord book too high (strip band): %s" % [tag, cb])
	if cb.end.y > 572.0:
		_fail("%s: chord book too low (END TURN zone): %s" % [tag, cb])
	# no card may touch the panel, the chord book, or the chord string
	var keep: Array = [pr, cb, _gr(btl._chord_str)]
	for cw in btl._hand_box.get_children():
		var cr := _gr(cw)
		for r in keep:
			if cr.intersects(r):
				_fail("%s: card %s intersects %s" % [tag, cr, r])
	_ok("%s: v3.2 panel + chord book clear" % tag)


func _check_all_card_texts() -> void:
	# v3.6: every card's name + text must fit the v2 text-zone windows
	# (from CardWidget.face_win_rect), name >= 8pt, text >= 6pt.
	var f: Font = UIH.font_reg()
	var nf: Font = UIH.font_title()
	var name_w := 0.80 * 140.0 - 4.0
	var text_w := 0.80 * 140.0 - 8.0
	var text_h := 0.165 * 204.0 - 2.0
	var bad := 0
	for cid in CardDB.CARDS.keys():
		var d: Dictionary = CardDB.get_def(str(cid))
		var plain := str(d.get("text", ""))
		if plain != "":
			var sz := f.get_multiline_string_size(plain, HORIZONTAL_ALIGNMENT_CENTER, text_w, 6)
			if sz.y > text_h or sz.x > text_w:
				_fail("card '%s' text does not fit v2 text zone even at 6pt" % cid)
				bad += 1
		var nm := str(d.get("name", ""))
		if nf.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8).x > name_w:
			_fail("card '%s' name does not fit v2 name zone even at 8pt" % cid)
			bad += 1
	if bad == 0:
		_ok("all %d card texts + names fit v2 text-zone windows" % CardDB.CARDS.size())


func _process(_delta: float) -> bool:
	step += 1
	match phase:
		0:
			if step == 4:
				main.show_battle("wild_boar")
			elif step == 10:
				btl = main.current
				_check_battle("1-enemy", 220.0)
				_check_v32("1-enemy")
				phase = 1
				step = 0
		1:
			if step == 4:
				main.show_battle([{"id": "wild_boar"}, {"id": "forest_viper"}])
			elif step == 10:
				btl = main.current
				_check_battle("2-enemy", 160.0)
				_check_v32("2-enemy")
				phase = 2
				step = 0
		2:
			if step == 4:
				main.show_battle([{"id": "wild_boar"}, {"id": "forest_viper"}, {"id": "timber_bandit"}])
			elif step == 10:
				btl = main.current
				_check_battle("3-enemy", 130.0)
				_check_v32("3-enemy")
				_check_all_card_texts()
				print("LAYOUT DONE: fails=", fails)
				quit(1 if fails > 0 else 0)
				return true
	return false
