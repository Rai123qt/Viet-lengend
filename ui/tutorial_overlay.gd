class_name TutorialOverlay
extends Control
## Step-by-step tutorial overlay for the first battle.
## Bulletproof design: no awaits, tap-anywhere advances, single-tap SKIP.
## English instructions, paper-style popups positioned near their targets.

signal step_completed

var _steps: Array = []
var _current: int = 0
var _popup: PanelContainer = null
var _highlight: Panel = null
var _on_action_step: bool = false
var _skip_btn: Button = null
var _done := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# STOP so taps anywhere hit this overlay first (tap-anywhere advances).
	mouse_filter = Control.MOUSE_FILTER_STOP
	_define_steps()


func _hero_intro_text() -> String:
	if Game.hero_id == "hai_ba_trung":
		return "You are HAI BA TRUNG, the warrior queen of Me Linh.\n\nLead your war elephant against the Han invaders.\nI'll guide you step by step.\n\n(Tap anywhere to continue)"
	return "You are THACH SANH, the kind woodcutter of the Green Forest.\n\nDefeat the beasts and demons with your cards and your lute.\nI'll guide you step by step.\n\n(Tap anywhere to continue)"


func _define_steps() -> void:
	var is_hbt := Game.hero_id == "hai_ba_trung"
	var power_step := {
		"title": "CHORDS (YOUR POWER)",
		"text": "Thach Sanh fights with MUSIC.\n\nPlay Attack/Skill cards and your NOTE STRING builds automatically — red notes = Attack, green = Skill.\n\nComplete a chord's note order (see CHORD BOOK) to trigger it — max 1 chord per turn!\nA wrong note snaps the string.\nPower cards are free grace notes.\n\n(Tap anywhere to continue)",
		"target": "chord",
	}
	if is_hbt:
		# v6.8: HBT uses war elephant + bow, not chords
		power_step = {
			"title": "WAR ELEPHANT",
			"text": "Your WAR ELEPHANT fights beside you!\n\n30 HP, tramples ALL enemies for 12 damage every 3 turns.\n25% of enemy attacks hit the elephant instead of you.\n\nUse Elephant cards to command it: charge, guard, heal.\n\n(Tap anywhere to continue)",
			"target": "elephant",
		}
	_steps = [
		{
			"title": "VIET LEGENDS",
			"text": _hero_intro_text(),
			"target": "",
		},
		{
			"title": "ENERGY",
			"text": "This is your Energy.\n\nEach card costs Energy (number in the gold circle).\nYou get 3 Energy per turn.\n\n(Tap anywhere to continue)",
			"target": "energy",
		},
		{
			"title": "YOUR HAND",
			"text": "These are your cards.\n\nYou draw 5 each turn.\nPlayed cards go to discard.\n\n(Tap anywhere to continue)",
			"target": "hand",
		},
		{
			"title": "CARD TYPES",
			"text": "Card borders show the card TYPE:\n\nRED = ATTACK (damage)\nGREEN = SKILL (block, draw, tricks)\nGOLD = POWER (stays in play)\n\n(Tap anywhere to continue)",
			"target": "hand",
		},
		power_step,
		{
			"title": "TRY IT!",
			"text": "To attack:\n1. Tap an ATTACK card (red border)\n2. Tap it again to confirm\n(or drag the card up)\n\nTry playing one now!",
			"target": "hand",
			"action": "play_card",
		},
		{
			"title": "SELECT TARGET",
			"text": "Tap an enemy to select your target.\n\nRed ring = selected.\nWhen one dies, target auto-switches.\n\n(Tap anywhere to continue)",
			"target": "enemy",
		},
		{
			"title": "ENEMY INTENT",
			"text": "Above each enemy: its INTENT — what it will do next.\n\nRead it every turn!\nBig red number = incoming damage.\nLong-press an enemy to inspect.\n\n(Tap anywhere to continue)",
			"target": "enemy",
		},
		{
			"title": "DIVINE ARTIFACT",
			"text": "This is your Divine Artifact.\n\nIt is PASSIVE — always active, no need to tap.\nTap the slot to inspect its effect.\n\n(Tap anywhere to continue)",
			"target": "equipment",
		},
		{
			"title": "END YOUR TURN",
			"text": "When done, press END TURN.\n\nEnemies will act, then it's your turn again.\n\nGood luck, woodcutter!",
			"target": "endturn",
		},
	]


func start() -> void:
	_current = 0
	_done = false
	_build_skip_button()
	_show_step()


func _build_skip_button() -> void:
	_skip_btn = Button.new()
	_skip_btn.text = "SKIP"
	_skip_btn.custom_minimum_size = Vector2(110, 52)
	_skip_btn.add_theme_font_size_override("font_size", 17)
	_skip_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_skip_btn.position = Vector2(-126, 76)  # below pause/deck buttons
	_skip_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_skip_btn.z_index = 10
	add_child(_skip_btn)
	# Single tap skips — no hold needed.
	_skip_btn.pressed.connect(_finish)


func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	var tapped := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			tapped = true
	elif event is InputEventScreenTouch:
		if (event as InputEventScreenTouch).pressed:
			tapped = true
	if tapped:
		# Don't advance on action steps (user must play a card).
		# The SKIP button handles its own tap.
		if not _on_action_step:
			_on_next()
		accept_event()


func _show_step() -> void:
	if _done:
		return
	if _current >= _steps.size():
		_finish()
		return
	var s: Dictionary = _steps[_current]
	_on_action_step = str(s.get("action", "")) != ""
	# Action steps: let taps reach the game (play a card). Other steps:
	# overlay eats taps so tap-anywhere advances.
	mouse_filter = Control.MOUSE_FILTER_IGNORE if _on_action_step else Control.MOUSE_FILTER_STOP
	_show_popup(s)


func _show_popup(s: Dictionary) -> void:
	_clear_popup()
	_clear_highlight()

	var target: String = str(s.get("target", ""))
	var target_rect := Rect2()
	if target != "":
		var p := get_parent()
		if p and p.has_method("get_tutorial_target_rect"):
			target_rect = p.get_tutorial_target_rect(target)

	# Highlight the target with a red ring (steady, no infinite tween).
	if target_rect.size.x > 0:
		_highlight = Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = Color(0.9, 0.25, 0.2, 0.95)
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(10)
		sb.shadow_color = Color(0.9, 0.25, 0.2, 0.4)
		sb.shadow_size = 12
		_highlight.add_theme_stylebox_override("panel", sb)
		_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_highlight.position = target_rect.position - Vector2(10, 10)
		_highlight.size = target_rect.size + Vector2(20, 20)
		add_child(_highlight)

	# Paper-style popup (light background, dark text — readable!)
	_popup = PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.93, 0.88, 0.76, 0.98)
	psb.border_color = Color(0.25, 0.18, 0.12)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(6)
	psb.content_margin_left = 20
	psb.content_margin_right = 20
	psb.content_margin_top = 16
	psb.content_margin_bottom = 16
	psb.shadow_color = Color(0, 0, 0, 0.5)
	psb.shadow_size = 10
	_popup.add_theme_stylebox_override("panel", psb)
	# Popup ignores taps so they fall through to the overlay
	# (tap-anywhere advances). Only real Buttons stop input.
	_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.add_child(vb)

	var title := Label.new()
	title.text = str(s.get("title", ""))
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.65, 0.12, 0.10))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(title)

	var body := Label.new()
	body.text = str(s.get("text", ""))
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", Color(0.20, 0.15, 0.10))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(440, 0)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(body)

	var counter := Label.new()
	counter.text = "Step %d / %d — tap anywhere" % [_current + 1, _steps.size()]
	counter.add_theme_font_size_override("font_size", 12)
	counter.add_theme_color_override("font_color", Color(0.45, 0.40, 0.35))
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(counter)

	if _on_action_step:
		var hint := Label.new()
		hint.text = "Follow the instruction above to continue"
		hint.add_theme_font_size_override("font_size", 13)
		hint.add_theme_color_override("font_color", Color(0.65, 0.12, 0.10))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(hint)

	add_child(_popup)

	# Position popup: near target, or right side if no target (don't cover hero). Fixed estimate, no awaits.
	var ps := Vector2(480, 340)
	var vs := get_viewport_rect().size
	if vs.x <= 0:
		vs = Vector2(1280, 720)
	# v6.9.2: centered (was right side, Rai: "lệch 1 bên")
	var pos := Vector2((vs.x - ps.x) / 2, (vs.y - ps.y) / 2)

	if target_rect.size.x > 0:
		var target_center := target_rect.get_center()
		if target_center.y > vs.y * 0.6:
			pos = Vector2((vs.x - ps.x) / 2, vs.y * 0.12)
		elif target_center.y < vs.y * 0.35:
			pos = Vector2((vs.x - ps.x) / 2, vs.y * 0.48)

	_popup.position = pos
	_popup.custom_minimum_size = ps
	if _skip_btn and is_instance_valid(_skip_btn):
		_skip_btn.z_index = 10


func _on_next() -> void:
	if _done:
		return
	_current += 1
	_show_step()
	step_completed.emit()


func notify_action_done() -> void:
	if _done:
		return
	if _on_action_step:
		_current += 1
		_show_step()
		step_completed.emit()


func _clear_popup() -> void:
	if _popup and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null


func _clear_highlight() -> void:
	if _highlight and is_instance_valid(_highlight):
		_highlight.queue_free()
	_highlight = null


func _finish() -> void:
	if _done:
		return
	_done = true
	_clear_popup()
	_clear_highlight()
	if _skip_btn and is_instance_valid(_skip_btn):
		_skip_btn.queue_free()
	_skip_btn = null
	set_process(false)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	step_completed.emit()
