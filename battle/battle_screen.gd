class_name BattleScreen
extends Control
## Battle UI: observes BattleState, handles input, plays tween animations.
## Dong Ho folk-stage layout v2 (1280x720):
##  - top-center: turn slip + legend banner
##  - stage: Thach Sanh (left) vs enemies (right), feet on one line (FEET_Y),
##    bamboo HP strips under the feet, big intent badges above enemy heads,
##    buff/debuff chips in one row under each fighter's name
##  - bottom-left: lute COMPOSE icon + chord string, music-note energy,
##    equipment seal + item slots
##  - bottom-center: hand of folk-art cards (fan layout)
##  - bottom-right: END TURN red seal stamp above the DISCARD pile
##  - NO battle log, NO enemy subject file


## FEET_Y: hero and enemy feet share this height (same ground line).
## v3.7: lowered to 410 so feet sit on the painted forest floor (was 350,
## which left fighters floating in the foliage). The whole fighter stack
## (HP strip + name + chips, ends at FEET_Y+88) still fits in the STAGE zone
## (y < TRAY_TOP) with a clear gap above the hand tray.
const FEET_Y := 410.0
## TRAY_TOP: hard split — nothing in the stage zone may cross this line.
## Hand cards start at TRAY_TOP + 2. v3.7: moved down to 500 to make room
## for the lowered fighters; cards (204 tall) still clear the bottom edge.
const TRAY_TOP := 500.0
## Hero sprite center x (sprite at x=140, size 300).
const HERO_CX := 290.0


## Energy as a row of small hand-drawn folk drums (trong com):
## barrel body with zigzag rope lacing, lit drums are full-color,
## spent drums are dim. No unicode glyphs (font-safe).
class NoteEnergy extends Control:
	var energy := 3
	var max_energy := 3
	var hero_id := "thach_sanh"  # v6.4: HBT uses war drums

	func _init(p_hero_id: String = "thach_sanh") -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		hero_id = p_hero_id

	func set_values(e: int, m: int) -> void:
		energy = e
		max_energy = m
		queue_redraw()

	func _draw() -> void:
		var n := maxi(3, max_energy)
		for i in range(n):
			var cx := (float(i) + 0.5) * size.x / float(n)
			var cy := size.y * 0.55
			var lit: bool = i < energy
			if hero_id == "hai_ba_trung":
				_drum(Vector2(cx, cy), 18.0, lit)
			else:
				_note(Vector2(cx, cy), 18.0, lit)

	## War drum: fits Hai Ba Trung theme (Rai)
	func _drum(c: Vector2, s: float, lit: bool) -> void:
		var col := Color("c0392b") if lit else Color("6a5f4c")
		var ink := UIH.INK
		# drum body (rounded rect)
		var r := Rect2(c - Vector2(s*0.6, s*0.4), Vector2(s*1.2, s*0.8))
		draw_rect(r, col)
		draw_rect(r, ink, false, 2.0)
		# drum top (ellipse)
		_draw_ellipse(c - Vector2(0, s*0.4), s*0.6, s*0.2, Color("e8dcc0") if lit else Color("8a7f72"), ink)
		# drumsticks
		draw_line(c + Vector2(-s*0.3, -s*0.6), c + Vector2(-s*0.1, -s*0.4), ink, 2.0)
		draw_line(c + Vector2(s*0.3, -s*0.6), c + Vector2(s*0.1, -s*0.4), ink, 2.0)

	## Musical note (quaver): fits Thach Sanh lute theme (Rai)
	func _note(c: Vector2, s: float, lit: bool) -> void:
		var col := Color("d9a92e") if lit else Color("6a5f4c")
		var ink := UIH.INK
		# note head (ellipse)
		var head_c := c + Vector2(-s*0.3, s*0.4)
		_draw_ellipse(head_c, s*0.35, s*0.25, col, ink)
		# stem
		draw_line(head_c + Vector2(s*0.3, 0), head_c + Vector2(s*0.3, -s*1.2), col, 3.0)
		# flag
		var top := head_c + Vector2(s*0.3, -s*1.2)
		draw_line(top, top + Vector2(s*0.5, s*0.3), col, 3.0)

	func _draw_ellipse(c: Vector2, rx: float, ry: float, fill: Color, outline: Color) -> void:
		var pts := PackedVector2Array()
		for i in range(25):
			var a := TAU * float(i) / 24.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		draw_colored_polygon(pts, fill)
		pts.append(pts[0])
		draw_polyline(pts, outline, 2.0)


## v3.8: battle backdrop with the painted ground PINNED to FEET_Y.
## KEEP_ASPECT_COVERED center-crops; on wider screens that pushes the painted
## ground down while fighters stay at fixed FEET_Y -> they look airborne.
## This sizes the (1.14x zoomed) texture by the COVERED scale but positions
## it so image fraction GROUND_F always lands at GROUND_Y, on any aspect.
class PinnedBg extends TextureRect:
	var ground_f := 0.66
	var ground_y := 410.0
	var zoom := 1.14

	func _init() -> void:
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_SCALE
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		_repin()
		get_viewport().size_changed.connect(_repin)

	func _repin() -> void:
		var tex := texture
		if tex == null:
			return
		var vp := get_viewport_rect().size
		if vp.x < 10.0 or vp.y < 10.0:
			return
		var iw := float(tex.get_width())
		var ih := float(tex.get_height())
		var sc := maxf(vp.x / iw, vp.y / ih) * zoom
		size = Vector2(iw * sc, ih * sc)
		position = Vector2((vp.x - iw * sc) * 0.5, ground_y - ground_f * ih * sc)


## v3.8 auto-detect chord tracker: a horizontal lute string showing this
## turn's played notes as colored dots — red = Attack, green = Skill,
## gold = Power (grace note, never advances/snaps). When the note string
## is a valid prefix, shows the chord being built toward (name + dim
## remaining notes). Red X flash on snap, gold ring when a chord completed.
class ChordString extends Control:
	var _notes: Array = []   # "A"/"S"/"P" played this turn (display)
	var _seq_len := 0        # A/S notes in the live string
	var _target := ""        # chord id tracked (nearest), or ""
	var _snapped := false
	var _completed := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_tracker(notes: Array, seq_len: int, target: String, snapped: bool, completed: bool) -> void:
		_notes = notes.duplicate()
		_seq_len = seq_len
		_target = target
		_snapped = snapped
		_completed = completed
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var cy := h * 0.5
		var f := UIH.font_reg()
		if _notes.is_empty() and not _completed:
			draw_string(f, Vector2(8, cy + 5), "PLAY NOTES: A / S",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.35))
			return
		# the string
		draw_line(Vector2(8, cy), Vector2(w - 8, cy), Color(0.86, 0.76, 0.52, 0.85), 3.0)
		# played notes, colored
		var nx := 26.0
		var step := 30.0
		for n in _notes:
			var col := Color(0.90, 0.25, 0.18)  # Attack: red
			if str(n) == "S":
				col = Color(0.30, 0.62, 0.30)  # Skill: green
			elif str(n) == "P":
				col = Color(0.95, 0.75, 0.30)  # Power: gold grace note
			draw_circle(Vector2(nx, cy), 10.0, Color(0, 0, 0, 0.55))
			draw_circle(Vector2(nx, cy), 8.0, col)
			nx += step
		if _snapped:
			# snapped string: red X over the middle
			var mx := w * 0.5
			var rc := Color(0.90, 0.20, 0.14)
			draw_line(Vector2(mx - 14, cy - 14), Vector2(mx + 14, cy + 14), rc, 5.0)
			draw_line(Vector2(mx - 14, cy + 14), Vector2(mx + 14, cy - 14), rc, 5.0)
		elif _completed:
			# completed chord: gold ring at the string's end
			draw_arc(Vector2(w - 18, cy), 12.0, 0, TAU, 28, Color(0.98, 0.82, 0.35), 3.0)
		elif _target != "":
			# chord being built toward: name + dim remaining notes
			var seq: Array = ChordDB.seq(_target)
			var rem := seq.size() - _seq_len
			var nm := ChordDB.chord_name(_target)
			var tx := nx + 8.0
			draw_string(f, Vector2(tx, cy + 5), nm,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.9, 0.6, 0.9))
			var gx := tx + f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 16.0
			for i in range(rem):
				draw_arc(Vector2(gx, cy), 8.0, 0, TAU, 24, Color(1, 1, 1, 0.35), 1.5)
				gx += step

var router = null
var encounter: Array = []   # Array of {"id","hp_mult"}; accepts a single id String too
var bs: BattleState = null
var busy := false

var _player_sprite: Control
# v5.9: War Elephant UI (Hai Ba Trung)
var _elephant_sprite: Control = null
var _elephant_hpbar: Control = null
var _player_home := Vector2.ZERO
var _pose_tex := {}
var _bob_tween: Tween = null
var _sway_tween: Tween = null
# per-enemy widget arrays (1-3), parallel to bs.enemies
var _enemy_sprites: Array = []
var _enemy_pose_tex: Array = []   # per enemy: {"idle": tex, "attack": tex, "hurt": tex}
var _enemy_homes: Array = []
var _enemy_bob_tweens: Array = []
var _enemy_strips: Array = []
var _enemy_chips: Array = []   # one centered HBoxContainer per enemy (all chips)
var _enemy_weak: Array = []
var _enemy_vuln: Array = []
var _enemy_strength: Array = []
var _intent_boxes: Array = []
var _intent_badges: Array = []   # Array of Array
var _target_rings: Array = []
var _player_strip: HpStrip
var _p_name_l: Label            # player name label (for layout tests)
var _p_chips: HBoxContainer   # single centered chip row under the player name
var _enemy_names: Array = []    # enemy name labels (for layout tests)
var _enemy_plaques: Array = []  # v5.2: name plaque panels (hidden on death)
var _p_weak: StatChip
var _p_strength: StatChip
var _note_energy: NoteEnergy
var _end_pulse_tw: Tween = null
var _end_pulse_mode := -1
var _pause_pop: PopupPanel
var _draw_l: Label
var _discard_l: Label
var _discard_pile: PileWidget
var _draw_pile: PileWidget
var _relic_box: HBoxContainer
var _deck_btn: Control
var _deck_count_l: Label
var _turn_l: Label
var _phase := "you"  # "you" | "enemy" — drives the turn banner text
var _hand_box: Control
var _chord_str: ChordString  # v3.8 auto-detect chord tracker
var _chordbook_btn: Button
var _p_vuln: StatChip
var _equip_btn: IconButton
var _item_btns: Array = []
var _item_emos: Array = []
var _cmd_panel: PanelContainer  # v3.2 unified bottom-left command panel
var _end_btn: Button
var _float_layer: Control
var _banner_l: Label
var _banner_bg: Control
var _ambient_tweens: Array = []
# long-press-to-inspect tracking for enemy intent popups
var _intent_pop: PopupPanel = null
## Tap-to-inspect: the currently raised (armed) hand card, if any.
var _armed_w: CardWidget = null
var _last_hand_n := 0
var _ei_pressed := false
var _ei_shown := false
var _ei_gen := 0
var _busy_token := 0  # watchdog generation: force-unstick if an animation hangs


## Viewport size in canvas pixels. With stretch aspect="expand" this is
## 1280x720 on 16:9 but 1600x720 on 20:9 phones — never hardcode 1280.
func _vsz() -> Vector2:
	return get_viewport_rect().size


## Watchdog: if `busy` is still set 12s after an animation started, something
## hung (e.g. awaiting a finished tween) — force-release so the game never
## soft-locks. Normal card/enemy animations take < 8s.
func _arm_watchdog() -> void:
	_busy_token += 1
	var tok := _busy_token
	await get_tree().create_timer(12.0).timeout
	if busy and tok == _busy_token:
		busy = false
		_refresh()

const EQUIP_NAMES := {
	"divine_axe": "DIVINE AXE",
	"divine_lute": "DIVINE LUTE",
	"endless_rice_pot": "ENDLESS RICE POT",
}


func _init(p_encounter = null) -> void:
	# Accept a single enemy id String (compat) or an encounter Array.
	if p_encounter is String:
		encounter = [{"id": p_encounter, "hp_mult": 1.0}]
	elif p_encounter is Array:
		encounter = p_encounter
	else:
		encounter = []


func _ready() -> void:
	bs = BattleState.new()
	var seed: int = int(Time.get_unix_time_from_system()) % 1000000
	bs.setup(Game.deck.duplicate(true), encounter, Game, seed if seed != 0 else 7)
	bs.start_player_turn()
	_build_ui()
	_refresh()
	_banner("YOUR TURN")
	_maybe_start_tutorial()


## Tutorial for first-time players (first battle of first run).
var _tutorial: TutorialOverlay = null

func _maybe_start_tutorial() -> void:
	# Only on the very first battle ever.
	if Game.get_meta("_tutorial_done", false):
		return
	Game.set_meta("_tutorial_done", true)
	_tutorial = TutorialOverlay.new()
	_tutorial.z_index = 100
	add_child(_tutorial)
	_tutorial.step_completed.connect(_on_tutorial_step)
	# Deferred (no await): UI is laid out by the time this runs.
	_tutorial.call_deferred("start")


func _on_tutorial_step() -> void:
	_update_tutorial_highlight()


func _update_tutorial_highlight() -> void:
	# Highlighting is now handled inside TutorialOverlay._show_popup().
	pass


## Returns the global rect of a UI element for tutorial highlighting.
func get_tutorial_target_rect(target: String) -> Rect2:
	var rect := Rect2()
	match target:
		"energy":
			if _note_energy and is_instance_valid(_note_energy):
				rect = (_note_energy as Control).get_global_rect()
		"hand":
			if _hand_box and is_instance_valid(_hand_box):
				rect = (_hand_box as Control).get_global_rect()
		"enemy":
			if _enemy_sprites.size() > 0 and is_instance_valid(_enemy_sprites[0]):
				rect = (_enemy_sprites[0] as Control).get_global_rect()
		"equipment":
			if _equip_btn and is_instance_valid(_equip_btn):
				rect = (_equip_btn as Control).get_global_rect()
		"chord":
			if _chord_str and is_instance_valid(_chord_str):
				rect = (_chord_str as Control).get_global_rect()
		"endturn":
			if _end_btn and is_instance_valid(_end_btn):
				rect = (_end_btn as Control).get_global_rect()
	return rect


## CHORD UI (Thach Sanh signature): v3.8 auto-detect chord tracker string
## + CHORD BOOK (reference only). The old COMPOSE lute button is gone:
## chords trigger automatically from the note order you play.
## v3.2: compose lived in the unified command panel (bottom-left);
## CHORD BOOK sits bottom-right above END TURN so the hand
## (which never passes x=1020) can never cover it.
func _build_vessel_indicator() -> void:
	# v6.3: Hai Ba Trung doesn't use chords — skip the note tracker
	if Game.hero_id == "hai_ba_trung":
		_chord_str = null
	else:
		# v3.7: the string sits just ABOVE the hand (hand moved down with
		# TRAY_TOP=500, no room below). x=560 keeps it clear of the HP strips
		# (hero ends x=400, enemy starts x=880); y=468 clears the cards (502+).
		# z_index 6 so a lifted card never hides the chord progress.
		# v3.8: widened for the note tracker (played notes + target name).
		_chord_str = ChordString.new()
		_chord_str.position = Vector2(480, 468)
		_chord_str.size = Vector2(460, 30)
		_chord_str.z_index = 6
		add_child(_chord_str)
	# v3.7: moved down to y=506 — the lowered fighter chips now end at
	# y=498, so the book sits just below the strip band, clear of cards.
	# v6.3: Hide CHORD BOOK for Hai Ba Trung
	if Game.hero_id != "hai_ba_trung":
		_chordbook_btn = UIH.wood_btn("CHORD BOOK", 180, 60)
		_chordbook_btn.position = Vector2(1042, 506)
		_chordbook_btn.pressed.connect(_show_chord_book)
		add_child(_chordbook_btn)


func _refresh_vessel() -> void:
	_refresh_chord()


func _refresh_chord() -> void:
	if _chord_str == null or bs == null:
		return
	_chord_str.set_tracker(bs.turn_notes, bs.chord_seq.size(),
		bs.chord_target(), bs.chord_snapped, bs.chord_completed)


## Chord Book: reference for all chords learned so far this run.
## v3.8: chords trigger automatically — no compose step. Play Attack/Skill
## cards in a chord's note order (red = Attack, green = Skill) to complete
## it, max 1 per turn. A wrong note snaps the string. Power cards are
## free grace notes.
func _show_chord_book() -> void:
	var pop := PopupPanel.new()
	pop.add_theme_stylebox_override("panel", UIH.paper_style(UIH.INK, 2, 3))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	pop.add_child(vb)
	vb.add_child(UIH.header("CHORD BOOK", UIH.STAMP, 16))
	vb.add_child(UIH.label("Play Attack/Skill cards in a chord's note order to trigger it automatically (max 1 per turn). A wrong note snaps the string. Power cards are free grace notes. Learn more from bosses, elites, events and shops.", 12, UIH.DIM))
	for cid in Game.chords:
		vb.add_child(UIH.header(ChordDB.chord_name(cid), UIH.INK, 13))
		vb.add_child(UIH.label("[%s]  %s" % [ChordDB.seq_text(cid), str(ChordDB.get_def(cid).get("text", ""))], 11, UIH.DIM))
	var cb := UIH.btn("CLOSE", 120)
	cb.pressed.connect(func(): pop.hide(); pop.queue_free())
	var cc := HBoxContainer.new()
	cc.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(cb)
	vb.add_child(cc)
	add_child(pop)
	pop.popup_centered()


# ------------------------------------------------------------------ UI ---

func _build_ui() -> void:
	# v3.3: AI-painted Dong Ho backdrop with real dirt ground (no black strip).
	# v3.8: PinnedBg keeps the painted ground at FEET_Y on every aspect
	# (replaces the old center-cropped + 1.14 pivot-zoom setup).
	var bgroot := Control.new()
	bgroot.set_anchors_preset(Control.PRESET_FULL_RECT)
	bgroot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pinned := PinnedBg.new()
	var bg_path := "res://assets/art/vl3/bg-battle-forest.png"
	if Game.hero_id == "hai_ba_trung":
		bg_path = "res://assets/art/vl3/bg_battle_hbt.png"
	pinned.texture = UIH.try_tex(bg_path)
	pinned.ground_y = FEET_Y
	pinned.modulate = Color(1.0, 1.0, 1.02)
	bgroot.add_child(pinned)
	bgroot.add_child(UIH.vignette())
	add_child(bgroot)
	_build_street()
	_build_ambient()
	# v3.1: thin divider marking the hard stage/tray split (TRAY_TOP).
	# Purely decorative; sits behind the cards.
	var div := ColorRect.new()
	div.color = Color(0.85, 0.75, 0.55, 0.28)
	div.position = Vector2(0, TRAY_TOP - 1.0)
	div.size = Vector2(_vsz().x, 2.0)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(div)

	# ---- player sprite (left): Thach Sanh, Dong Ho folk art ----
	# feet on the shared ground line FEET_Y; vl2 art first, vl fallback
	var hero_art := "res://assets/art/vl2/hero_thachsanh.png"
	if Game.hero_id == "hai_ba_trung":
		hero_art = "res://assets/art/vl/hero_haibatrung_battle.png"
	if UIH.try_tex(hero_art) == null:
		hero_art = "res://assets/art/vl/hero_thachsanh.png"
	var hero_tex := UIH.try_tex(hero_art)
	for pose in ["guard", "slash", "hurt", "cast"]:
		_pose_tex[pose] = [hero_tex] if hero_tex else []
	# v3.2: shrink ~17% so the fighter stands on the ground, not looming.
	# v5.9: hero-aware name; sprite art still Thach Sanh until HBT battle sprite ships.
	_player_sprite = _make_sprite(hero_art, CharacterDB.hero_name(Game.hero_id), Color("2a4a6a"), 175.0, 165.0)
	_player_sprite.position = Vector2(HERO_CX - 87.5, FEET_Y - 175.0 * 0.94)
	add_child(_player_sprite)
	_player_home = _player_sprite.position
	_start_idle_bob()
	# v5.9: War Elephant companion (Hai Ba Trung only)
	_build_elephant_ui()

	# ---- player HP strip under the feet (same height as the enemy bars) ----
	# v3.1 stack (all inside the STAGE zone, y < TRAY_TOP):
	#   strip  FEET_Y+10 .. +44 | name plaque FEET_Y+47 .. +69 | chips FEET_Y+70 .. +88
	_player_strip = HpStrip.new()
	_player_strip.bar_w = 220.0
	_player_strip.armor_side = 1.0  # player armor shield on the RIGHT of the bar
	_player_strip.setup()
	_player_strip.custom_minimum_size = Vector2(220, 36)
	_player_strip.size = Vector2(220, 36)
	_player_strip.position = Vector2(HERO_CX - 110.0, FEET_Y + 10.0)
	# above the hand cards (armed cards lift to z 5, above the plates)
	_player_strip.z_index = 4
	add_child(_player_strip)
	# player name on a small dark wood plaque (v3.9.2: readable on any bg)
	# v5.9: hero-aware.
	var hero_label := CharacterDB.hero_name(Game.hero_id)
	var pnm := UIH.label(hero_label, 16, Color(0.95, 0.91, 0.82))
	pnm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pnm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pplaque := PanelContainer.new()
	pplaque.add_theme_stylebox_override("panel", UIH.wood_plaque_style())
	pplaque.add_child(pnm)
	var pptw := UIH.font_reg().get_string_size(hero_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16).x
	var pppw := pptw + 30.0
	pplaque.position = Vector2(HERO_CX - pppw * 0.5, FEET_Y + 47.0)
	pplaque.custom_minimum_size = Vector2(pppw, 22)
	pplaque.size = Vector2(pppw, 22)
	pplaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pplaque.z_index = 4
	add_child(pplaque)
	_p_name_l = pnm
	# player status chips: ONE centered row under the name
	_p_chips = HBoxContainer.new()
	_p_chips.add_theme_constant_override("separation", 8)
	_p_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	_p_chips.position = Vector2(HERO_CX - 110.0, FEET_Y + 70.0)
	_p_chips.custom_minimum_size = Vector2(220, 18)
	_p_chips.size = Vector2(220, 18)
	_p_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p_chips.z_index = 4
	add_child(_p_chips)
	_p_weak = StatChip.new()
	_p_weak.setup("weak")
	_p_weak.tapped.connect(func(_k): _show_status_pop("weak_p"))
	_p_chips.add_child(_p_weak)
	_p_vuln = StatChip.new()
	_p_vuln.setup("vulnerable")
	_p_vuln.tapped.connect(func(_k): _show_status_pop("vulnerable_p"))
	_p_chips.add_child(_p_vuln)
	# strength chip (buff area)
	_p_strength = StatChip.new()
	_p_strength.setup("strength")
	_p_strength.tapped.connect(_show_status_pop)
	_p_chips.add_child(_p_strength)
	# (armor shown in HP strip shield)

	# ---- enemies (right side): 1 / 2 / 3 slots ----
	_build_enemies()

	_build_turn_slip()
	_build_vessel_indicator()
	_build_skill_icons()
	_build_energy_cluster()
	_build_command_panel()
	_build_end_stamp()
	_build_pause_btn()

	# ---- hand (bottom-center): plain holder, cards positioned manually ----
	# (HBoxContainer auto-layout proved unreliable: stale children and transient
	# minimum sizes shifted the row. Manual layout centers exactly at vw/2.)
	_hand_box = Control.new()
	_hand_box.position = Vector2.ZERO
	_hand_box.size = _vsz()
	_hand_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hand_box)

	# ---- banner (center announcements) ----
	_banner_l = UIH.label("", 44, Color("f4ecd8"))
	_banner_l.add_theme_font_override("font", UIH.font_bold())
	_banner_l.add_theme_color_override("font_shadow_color", Color("4a0f0a"))
	_banner_l.add_theme_constant_override("shadow_offset_x", 2)
	_banner_l.add_theme_constant_override("shadow_offset_y", 2)
	_banner_l.position = Vector2(_vsz().x * 0.5 - 300, 280)
	_banner_l.custom_minimum_size = Vector2(600, 80)
	_banner_l.size = Vector2(600, 80)
	_banner_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_l.modulate.a = 0.0
	# red silk ribbon backdrop
	var bbg := UIH.SilkRibbon.new()
	bbg.position = Vector2(_vsz().x * 0.5 - 320, 272)
	bbg.size = Vector2(640, 96)
	bbg.modulate.a = 0.0
	add_child(bbg)
	_banner_bg = bbg
	add_child(_banner_l)


	# ---- float layer ----
	_float_layer = Control.new()
	_float_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_float_layer)


## Slot layout for 1/2/3 enemies on the right side.
## Feet share the ground line: pos.y = FEET_Y - size * 0.94.
## Shifts right with wider viewports so enemies stay near the right edge.
func _enemy_layout() -> Array:
	# v3.1: enemy group mirrored around x=990 (mirror of HERO_CX=290),
	# so hero and enemy sides are symmetric.
	# NOTE: slot["pos"] is the sprite's TOP-LEFT (sprite is size x size),
	# so pos.x = desired_center_x - size/2.
	var dx := _vsz().x - 1280.0
	var n := bs.enemies.size()
	# v5.3: boss (chan_tinh/dai_bang) renders bigger (240) to stand out.
	# Regular enemies match the hero (175) for visual uniformity.
	var is_boss := n == 1 and (str(encounter[0].get("id", "")) == "chan_tinh" or str(encounter[0].get("id", "")) == "dai_bang")
	if is_boss:
		return [{"pos": Vector2(904.0 + dx, FEET_Y - 240.0 * 0.94), "size": 240.0}]
	# v3.2: shrink ~17% so fighters stand on the ground, not looming.
	# v3.2b: keep group centers (990 / 880+1100 / 840+990+1140) so the
	# hero/enemy mirror holds after the shrink.
	if n == 2:
		return [
			{"pos": Vector2(802.0 + dx, FEET_Y - 156.0 * 0.94), "size": 156.0},
			{"pos": Vector2(1022.0 + dx, FEET_Y - 156.0 * 0.94), "size": 156.0},
		]
	if n >= 3:
		return [
			{"pos": Vector2(778.0 + dx, FEET_Y - 124.0 * 0.94), "size": 124.0},
			{"pos": Vector2(928.0 + dx, FEET_Y - 124.0 * 0.94), "size": 124.0},
			{"pos": Vector2(1078.0 + dx, FEET_Y - 124.0 * 0.94), "size": 124.0},
		]
	return [{"pos": Vector2(904.0 + dx, FEET_Y - 172.0 * 0.94), "size": 172.0}]


## HP strip width shrinks with enemy count so the red bars never touch.
## v3.1: single enemy matches the hero strip (220) for exact mirroring.
func _hp_strip_w() -> float:
	var n := bs.enemies.size()
	if n == 2:
		return 160.0
	if n >= 3:
		return 130.0
	return 220.0


func _build_enemies() -> void:
	var layout := _enemy_layout()
	for i in range(bs.enemies.size()):
		var f: BattleState.Fighter = bs.enemies[i]
		var eid: String = str(encounter[i].get("id", ""))
		var slot: Dictionary = layout[i]
		var ssize: float = slot["size"]
		var ecx: float = slot["pos"].x + ssize * 0.5
		# Dong Ho folk art: try vl2 first (drawn facing left), fall back to vl
		# (drawn facing right, so flip it toward the hero on the left).
		var eart_vl := str(EnemyDB.get_def(eid).get("art", ""))
		var eart := "res://assets/art/vl2/" + eart_vl.get_file()
		var use_vl2 := UIH.try_tex(eart) != null
		if not use_vl2:
			eart = eart_vl
		var etex := UIH.try_tex(eart)
		_enemy_pose_tex.append({"idle": etex, "attack": etex, "hurt": etex})
		# flat red target ring on the GROUND under the selected enemy's feet
		# (created before the sprite so it draws underneath)
		var ring := TextureRect.new()
		ring.texture = _ring_tex()
		ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ring.stretch_mode = TextureRect.STRETCH_SCALE
		var rw := ssize * 1.15
		var rh := rw * 0.30
		ring.custom_minimum_size = Vector2(rw, rh)
		ring.size = Vector2(rw, rh)
		ring.position = Vector2(ecx - rw * 0.5, FEET_Y - rh * 0.5)
		ring.modulate = Color(1.0, 0.14, 0.10, 0.95)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.visible = false
		add_child(ring)
		_target_rings.append(ring)
		# gentle pulse so the selected target is unmistakable
		var ptw := ring.create_tween().set_loops()
		ptw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		ptw.tween_property(ring, "modulate:a", 0.55, 0.7)
		ptw.tween_property(ring, "modulate:a", 0.95, 0.7)
		# sprite (tap to target); feet on the shared ground line
		var sp := _make_sprite(eart, f.name.to_upper(), Color("6a2a2a"), ssize, ssize * 0.95)
		# v6.2: Han enemies already face left, don't flip them
		var no_flip := eid in ["han_soldier", "han_archer", "han_general", "to_dinh"]
		if sp is TextureRect and not use_vl2 and not no_flip:
			(sp as TextureRect).flip_h = true
		sp.position = slot["pos"]
		sp.gui_input.connect(_on_enemy_gui.bind(i))
		add_child(sp)
		_enemy_sprites.append(sp)
		_enemy_homes.append(sp.position)
		_start_enemy_bob(i)
		# ---- above the head: small name + BIG intent badges ----
		# v3.1: cluster width shrinks with enemy count so clusters never overlap
		var cw := 220.0
		var ecount := bs.enemies.size()
		if ecount == 2:
			cw = 180.0
		elif ecount >= 3:
			cw = 140.0
		var cluster := VBoxContainer.new()
		cluster.add_theme_constant_override("separation", 4)
		cluster.custom_minimum_size = Vector2(cw, 100)
		cluster.size = Vector2(cw, 100)
		cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cluster.position = Vector2(ecx - cw * 0.5, slot["pos"].y - 104.0)
		add_child(cluster)
		var nm := UIH.label(f.name.to_upper(), 13, Color(0.95, 0.91, 0.82))
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cluster.add_child(nm)
		# intent badges (enlarged; tap / long-press to inspect)
		var ibox := HBoxContainer.new()
		ibox.add_theme_constant_override("separation", 6)
		ibox.alignment = BoxContainer.ALIGNMENT_CENTER
		ibox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cluster.add_child(ibox)
		_intent_boxes.append(ibox)
		_intent_badges.append([])
		# ---- under the feet: HP strip + name + ONE chip row ----
		# v3.1: same stack geometry as the player (strip +10 h36, name plaque
		# +47 h22, chips +70 h18) so both sides mirror exactly; all inside
		# the STAGE zone.
		var hw := _hp_strip_w()
		var strip := HpStrip.new()
		strip.bar_w = hw
		strip.setup()
		strip.custom_minimum_size = Vector2(hw, 36)
		strip.size = Vector2(hw, 36)
		strip.position = Vector2(ecx - hw * 0.5, FEET_Y + 10.0)
		# above the hand cards (armed cards lift to z 5, above the plates)
		strip.z_index = 4
		add_child(strip)
		_enemy_strips.append(strip)
		var ename := f.name.to_upper()
		var enm := UIH.label(ename, 16, Color(0.95, 0.91, 0.82))
		enm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		enm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var eplaque := PanelContainer.new()
		eplaque.add_theme_stylebox_override("panel", UIH.wood_plaque_style())
		eplaque.add_child(enm)
		var etw := UIH.font_reg().get_string_size(ename, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16).x
		var epw := minf(etw + 30.0, hw)
		eplaque.position = Vector2(ecx - epw * 0.5, FEET_Y + 47.0)
		eplaque.custom_minimum_size = Vector2(epw, 22)
		eplaque.size = Vector2(epw, 22)
		eplaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
		eplaque.z_index = 4
		add_child(eplaque)
		_enemy_names.append(enm)
		_enemy_plaques.append(eplaque)
		var chips := HBoxContainer.new()
		chips.add_theme_constant_override("separation", 6)
		chips.alignment = BoxContainer.ALIGNMENT_CENTER
		chips.position = Vector2(ecx - hw * 0.5, FEET_Y + 70.0)
		chips.custom_minimum_size = Vector2(hw, 18)
		chips.size = Vector2(hw, 18)
		chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chips.z_index = 4
		add_child(chips)
		_enemy_chips.append(chips)
		var weakc := StatChip.new()
		weakc.setup("weak")
		weakc.tapped.connect(func(_k): _show_status_pop("weak_e"))
		chips.add_child(weakc)
		_enemy_weak.append(weakc)
		var vulnc := StatChip.new()
		vulnc.setup("vulnerable")
		vulnc.tapped.connect(func(_k): _show_status_pop("vulnerable_e"))
		chips.add_child(vulnc)
		_enemy_vuln.append(vulnc)
		var strc := StatChip.new()
		strc.setup("strength")
		strc.tapped.connect(_show_status_pop)
		chips.add_child(strc)
		_enemy_strength.append(strc)


## Intent badge enlarged for the Dong Ho stage: the telegraphed number is
## the biggest, clearest element on the enemy side. Tap/long-press still
## opens the inspect popup (wired in _refresh).
func _big_intent_badge(itd: Dictionary) -> Control:
	var badge := UIH.intent_badge(itd)
	var box := badge.get_child(0)
	if box != null:
		for ch in box.get_children():
			if ch is Label:
				(ch as Label).add_theme_font_size_override("font_size", 40)
			elif ch is TypeIcon:
				var ti := ch as TypeIcon
				ti.icon_px = 60.0
				ti.custom_minimum_size = Vector2(60, 60)
				ti.queue_redraw()
	return badge


func _on_enemy_gui(event: InputEvent, i: int) -> void:
	# Tap an enemy to select it as the attack target; hold 0.5s to inspect
	# its telegraphed intents in plain language.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if busy or bs.battle_over:
				return
			_ei_pressed = true
			_ei_gen += 1
			_ei_shown = false
			var gen := _ei_gen
			var idx := i
			await get_tree().create_timer(0.5).timeout
			if _ei_gen == gen and _ei_pressed and is_instance_valid(self) and not bs.battle_over:
				_ei_shown = true
				_show_intent_pop(idx)
		else:
			var was_shown := _ei_shown
			_ei_pressed = false
			_ei_gen += 1
			_hide_intent_pop()
			if not was_shown and not busy and not bs.battle_over:
				if bs.enemies[i].hp <= 0:
					_float_text(_enemy_center(i), "Already down.", UIH.DIM)
				elif bs.set_target(i):
					_refresh()
					# Move the armed card's damage preview to the new target.
					if _armed_w != null and is_instance_valid(_armed_w):
						var aidx := _armed_w._hand_index()
						if aidx >= 0:
							_clear_card_preview()
							_show_card_preview(aidx)
	elif event is InputEventMouseMotion and _ei_pressed:
		_ei_pressed = false
		_ei_gen += 1
		_hide_intent_pop()



func _build_skill_icons() -> void:
	# Divine Artifact seal. v3.4: artifacts are PASSIVE (always on).
	# The slot shows the artifact icon; tap to inspect (popup with description).
	# Lives in the unified command panel (bottom-left); positioned by
	# _build_command_panel().
	# (CATCH skill removed per design: hero has a unique passive instead).
	var eqdef: Dictionary = GameState.EQUIPMENT.get(Game.equipment, {})
	var eq_name: String = str(eqdef.get("name", "ARTIFACT")).to_upper()
	var eq_desc: String = str(eqdef.get("desc", "")) + "\nDivine Artifact — passive, always active."
	_equip_btn = UIH.icon_btn(null, eq_name, 52.0)
	var ebtn := _equip_btn as IconButton
	ebtn.tip_title = eq_name
	ebtn.tip_desc = eq_desc
	ebtn.tapped.connect(_on_equipment)
	# v3.4: use the artifact's painted icon (PNG), not the generic folk icon.
	var eq_icon_path := str(eqdef.get("icon", ""))
	var eq_tex := UIH.try_tex(eq_icon_path) if eq_icon_path != "" else null
	var eq_img := TextureRect.new()
	eq_img.texture = eq_tex
	eq_img.custom_minimum_size = Vector2(44, 44)
	eq_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	eq_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	eq_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eq_img.set_anchors_preset(Control.PRESET_CENTER)
	eq_img.position -= Vector2(22, 22)
	_equip_btn.add_child(eq_img)
	_build_item_slots()


## Folk-art icon for items/equipment (replaces emoji, font-safe).
func _folk_icon(art_name: String, px: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UIH.try_tex("res://assets/art/vl/icons/%s.webp" % art_name)
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _build_item_slots() -> void:
	# v3.2: 3 consumable item slots live in the unified command panel
	# (bottom-left); positioned by _build_command_panel().
	for i in range(3):
		var btn := UIH.icon_btn(null, "ITEM", 36.0)
		var ib := btn as IconButton
		ib.tip_title = "ITEM"
		ib.tip_desc = "Empty slot."
		var idx := i
		ib.tapped.connect(func(): _show_item_pop(idx))
		var emo := _folk_icon("drum", 28.0)
		emo.set_anchors_preset(Control.PRESET_CENTER)
		emo.position -= Vector2(14, 14)
		btn.add_child(emo)
		_item_emos.append(emo)
		_item_btns.append(btn)


func _refresh_item_slots() -> void:
	for i in range(3):
		var btn = _item_btns[i]
		var ib := btn as IconButton
		var emo: TextureRect = _item_emos[i]
		if i < Game.items.size():
			var iid: String = Game.items[i]
			var idef: Dictionary = GameState.ITEMS[iid]
			ib.tip_title = str(idef["name"]).to_upper()
			ib.tip_desc = str(idef["desc"])
			(emo as TextureRect).texture = UIH.try_tex("res://assets/art/vl/icons/%s.webp" % str(idef.get("art", "drum")))
			btn.modulate = Color(1, 1, 1)
		else:
			ib.tip_title = "EMPTY"
			ib.tip_desc = "Empty item slot."
			(emo as TextureRect).texture = null
			btn.modulate = Color(0.35, 0.35, 0.38)


func _show_item_pop(idx: int) -> void:
	# Inspect an item: name + effect description + USE button.
	# Tapping USE actually consumes it; tapping elsewhere closes.
	if busy or bs.battle_over:
		return
	if idx < 0 or idx >= Game.items.size():
		return
	_hide_intent_pop()
	var iid: String = Game.items[idx]
	var idef: Dictionary = GameState.ITEMS[iid]
	var pop := PopupPanel.new()
	pop.add_theme_stylebox_override("panel", UIH.paper_style(UIH.INK, 2, 3))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	pop.add_child(vb)
	var title := UIH.header(str(idef["name"]).to_upper(), UIH.STAMP, 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var emo := _folk_icon(str(idef.get("art", "drum")), 56.0)
	var emoh := HBoxContainer.new()
	emoh.alignment = BoxContainer.ALIGNMENT_CENTER
	emoh.add_child(emo)
	vb.add_child(emoh)
	var ds := UIH.label(str(idef["desc"]), 14, UIH.DIM)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.custom_minimum_size = Vector2(260, 0)
	ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(ds)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	var use := UIH.btn("USE", 130)
	use.custom_minimum_size = Vector2(130, 46)
	use.pressed.connect(func(): _hide_intent_pop(); _on_use_item(idx))
	row.add_child(use)
	var close := UIH.btn("CLOSE", 130)
	close.custom_minimum_size = Vector2(130, 46)
	close.pressed.connect(func(): _hide_intent_pop())
	row.add_child(close)
	add_child(pop)
	_intent_pop = pop
	pop.popup_centered()


func _on_use_item(idx: int) -> void:
	if busy or bs.battle_over:
		return
	if idx < 0 or idx >= Game.items.size():
		return
	var iid: String = Game.remove_item(idx)
	if iid == "":
		return
	var idef: Dictionary = GameState.ITEMS[iid]
	var fx: String = str(idef["fx"])
	var val: int = int(idef["val"])
	Sfx.play("ui_click")
	match fx:
		"heal":
			bs.player.hp = mini(bs.player.max_hp, bs.player.hp + val)
			_float_text(_player_center(), "+%d HP" % val, UIH.LT_GREEN)
		"energy":
			bs.energy = mini(_max_energy(), bs.energy + val)
			_float_text(_player_center(), "+%d Energy" % val, UIH.LT_GOLD)
		"energy_draw":
			bs.energy = mini(_max_energy(), bs.energy + val)
			bs.draw_cards(1)
			_float_text(_player_center(), "+%d Energy, +1 card" % val, UIH.LT_GOLD)
		"energy_hurt":
			bs.energy = mini(_max_energy(), bs.energy + val)
			bs.player.hp = maxi(1, bs.player.hp - 5)
			_float_text(_player_center(), "+%d Energy, -5 HP" % val, UIH.LT_GOLD)
		"cleanse":
			bs.player.weak = 0
			bs.player.vulnerable = 0
			_float_text(_player_center(), "Cleansed", UIH.TEAL)
		"armor":
			bs.player.armor += val
			_float_text(_player_center(), "+%d Block" % val, UIH.TEAL)
		"dmg_target":
			bs._damage_enemy(val)
			_float_text(_enemy_center(bs.target_idx), "%d damage!" % val, UIH.STAMP)

		"dmg_draw":
			bs._damage_enemy(val)
			bs.draw_cards(1)
			_float_text(_enemy_center(bs.target_idx), "%d damage!" % val, UIH.STAMP)
		"dmg_all":
			for i in range(bs.enemies.size()):
				if bs.enemies[i].hp > 0:
					var old_t := bs.target_idx
					bs.target_idx = i
					bs._damage_enemy(val)
					bs.target_idx = old_t
			_banner("%d DAMAGE TO ALL!" % val)
		"draw":
			bs.draw_cards(val)
			_float_text(_player_center(), "+%d cards" % val, UIH.LT_GOLD)

		"strength":
			bs.player.strength += val
			_float_text(_player_center(), "+%d Strength" % val, UIH.STAMP)
	_banner(str(idef["name"]).to_upper() + " USED")
	_refresh()


## Dimmed countdown ring + centered number drawn over a skill button
## while it is on cooldown (replaces the red "notification" badge).
class CooldownRing extends Control:
	var frac := 0.0  # 0 = ready, >0 = cooling down

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if frac <= 0.0:
			return
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.40
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * clampf(frac, 0.0, 1.0), 36,
			Color(1.0, 0.82, 0.35, 0.95), 6.0)


func _add_skill_label(btn: Control, text: String) -> void:
	var l := UIH.label(text, 11, Color(0.92, 0.85, 0.68))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.offset_top = btn.size.y * 0.5 + 22.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(l)


func _cooldown_label(btn: Control) -> Label:
	var l := UIH.label("", 26, Color(1.0, 0.95, 0.85))
	l.add_theme_font_override("font", UIH.font_bold())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(l)
	return l


## v3.2: ONE unified command panel, bottom-left.
## [compose lute | energy drums | EQUIP | 3 item slots] in a single wooden
## box, so nothing sits scattered. Hand cards start at x>=416, so the panel
## (x 16..392) can never be touched by the hand.
func _build_command_panel() -> void:
	# v3.3: compact 2-row command cluster (was one wide 376px row that crowded
	# big hands). Row 1: compose + energy. Row 2: equipment + item slots.
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.11, 0.07, 0.92)
	sb.border_color = Color("d9a92e")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(16, 532)
	panel.custom_minimum_size = Vector2(212, 172)
	panel.size = Vector2(212, 172)
	add_child(panel)
	_cmd_panel = panel
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vb)
	# row 1: energy drums (v3.8: compose lute removed — chords auto-detect)
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 10)
	r1.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(r1)
	_note_energy = NoteEnergy.new(Game.hero_id)
	_note_energy.custom_minimum_size = Vector2(100, 60)
	_note_energy.size = Vector2(100, 60)
	_note_energy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r1.add_child(_note_energy)
	# row 2: equipment + caption + item slots
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 8)
	r2.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(r2)
	var eqv := VBoxContainer.new()
	eqv.add_theme_constant_override("separation", 2)
	eqv.alignment = BoxContainer.ALIGNMENT_CENTER
	eqv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_equip_btn.custom_minimum_size = Vector2(52, 52)
	eqv.add_child(_equip_btn)
	var ecap := UIH.label("EQUIP", 11, Color(0.92, 0.85, 0.68))
	ecap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eqv.add_child(ecap)
	r2.add_child(eqv)
	for b in _item_btns:
		(b as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r2.add_child(b)
	# v5.7: relic row (Rai: relics weren't displayed)
	_relic_box = HBoxContainer.new()
	_relic_box.add_theme_constant_override("separation", 6)
	_relic_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(_relic_box)
	_refresh_relics()


func _refresh_relics() -> void:
	if _relic_box == null:
		return
	for c in _relic_box.get_children():
		c.queue_free()
	for rid in Game.relics:
		var rdef: Dictionary = GameState.RELICS.get(rid, {})
		var icon_path := str(rdef.get("icon", ""))
		var tex := UIH.try_tex(icon_path) if icon_path != "" else null
		var btn := UIH.icon_btn(tex, str(rdef.get("name", rid)), 36.0)
		var ib := btn as IconButton
		ib.tip_title = str(rdef.get("name", rid))
		ib.tip_desc = str(rdef.get("desc", ""))
		_relic_box.add_child(btn)


## v5.9: Simple war elephant drawn in code (no art asset yet).
class ElephantSprite extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(120, 100)
		size = Vector2(120, 100)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var body := Color("8a7f72")  # gray-brown
		var dark := Color("5a5348")
		# body (ellipse)
		var pts := PackedVector2Array()
		for i in range(25):
			var a := TAU * float(i) / 24.0
			pts.append(Vector2(60, 55) + Vector2(cos(a) * 45, sin(a) * 30))
		draw_colored_polygon(pts, body)
		# head (circle, right side)
		draw_circle(Vector2(95, 45), 22, body)
		draw_arc(Vector2(95, 45), 22, 0, TAU, 24, dark, 2.0)
		# trunk (curved line down from head)
		var trunk := PackedVector2Array([Vector2(110, 55), Vector2(115, 75), Vector2(108, 90)])
		draw_polyline(trunk, dark, 6.0)
		# tusks
		draw_line(Vector2(105, 60), Vector2(118, 68), Color("e8dcc0"), 3.0)
		# legs (4 rectangles)
		for lx in [25, 45, 75, 95]:
			draw_rect(Rect2(lx, 75, 12, 25), body)
			draw_rect(Rect2(lx, 75, 12, 25), dark, false, 1.5)
		# ears
		draw_circle(Vector2(85, 35), 10, dark)


func _build_elephant_ui() -> void:
	if not bs.has_elephant:
		return
	# v6.2: Use art texture for war elephant (facing right)
	var etex := UIH.try_tex("res://assets/art/vl/elephant_war.png")
	if etex != null:
		var tr := TextureRect.new()
		tr.texture = etex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(160, 140)
		tr.size = Vector2(160, 140)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_elephant_sprite = tr
	else:
		_elephant_sprite = ElephantSprite.new()
	_elephant_sprite.position = Vector2(HERO_CX - 240, FEET_Y - 140)
	add_child(_elephant_sprite)
	# HP bar below elephant
	_elephant_hpbar = UIH.hp_bar(140)
	_elephant_hpbar.position = Vector2(HERO_CX - 240, FEET_Y + 5)
	add_child(_elephant_hpbar)
	_refresh_elephant()


func _refresh_elephant() -> void:
	if _elephant_sprite == null or bs.elephant == null:
		return
	if bs.elephant.hp <= 0:
		_elephant_sprite.modulate.a = 0.3
	else:
		_elephant_sprite.modulate.a = 1.0
	if _elephant_hpbar != null and _elephant_hpbar.has_method("set_values"):
		_elephant_hpbar.set_values(bs.elephant.hp, bs.elephant.max_hp)


func _build_energy_cluster() -> void:
	# v3.2: the energy drums live in the unified command panel (bottom-left);
	# only their values are refreshed here. 28px left safe-area margin.
	# (DISCARD lives bottom-right under END TURN; deck icon next to Pause.)
	_discard_pile = PileWidget.new("DISCARD")
	# v3.7: under the compact right column (CHORD BOOK 506..566,
	# END TURN 572..668) — clear of both.
	_discard_pile.position = Vector2(1136, 668)
	add_child(_discard_pile)
	_discard_pile.mouse_filter = Control.MOUSE_FILTER_STOP
	_discard_pile.gui_input.connect(_on_pile_tapped.bind("discard"))
	# v5.7: draw pile bottom-left (Rai: show deck count + draw animation)
	_draw_pile = PileWidget.new("DRAW")
	_draw_pile.position = Vector2(28, 668)
	add_child(_draw_pile)
	_draw_pile.mouse_filter = Control.MOUSE_FILTER_STOP
	_draw_pile.gui_input.connect(_on_pile_tapped.bind("draw"))
	_build_deck_btn()


func _pile_slip(caption: String, parent: Control) -> Label:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIH.PAPER_DK
	sb.border_color = UIH.INK_SOFT
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", sb)
	var l := UIH.label("", 14, UIH.INK)
	l.add_theme_font_override("font", UIH.font_bold())
	p.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UIH.header(caption, UIH.INK_SOFT, 12))
	row.add_child(p)
	parent.add_child(row)
	return l


func _build_turn_slip() -> void:
	# v3.2: top-center turn slip as a red silk ribbon with gold text.
	# (The old "THACH SANH · LEGEND I" legend banner was removed.)
	_turn_l = UIH.label("", 14, Color("f4ecd8"))
	_turn_l.add_theme_font_override("font", UIH.font_bold())
	var rib := UIH.SilkRibbon.new()
	rib.position = Vector2(_vsz().x * 0.5 - 150, 30)
	rib.size = Vector2(300, 34)
	add_child(rib)
	_turn_l.position = Vector2(_vsz().x * 0.5 - 150, 30)
	_turn_l.custom_minimum_size = Vector2(300, 34)
	_turn_l.size = Vector2(300, 34)
	_turn_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_turn_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_turn_l)


func _build_end_stamp() -> void:
	# END TURN = red seal stamp (Dong Ho style, v3.4), bottom-right corner
	# above the DISCARD pile, 16px right safe-area margin.
	# v3.7: 96px and tucked under CHORD BOOK (moved to y=506) — the compact
	# right column is CHORD BOOK (506..566) / END TURN (572..668) / DISCARD.
	_end_btn = UIH.seal_btn("END\nTURN", 96)
	_end_btn.position = Vector2(_vsz().x - 28 - 96, 572)
	_end_btn.pivot_offset = Vector2(48, 48)
	_end_btn.tooltip_text = "End your turn."
	_end_btn.pressed.connect(_on_end_turn)
	add_child(_end_btn)


## True when the player has at least one playable card in hand.
func _any_playable() -> bool:
	if bs == null:
		return false
	for i in range(bs.hand.size()):
		var r: Dictionary = bs.can_play(i)
		if r.get("ok", false):
			return true
	return false


## END TURN glow states: 0 = dim/locked, 1 = usable (gentle glow pulse),
## 2 = stuck nudge (stronger pulse). Replaces the old on/off pulse.
func _set_end_pulse(mode: int) -> void:
	if mode == _end_pulse_mode:
		return
	if _end_pulse_tw != null and _end_pulse_tw.is_valid():
		_end_pulse_tw.kill()
		_end_pulse_tw = null
	_end_pulse_mode = mode
	_end_btn.modulate.a = 1.0
	if mode == 0:
		return
	_end_pulse_tw = create_tween().set_loops()
	if mode == 1:
		# usable: gentle glow — soft alpha breathing
		_end_pulse_tw.tween_property(_end_btn, "modulate:a", 0.88, 0.9)
		_end_pulse_tw.tween_property(_end_btn, "modulate:a", 1.0, 0.9)
	else:
		# stuck: stronger nudge
		_end_pulse_tw.tween_property(_end_btn, "modulate:a", 0.55, 0.7)
		_end_pulse_tw.tween_property(_end_btn, "modulate:a", 1.0, 0.7)


func _build_street() -> void:
	# v3.3: the backdrop itself is a painted Dong Ho dirt ground, so the old
	# black cobblestone strip is gone. Fighters stand on the painted earth
	# (feet at FEET_Y) with their own soft shadows; no seam line needed.
	# soft darkening at the very bottom so the hand, piles and orb stay readable
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0.01, 0.012, 0.02, 0.5))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_LINEAR
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	t.width = 16
	t.height = 128
	var shade := TextureRect.new()
	shade.texture = t
	shade.position = Vector2(0, _vsz().y - 150.0)
	shade.size = Vector2(_vsz().x, 150.0)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _soft_disc(alpha: float) -> GradientTexture2D:
	var fg := Gradient.new()
	fg.set_color(0, Color(0.62, 0.66, 0.75, alpha))
	fg.set_color(1, Color(0.62, 0.66, 0.75, 0.0))
	var ft := GradientTexture2D.new()
	ft.gradient = fg
	ft.fill = GradientTexture2D.FILL_RADIAL
	ft.fill_from = Vector2(0.5, 0.5)
	ft.fill_to = Vector2(1.0, 0.5)
	ft.width = 128
	ft.height = 128
	return ft


func _build_ambient() -> void:
	# dust motes drifting up (neutral ambience; noir fog banks removed)
	var dust := CPUParticles2D.new()
	dust.amount = 16
	dust.lifetime = 7.0
	dust.preprocess = 7.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(620, 180)
	dust.position = Vector2(_vsz().x * 0.5, 300)
	dust.direction = Vector2(0, -1)
	dust.spread = 35.0
	dust.initial_velocity_min = 6.0
	dust.initial_velocity_max = 16.0
	dust.gravity = Vector2.ZERO
	dust.scale_amount_min = 1.5
	dust.scale_amount_max = 3.0
	dust.color = Color(0.8, 0.8, 0.85, 0.28)
	add_child(dust)


func _make_sprite(path: String, fallback_text: String, fallback_color: Color, size: float = 280.0, shadow_w: float = 220.0) -> Control:
	var tex := UIH.try_tex(path)
	if tex:
		var t := TextureRect.new()
		t.texture = tex
		t.custom_minimum_size = Vector2(size, size)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var sh := UIH.ground_shadow(shadow_w, shadow_w * 0.22)
		sh.name = "GroundShadow"
		sh.show_behind_parent = true
		sh.position = Vector2((size - shadow_w) * 0.5, size - shadow_w * 0.22 - 4)
		t.add_child(sh)
		return t
	var c := ColorRect.new()
	c.color = fallback_color
	c.custom_minimum_size = Vector2(220, 260)
	var l := UIH.label(fallback_text, 22)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(l)
	return c


## Warm/cool radial halo behind a combatant so the silhouette separates
## from the busy backdrop (no saturation boost — a soft spotlight glow that
## fades into a dark vignette at the edge). Added as a child with
## show_behind_parent (same pattern as the ground shadow), so it follows
## the sprite's bob/lunge tweens automatically.
# ------------------------------------------------------------- idle life ---
func _set_player_pose(pose: String) -> void:
	var frames: Array = _pose_tex.get(pose, [])
	if frames.is_empty():
		return
	_current_pose = pose
	_pose_frame = 0
	if _player_sprite is TextureRect:
		(_player_sprite as TextureRect).texture = frames[0]
	_start_pose_anim()

var _pose_anim_timer: Timer = null
var _current_pose := "guard"
var _pose_frame := 0

func _start_pose_anim() -> void:
	_stop_pose_anim()
	_pose_anim_timer = Timer.new()
	_pose_anim_timer.wait_time = 0.22  # ~4.5 fps, smooth chibi animation
	_pose_anim_timer.timeout.connect(_advance_pose_frame)
	add_child(_pose_anim_timer)
	_pose_anim_timer.start()

func _stop_pose_anim() -> void:
	if _pose_anim_timer and is_instance_valid(_pose_anim_timer):
		_pose_anim_timer.stop()
		_pose_anim_timer.queue_free()
	_pose_anim_timer = null

func _advance_pose_frame() -> void:
	var frames: Array = _pose_tex.get(_current_pose, [])
	if frames.size() < 2:
		return
	_pose_frame = (_pose_frame + 1) % frames.size()
	if _player_sprite is TextureRect:
		(_player_sprite as TextureRect).texture = frames[_pose_frame]


## Swap an enemy's sprite to its attack/hurt/idle art (no-op if art missing).
func _set_enemy_pose(i: int, pose: String) -> void:
	if i < 0 or i >= _enemy_sprites.size() or i >= _enemy_pose_tex.size():
		return
	var sp: Control = _enemy_sprites[i]
	if sp == null or not (sp is TextureRect):
		return
	var tex: Texture2D = (_enemy_pose_tex[i] as Dictionary).get(pose, null)
	if tex:
		(sp as TextureRect).texture = tex


func _start_idle_bob() -> void:
	_stop_idle_bob()
	if not is_instance_valid(_player_sprite):
		return
	_player_sprite.position = _player_home
	# very subtle breathing only — no sideways sway (user wants the fighter
	# to stand still, not wander back and forth)
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(_player_sprite, "position:y", _player_home.y - 2.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(_player_sprite, "position:y", _player_home.y + 1.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_idle_bob() -> void:
	if _bob_tween and _bob_tween.is_valid():
		_bob_tween.kill()
	_bob_tween = null
	if _sway_tween and _sway_tween.is_valid():
		_sway_tween.kill()
	_sway_tween = null


func _sway_hips() -> void:
	# occasional weight shift, fired once per bob loop
	if not is_instance_valid(_player_sprite):
		return
	if _bob_tween == null or not _bob_tween.is_valid():
		return
	if _sway_tween and _sway_tween.is_valid():
		_sway_tween.kill()
	_sway_tween = create_tween()
	var tw := _sway_tween
	var dx := randf_range(-9.0, 9.0)
	tw.tween_property(_player_sprite, "position:x", _player_home.x + dx, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_player_sprite, "position:x", _player_home.x, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _start_enemy_bob(i: int) -> void:
	while _enemy_bob_tweens.size() <= i:
		_enemy_bob_tweens.append(null)
	var old: Tween = _enemy_bob_tweens[i]
	if old and old.is_valid():
		old.kill()
	if not is_instance_valid(_enemy_sprites[i]):
		return
	var sp: Control = _enemy_sprites[i]
	var home: Vector2 = _enemy_homes[i]
	var tw := create_tween().set_loops()
	tw.tween_property(sp, "position:y", home.y - 2.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(sp, "position:y", home.y + 1.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_enemy_bob_tweens[i] = tw


func _kill_bobs() -> void:
	_stop_idle_bob()
	for tw in _enemy_bob_tweens:
		if tw and (tw as Tween).is_valid():
			(tw as Tween).kill()
	_enemy_bob_tweens.clear()


func _exit_tree() -> void:
	_kill_bobs()
	for tw in _ambient_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_ambient_tweens.clear()


# ---------------------------------------------------------------- refresh ---

func _max_energy() -> int:
	var m := 3
	if Game.has_perk("energy_t1"):
		m += 1
	if bs.turn_count <= 1 and Game.has_relic("coffee_thermos"):
		m += 1
	return m


## Final incoming damage of one telegraphed intent, after every modifier.
## Mirrors BattleState's NIGHTMARE resolution order exactly:
## Final displayed intent damage: base power + enemy strength, x0.75 if weak.
## each step rounded like the logic code. Non-attack intents show raw power.
func _final_intent_dmg(it: Dictionary, ei: int = -1) -> int:
	if it.get("failed", false):
		return 0
	if str(it.get("kind", "")) != "attack":
		return int(it.get("power", 0))
	var dmg := float(it.get("power", 0))
	if ei >= 0 and ei < bs.enemies.size():
		var e: BattleState.Fighter = bs.enemies[ei]
		dmg += e.strength
		if e.weak > 0:
			dmg = round(dmg * 0.75)
	return maxi(0, int(dmg))


## Total HP you are about to lose next enemy turn (after your armor),
## for the damage preview on your HP bar.
func _incoming_total() -> int:
	if bs == null or bs.battle_over:
		return 0
	var total := 0
	for i in range(bs.enemies.size()):
		if bs.enemies[i].hp <= 0:
			continue
		for it in bs.intent_summary_for(i):
			total += _final_intent_dmg(it)
	return maxi(0, total - bs.player.armor)


## Update HP bars to match battle state. Call this right AFTER a damage
## animation lands so the bar drains in sync with the hit.
func _sync_hp() -> void:
	_player_strip.set_hp(bs.player.hp, bs.player.max_hp, bs.player.armor)
	for i in range(bs.enemies.size()):
		var f: BattleState.Fighter = bs.enemies[i]
		(_enemy_strips[i] as HpStrip).set_hp(f.hp, f.max_hp, f.armor)


func _refresh(defer_hp := false) -> void:
	# defer_hp: skip HP bar updates (used before damage animations so the
	# bar drops in sync with the slash, not before it). Call _sync_hp()
	# right after the hit lands.
	if not defer_hp:
		_sync_hp()
	_player_strip.set_preview(_incoming_total())
	_p_weak.set_value(bs.player.weak)
	_p_vuln.set_value(bs.player.vulnerable)
	_p_strength.set_value(bs.player.strength)
	_note_energy.set_values(bs.energy, _max_energy())
	_discard_pile.set_count(bs.discard_pile.size())
	if _draw_pile:
		_draw_pile.set_count(bs.draw_pile.size())
	_refresh_relics()
	_refresh_elephant()
	if _deck_count_l:
		_deck_count_l.text = str(bs.draw_pile.size() + bs.hand.size() + bs.discard_pile.size())
	_refresh_vessel()
	# per-enemy: HP strip, status chips, intents, target ring, death dim
	for i in range(bs.enemies.size()):
		var f: BattleState.Fighter = bs.enemies[i]
		var alive: bool = f.hp > 0
		if not defer_hp:
			(_enemy_strips[i] as HpStrip).set_hp(f.hp, f.max_hp, f.armor)
		(_enemy_weak[i] as StatChip).set_value(f.weak)
		(_enemy_vuln[i] as StatChip).set_value(f.vulnerable)
		(_enemy_strength[i] as StatChip).set_value(f.strength)
		for b in _intent_badges[i]:
			(b as Control).queue_free()
		_intent_badges[i].clear()
		for c in (_intent_boxes[i] as HBoxContainer).get_children():
			c.queue_free()
		if alive and not bs.battle_over:
			for it in bs.intent_summary_for(i):
				var itd: Dictionary = (it as Dictionary).duplicate()
				itd["shown"] = _final_intent_dmg(itd, i)
				var badge := _big_intent_badge(itd)
				badge.mouse_filter = Control.MOUSE_FILTER_STOP
				var eidx := i
				badge.gui_input.connect(func(event: InputEvent):
					if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
						_show_intent_pop(eidx, true)
						get_viewport().set_input_as_handled()
				)
				(_intent_boxes[i] as HBoxContainer).add_child(badge)
				_intent_badges[i].append(badge)
		(_target_rings[i] as TextureRect).visible = alive and i == bs.target_idx and not bs.battle_over
		# v5.2: dead enemies are fully hidden (death anim already played); no dim linger.
		if alive:
			(_enemy_sprites[i] as Control).modulate = Color(1, 1, 1, 1)
			(_enemy_sprites[i] as Control).visible = true
			if is_instance_valid(_enemy_strips[i]):
				(_enemy_strips[i] as Control).visible = true
			if i < _enemy_plaques.size() and is_instance_valid(_enemy_plaques[i]):
				(_enemy_plaques[i] as Control).visible = true
			if is_instance_valid(_enemy_chips[i]):
				(_enemy_chips[i] as Control).visible = true
			if is_instance_valid(_intent_boxes[i]):
				(_intent_boxes[i] as Control).visible = true
		else:
			_hide_enemy_ui(i)
			if is_instance_valid(_enemy_sprites[i]):
				(_enemy_sprites[i] as Control).visible = false
	_turn_l.text = "— TURN %d · %s —" % [bs.turn_count, "YOUR TURN" if _phase == "you" else "ENEMY TURN"]

	# hand: cards laid out manually, row centered exactly at vw/2.
	# Overlap is allowed for big hands (negative sep); clear fan arc.
	# v3.1: hard stage/tray split — cards start at TRAY_TOP + 2 so the hand
	# can NEVER touch the HP strips / names / chip rows in the stage zone.
	# Row raised ~50px so card text clears the screen bottom edge.
	var old_n := _last_hand_n
	var hand_grew := bs.hand.size() > old_n
	_last_hand_n = bs.hand.size()
	for c in _hand_box.get_children():
		_hand_box.remove_child(c)
		c.queue_free()
	_armed_w = null
	var n := bs.hand.size()
	var cw := CardWidget.CARD_W
	var ch := CardWidget.CARD_H
	# v6.5: center hand zone on screen (Rai: cards looked left-shifted)
	var vw := _vsz().x
	var zone_w0 := 620.0
	var zone_l := (vw - zone_w0) * 0.5
	var zone_r := zone_l + zone_w0
	var zone_w := zone_r - zone_l
	var sep := 14.0
	if n > 1:
		sep = minf(14.0, (zone_w - float(n) * cw) / float(n - 1))
		# Allow overlap (negative sep) but cap at -cw*0.6 so cards stay visible
		sep = maxf(sep, -cw * 0.6)
	var total_w := float(n) * cw + float(maxi(n - 1, 0)) * sep
	var start_x := zone_l + (zone_w - total_w) * 0.5
	var mid := (float(n) - 1.0) * 0.5
	for i in range(n):
		var w := CardWidget.new(bs.hand[i], bs)
		w.clicked.connect(_on_card_clicked)
		w.drag_play.connect(_on_card_drag_play)
		var off := float(i) - mid
		w.position = Vector2(start_x + float(i) * (cw + sep), TRAY_TOP + 2.0 + pow(absf(off), 1.4) * 9.0)
		w.custom_minimum_size = Vector2(cw, ch)
		w.size = Vector2(cw, ch)
		w.pivot_offset = Vector2(cw, ch) * 0.5
		w.rotation = off * 0.055
		_hand_box.add_child(w)
	# v5.7: draw animation — cards fly from deck pile (left) with stagger (Rai)
	if hand_grew:
		var new_count := bs.hand.size() - old_n
		var total := _hand_box.get_child_count()
		var deck_pos := Vector2(28, 668)  # draw pile position
		for j in range(total):
			var w2 := _hand_box.get_child(j) as CardWidget
			if w2 == null or j < total - new_count:
				continue
			var target_pos := w2.position
			w2.position = deck_pos
			w2.modulate.a = 0.0
			w2.scale = Vector2(0.5, 0.5)
			var tw := w2.create_tween()
			tw.set_parallel(true)
			tw.tween_property(w2, "position", target_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(float(j - (total - new_count)) * 0.08)
			tw.tween_property(w2, "modulate:a", 1.0, 0.25).set_delay(float(j - (total - new_count)) * 0.08)
			tw.tween_property(w2, "scale", Vector2.ONE, 0.3).set_delay(float(j - (total - new_count)) * 0.08)

	# buttons: Divine Artifact is passive (always on) — no cooldown.
	# Tap the EQUIP slot to inspect the artifact.
	_equip_btn.modulate = Color(1, 1, 1)
	# keep tappable to inspect (don't hard-disable)
	_equip_btn.disabled = busy
	_refresh_item_slots()
	# END TURN: locked (grey) during the enemy turn and while a card is armed
	# (mid-play); gentle glow pulse when usable; stronger nudge when stuck.
	var enemy_phase := busy or _phase == "enemy"
	var targeting := _armed_w != null and is_instance_valid(_armed_w)
	_end_btn.disabled = enemy_phase or targeting
	if enemy_phase or targeting:
		_set_end_pulse(0)
	elif bs.energy <= 0 or not _any_playable():
		_set_end_pulse(2)
	else:
		_set_end_pulse(1)



# ----------------------------------------------------------------- input ---

func _on_card_clicked(w: CardWidget) -> void:
	if busy or bs.battle_over:
		return
	var idx := w._hand_index()
	if idx < 0:
		return
	# Two-tap flow (phone readability): first tap raises the card for
	# reading and shows a damage/heal preview; tapping the raised card
	# again plays it.
	if w.playable and w != _armed_w:
		_disarm_card()
		_armed_w = w
		w.set_armed(true)
		_hand_box.move_child(w, -1)
		_show_card_preview(idx)
		return
	_play_card(w)


## Show what the armed card would do: damage preview stripes on the
## target enemy's HP bar, heal estimate on the player.
func _show_card_preview(hand_idx: int) -> void:
	if bs == null:
		return
	var pv: Dictionary = bs.preview_card(hand_idx)
	var dmg: int = int(pv.get("dmg", 0))
	var heal: int = int(pv.get("heal", 0))
	if dmg > 0 and bs.target_idx >= 0 and bs.target_idx < _enemy_strips.size():
		(_enemy_strips[bs.target_idx] as HpStrip).set_preview(dmg)
	if heal > 0:
		_float_text(_player_center(), "+%d HP" % heal, Color("6fbf73"))


## Clear all card previews (enemy damage stripes).
func _clear_card_preview() -> void:
	for s in _enemy_strips:
		if is_instance_valid(s):
			(s as HpStrip).set_preview(0)


## Drag upward on a card: play it immediately (mobile shortcut).
func _on_card_drag_play(w: CardWidget) -> void:
	if busy or bs.battle_over:
		return
	if w._hand_index() < 0:
		return
	_play_card(w)


## Shared card-play path for tap-confirm and drag-play.
func _play_card(w: CardWidget) -> void:
	_disarm_card()
	var idx := w._hand_index()
	if idx < 0:
		return
	var card: Dictionary = bs.hand[idx]
	var armor_before: int = bs.player.armor
	var r: Dictionary = bs.play_card(idx)
	if not r["ok"]:
		_float_text(Vector2(_vsz().x * 0.5, 618), r["reason"], UIH.STAMP)
		return
	# RELEASE token: show STRIKE/GUARD choice popup.
	if r.get("needs_release_choice", false):
		_show_release_choice(int(r.get("power", 0)), w)
		return
	w.modulate.a = 0.25
	busy = true
	_arm_watchdog()
	Sfx.play("card_play")
	await _animate_card_events(bs.events, card, w.get_global_rect().get_center(), armor_before)
	# v5.7: card flies to discard pile (Rai)
	var discard_pos := Vector2(1136, 668)
	var fly_tw := w.create_tween()
	fly_tw.set_parallel(true)
	fly_tw.tween_property(w, "global_position", discard_pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly_tw.tween_property(w, "modulate:a", 0.0, 0.3)
	fly_tw.tween_property(w, "scale", Vector2(0.3, 0.3), 0.3)
	await fly_tw.finished
	busy = false
	_refresh()
	_check_end()
	# Tutorial: notify if this was the action step.
	if _tutorial and is_instance_valid(_tutorial):
		_tutorial.notify_action_done()


## ECHO OF SLEEP choice: DROWN (damage) or SLUMBER (armor + cleanse Drowsy).
func _show_release_choice(power: int, w: CardWidget) -> void:
	var pop := PopupPanel.new()
	pop.add_theme_stylebox_override("panel", UIH.paper_style(UIH.INK, 2, 3))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pop.add_child(vb)
	vb.add_child(UIH.header("ECHO OF SLEEP — CHOOSE", UIH.STAMP, 18))
	vb.add_child(UIH.label("The Verb Cage releases its captive echo (%d)." % power, 14, UIH.INK))
	var sb := UIH.btn("🌊 DROWN: Deal %d damage" % power, 280)
	sb.pressed.connect(func(): pop.hide(); pop.queue_free(); _resolve_release("drown", w))
	vb.add_child(sb)
	var gb := UIH.btn("😴 SLUMBER: Gain %d Armor, cleanse Drowsy" % power, 280)
	gb.pressed.connect(func(): pop.hide(); pop.queue_free(); _resolve_release("slumber", w))
	vb.add_child(gb)
	add_child(pop)
	pop.popup_centered()


func _resolve_release(choice: String, w: CardWidget) -> void:
	var armor_before: int = bs.player.armor
	bs.resolve_release(choice)
	w.modulate.a = 0.25
	busy = true
	_arm_watchdog()
	Sfx.play("card_play")
	await _animate_card_events(bs.events, {"id": "echo_of_sleep"}, w.get_global_rect().get_center(), armor_before)
	busy = false
	_refresh()
	_check_end()


## Tap on empty space: lower the raised (armed) card.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_disarm_card()


## Lower the raised (armed) hand card, if any.
func _disarm_card() -> void:
	if _armed_w != null and is_instance_valid(_armed_w):
		_armed_w.set_armed(false)
	_armed_w = null
	_clear_card_preview()


func _on_pile_tapped(event: InputEvent, which: String) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_show_pile_popup(which)


func _show_pile_popup(which: String) -> void:
	if busy or bs == null:
		return
	var cards: Array = []
	var title := ""
	match which:
		"draw":
			cards = bs.draw_pile
			title = "DRAW PILE"
		"discard":
			cards = bs.discard_pile
			title = "DISCARD PILE"
		_:
			cards = bs.draw_pile + bs.hand + bs.discard_pile
			title = "FULL DECK"
	# cards shown as real CardWidgets in a grid (inspect-only), in pile order
	var vw := _vsz()
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var pw: float = minf(vw.x - 60.0, 720.0)
	var ph: float = minf(vw.y - 60.0, 600.0)
	var panel := UIH.panel()
	panel.custom_minimum_size = Vector2(pw, ph)
	panel.size = Vector2(pw, ph)
	panel.position = Vector2((vw.x - pw) * 0.5, (vw.y - ph) * 0.5)
	overlay.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var ttl := UIH.header("%s (%d)" % [title, cards.size()], UIH.STAMP, 20)
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(ttl)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(pw - 40.0, ph - 130.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)
	if cards.is_empty():
		var e := UIH.label("— empty —", 15, UIH.INK_SOFT)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(e)
	else:
		# real cards in a grid, inspect-only (no input, no hover)
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(grid)
		for c in cards:
			var w := CardWidget.new(c, null)
			w.inspect_only = true
			w.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(w)
	var hint := UIH.label("Tap outside to close.", 13, UIH.INK_SOFT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				overlay.queue_free())


## Animate remaining hand cards flying to the discard pile (staggered).
func _animate_hand_discard() -> void:
	var cards := _hand_box.get_children()
	if cards.is_empty():
		return
	var pile_c := _discard_pile.get_global_rect().get_center()
	# Reparent to top level so _refresh won't free them mid-flight.
	for c in cards:
		_hand_box.remove_child(c)
		add_child(c)
		c.z_index = 50
	# Staggered flight: each card arcs to the pile and fades.
	var i := 0
	for c in cards:
		var cc := c as Control
		var delay := float(i) * 0.06
		_fly_discard_one(cc, pile_c, delay)
		i += 1
		Sfx.play("card_discard")
	await get_tree().create_timer(0.35 + float(cards.size()) * 0.06).timeout
	for c in cards:
		if is_instance_valid(c):
			c.queue_free()


func _fly_discard_one(cc: Control, pile_c: Vector2, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(cc):
		return
	await _fly_card_to(cc, pile_c, 0.4, 0.35, 80.0, true)


func _on_end_turn() -> void:
	if busy or bs.battle_over:
		return
	Sfx.play("end_turn")
	busy = true
	_arm_watchdog()
	_disarm_card()
	# Discard animation: remaining hand cards fly to the discard pile.
	await _animate_hand_discard()
	bs.end_player_turn()
	_refresh()
	_phase = "enemy"
	_banner("ENEMY TURN")
	_refresh(true)  # defer HP: bars update as each hit lands
	await _animate_enemy_events(bs.events)
	_phase = "you"
	if not bs.battle_over:
		bs.start_player_turn()
		_banner("YOUR TURN")
		Sfx.play("new_turn")
		Sfx.play("card_draw")
	busy = false
	_refresh()


func _build_pause_btn() -> void:
	# top-right pause: opens resume / forfeit overlay.
	# Icon is drawn in code (two ink bars) — no art asset needed.
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ink := Color(0.22, 0.19, 0.15)
	for y in range(12, 37):
		for x in range(16, 23):
			img.set_pixel(x, y, ink)
		for x in range(26, 33):
			img.set_pixel(x, y, ink)
	var pb := UIH.icon_btn(ImageTexture.create_from_image(img), "PAUSE", 52.0)
	var btn := pb as IconButton
	btn.tip_title = "PAUSE"
	btn.tip_desc = "Pause the battle."
	btn.tapped.connect(_show_pause)
	pb.position = Vector2(_vsz().x - 68, 12)
	add_child(pb)


func _build_deck_btn() -> void:
	# deck as a tappable icon next to Pause (top-right). Shows card count;
	# tap opens the full deck list. Icon = stacked cards, drawn in code.
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var paper := Color(0.93, 0.87, 0.74)
	var ink := Color(0.22, 0.19, 0.15)
	for o in [8, 4, 0]:
		var x0: int = 14 + o
		var y0: int = 10 + o
		for y in range(y0, y0 + 28):
			for x in range(x0, x0 + 20):
				var edge: bool = x == x0 or x == x0 + 19 or y == y0 or y == y0 + 27
				img.set_pixel(x, y, ink if edge else paper)
	var db := UIH.icon_btn(ImageTexture.create_from_image(img), "DECK", 52.0)
	var btn := db as IconButton
	btn.tip_title = "DECK"
	btn.tip_desc = "View all cards in your deck."
	btn.tapped.connect(_on_deck_tapped)
	db.position = Vector2(_vsz().x - 136, 12)
	add_child(db)
	_deck_btn = db
	_deck_count_l = _cooldown_label(db)
	_deck_count_l.add_theme_font_size_override("font_size", 18)
	_deck_count_l.add_theme_color_override("font_color", Color(0.25, 0.18, 0.12))
	_deck_count_l.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	_deck_count_l.add_theme_constant_override("outline_size", 4)


func _on_deck_tapped() -> void:
	_show_pile_popup("deck")


func _show_pause() -> void:
	if _pause_pop and is_instance_valid(_pause_pop):
		_pause_pop.hide()
	_pause_pop = PopupPanel.new()
	_pause_pop.add_theme_stylebox_override("panel", UIH.paper_style(UIH.INK, 2, 4))
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	_pause_pop.add_child(pv)
	pv.add_child(UIH.title("PAUSED", 24))
	var rb := UIH.btn("RESUME", 220)
	rb.pressed.connect(func(): _pause_pop.hide())
	pv.add_child(rb)
	var fb := UIH.btn("FORFEIT RUN", 220)
	fb.pressed.connect(func():
		_pause_pop.hide()
		if router:
			router.show_title())
	pv.add_child(fb)
	_pause_pop.size = Vector2(300, 220)
	add_child(_pause_pop)
	_pause_pop.popup_centered()
	_check_end()


func _on_equipment() -> void:
	# v3.4: Divine Artifacts are passive. Tap EQUIP to inspect (popup).
	if busy:
		return
	Sfx.play("ui_click")
	var eqdef: Dictionary = GameState.EQUIPMENT.get(Game.equipment, {})
	var eq_name := str(eqdef.get("name", "Divine Artifact"))
	var eq_desc := str(eqdef.get("desc", ""))
	var eq_icon := str(eqdef.get("icon", ""))
	_inspect_popup("DIVINE ARTIFACT", eq_name, eq_desc, eq_icon)
	_refresh()


## v3.4: Generic inspect popup for the Divine Artifact (icon + name + desc).
func _inspect_popup(kind: String, item_name: String, desc: String, icon_path: String) -> void:
	_hide_intent_pop()
	var pop := PopupPanel.new()
	pop.add_theme_stylebox_override("panel", UIH.paper_style(UIH.INK, 2, 3))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	pop.add_child(vb)
	var title := UIH.header(kind, UIH.STAMP, 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var nm := UIH.header(item_name.to_upper(), UIH.INK, 20)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(nm)
	if icon_path != "":
		var tex := UIH.try_tex(icon_path)
		if tex != null:
			var img := TextureRect.new()
			img.texture = tex
			img.custom_minimum_size = Vector2(96, 96)
			img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var imgh := HBoxContainer.new()
			imgh.alignment = BoxContainer.ALIGNMENT_CENTER
			imgh.add_child(img)
			vb.add_child(imgh)
	var ds := UIH.label(desc, 14, UIH.DIM)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.custom_minimum_size = Vector2(280, 0)
	ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(ds)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)
	var close := UIH.btn("CLOSE", 130)
	close.custom_minimum_size = Vector2(130, 46)
	close.pressed.connect(func(): _hide_intent_pop())
	row.add_child(close)
	_intent_pop = pop
	add_child(pop)
	pop.popup_centered()


func _check_end() -> void:
	if not bs.battle_over:
		return
	Game.hp = bs.player.hp
	await get_tree().create_timer(0.8).timeout
	if bs.result == "win":
		Sfx.ambience_stop()
		Sfx.play("victory")
		router.show_reward(encounter, bs)
	else:
		Sfx.ambience_stop()
		Sfx.play("defeat")
		router.show_gameover()


# -------------------------------------------------------------- animation ---

func _banner(text: String) -> void:
	_banner_l.text = text
	_banner_l.modulate.a = 1.0
	_banner_bg.modulate.a = 1.0
	_banner_l.scale = Vector2(0.8, 0.8)
	_banner_l.pivot_offset = Vector2(300, 40)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_banner_l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.2)
	tw.chain().tween_property(_banner_l, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(_banner_bg, "modulate:a", 0.0, 0.4)


func _float_text(pos: Vector2, text: String, color: Color, big := false, pop := false) -> void:
	var l := UIH.label(text, 36 if big else 24, color)
	l.add_theme_font_override("font", UIH.font_bold())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(240, 56)
	l.size = Vector2(240, 56)
	l.pivot_offset = Vector2(120, 28)
	l.position = pos - Vector2(120, 28) + Vector2(randf_range(-16, 16), 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_layer.add_child(l)
	var tw := create_tween()
	if pop:
		l.scale = Vector2(1.8, 1.8)
		tw.tween_property(l, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 70, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9)
	tw.chain().tween_callback(l.queue_free)


func _pulse(node: Control, amt: float = 1.3) -> void:
	if node == null:
		return
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(amt, amt), 0.12)
	tw.tween_property(node, "scale", Vector2.ONE, 0.18)


func _shake(node: Control, strength: float = 8.0) -> void:
	var home: Vector2 = node.get_meta("home") if node.has_meta("home") else node.position
	node.set_meta("home", home)
	var tw := create_tween()
	for i in range(4):
		tw.tween_property(node, "position", home + Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), 0.05)
	tw.tween_property(node, "position", home, 0.05)


func _flash(node: Control, color: Color) -> void:
	var tw := create_tween()
	tw.tween_property(node, "modulate", color, 0.08)
	tw.tween_property(node, "modulate", Color.WHITE, 0.25)


func _enemy_center(i: int = -1) -> Vector2:
	# Center of enemy i's sprite; default = current target.
	var idx := bs.target_idx if (i < 0 and bs != null) else i
	if idx >= 0 and idx < _enemy_sprites.size():
		var sp: Control = _enemy_sprites[idx]
		if sp and is_instance_valid(sp):
			return sp.get_global_rect().get_center()
	return Vector2(1120, 220)


func _player_center() -> Vector2:
	if _player_sprite and is_instance_valid(_player_sprite):
		return _player_sprite.get_global_rect().get_center()
	return Vector2(580, 310)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


# ----------------------------------------------------------------- juice ---

var _dot_tex_cache: Texture2D = null
var _ring_tex_cache: Texture2D = null
var _moon_tex_cache: Texture2D = null


func _dot_tex() -> Texture2D:
	if _dot_tex_cache:
		return _dot_tex_cache
	var s := 24
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in range(s):
		for x in range(s):
			var d := Vector2(x - s / 2.0 + 0.5, y - s / 2.0 + 0.5).length() / (s / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_dot_tex_cache = ImageTexture.create_from_image(img)
	return _dot_tex_cache


## One-shot particle burst at a canvas position.
func _burst(pos: Vector2, color: Color, count: int = 20, speed: float = 280.0) -> void:
	var p := CPUParticles2D.new()
	p.texture = _dot_tex()
	p.amount = count
	p.one_shot = true
	p.explosiveness = 0.92
	p.lifetime = 0.65
	p.position = pos
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 620)
	p.damping_min = 40.0
	p.damping_max = 120.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	p.color = color
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 14.0
	_float_layer.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.4).timeout.connect(func(): if is_instance_valid(p): p.queue_free())


func _ring_tex() -> Texture2D:
	if _ring_tex_cache:
		return _ring_tex_cache
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in range(s):
		for x in range(s):
			var d := Vector2(x - s / 2.0, y - s / 2.0).length() / (s / 2.0)
			var band := 1.0 - clampf(absf(d - 0.78) / 0.10, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, band))
	_ring_tex_cache = ImageTexture.create_from_image(img)
	return _ring_tex_cache


## Expanding shield ring around a point.
func _ring(pos: Vector2, radius: float, color: Color) -> void:
	var t := TextureRect.new()
	t.texture = _ring_tex()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	var d := radius * 2.0
	t.custom_minimum_size = Vector2(d, d)
	t.size = Vector2(d, d)
	t.pivot_offset = Vector2(d, d) * 0.5
	t.position = pos - t.pivot_offset
	t.modulate = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_layer.add_child(t)
	var tw := t.create_tween().set_parallel(true)
	tw.tween_property(t, "scale", Vector2(1.35, 1.35), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(t, "modulate:a", 0.0, 0.55)
	tw.chain().tween_callback(t.queue_free)


## Stream of dots from one point to another (LULL).
func _stream(from_pos: Vector2, to_pos: Vector2, color: Color, count: int = 10) -> void:
	for i in range(count):
		var t := TextureRect.new()
		t.texture = _dot_tex()
		t.custom_minimum_size = Vector2(10, 10)
		t.size = Vector2(10, 10)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.modulate = color
		t.position = from_pos
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_float_layer.add_child(t)
		var tw := t.create_tween()
		tw.tween_interval(i * 0.05)
		tw.tween_property(t, "position", to_pos + Vector2(randf_range(-24, 24), randf_range(-24, 24)), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(t, "modulate:a", 0.0, 0.45)
		tw.tween_callback(t.queue_free)


func _moon_tex() -> Texture2D:
	if _moon_tex_cache:
		return _moon_tex_cache
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in range(s):
		for x in range(s):
			var p := Vector2(x, y)
			var in_big: bool = p.distance_to(Vector2(s * 0.5, s * 0.5)) < s * 0.38
			var in_cut: bool = p.distance_to(Vector2(s * 0.62, s * 0.42)) < s * 0.32
			img.set_pixel(x, y, Color(1, 1, 1, 1.0 if (in_big and not in_cut) else 0.0))
	_moon_tex_cache = ImageTexture.create_from_image(img)
	return _moon_tex_cache


## Crescent-moon marker floating above a head (LULL).
func _moon_mark(at: Vector2, size := 44.0) -> void:
	var t := TextureRect.new()
	t.texture = _moon_tex()
	t.custom_minimum_size = Vector2(size, size)
	t.size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.modulate = Color("7b5fb5")
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head: Vector2 = at + Vector2(0, -130)
	t.position = head
	_float_layer.add_child(t)
	var tw := t.create_tween().set_parallel(true)
	tw.tween_property(t, "position:y", head.y - 46, 1.3)
	tw.tween_property(t, "modulate:a", 0.0, 1.3)
	tw.chain().tween_callback(t.queue_free)


var _slash_tex_cache: Texture2D = null
var _shield_tex_cache: Texture2D = null


## Big crescent swoosh used for slash arcs.
func _slash_tex() -> Texture2D:
	if _slash_tex_cache:
		return _slash_tex_cache
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := Vector2(s * 0.5, s * 0.5)
	for y in range(s):
		for x in range(s):
			var p := Vector2(x, y) - c
			var r := p.length() / (s * 0.5)
			var ang := rad_to_deg(atan2(p.y, p.x))
			var ad := absf(wrapf(ang - 25.0, -180.0, 180.0))
			var rband := 1.0 - clampf(absf(r - 0.74) / 0.24, 0.0, 1.0)
			var aband := 1.0 - clampf(ad / 75.0, 0.0, 1.0)
			var a := rband * aband * aband
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_slash_tex_cache = ImageTexture.create_from_image(img)
	return _slash_tex_cache


## Heater-shield shape for the REST shield wall.
func _shield_tex() -> Texture2D:
	if _shield_tex_cache:
		return _shield_tex_cache
	var w := 96
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var poly := PackedVector2Array([
		Vector2(10, 6), Vector2(86, 6), Vector2(86, 62),
		Vector2(48, 122), Vector2(10, 62)])
	var boss := Vector2(48, 50)
	for y in range(h):
		for x in range(w):
			var p := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(p, poly):
				var shade := 1.0 - float(y) / float(h) * 0.22
				var col := Color(shade, shade, shade, 0.94)
				if p.distance_to(boss) < 13.0:
					col = Color(1.0, 1.0, 1.0, 0.98)
				img.set_pixel(x, y, col)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	_shield_tex_cache = ImageTexture.create_from_image(img)
	return _shield_tex_cache


## Big slash arc sweeping across a point (attacks).
func _slash_arc(at: Vector2, color: Color, size := 300.0, dur := 0.3, flip := false) -> void:
	var t := TextureRect.new()
	t.texture = _slash_tex()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.custom_minimum_size = Vector2(size, size)
	t.size = Vector2(size, size)
	t.pivot_offset = Vector2(size, size) * 0.5
	t.position = at - t.pivot_offset
	t.modulate = color
	t.rotation = 0.5 if flip else -0.5
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_layer.add_child(t)
	var tw := t.create_tween().set_parallel(true)
	tw.tween_property(t, "rotation", -0.55 if flip else 0.55, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(t, "scale", Vector2(1.18, 1.18), dur)
	tw.tween_property(t, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(t.queue_free)


## Wall of shields rising in front of a point (REST guard). Holds, then fades.
func _shield_wall(at: Vector2, color: Color, dur := 1.4) -> void:
	# Elegant shield: layered translucent arcs forming a dome, not 3 panels.
	# Draws a glowing dome that rises and settles.
	var dome := Control.new()
	dome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_layer.add_child(dome)
	dome.position = at - Vector2(90, 130)
	dome.size = Vector2(180, 140)
	# custom draw via a script-less approach: use ColorRect layers with radial feel
	# Outer glow ring
	for k in range(3):
		var ring := ColorRect.new()
		var sz := 150.0 - float(k) * 28.0
		ring.color = Color(color.r, color.g, color.b, 0.18 + float(k) * 0.12)
		ring.position = Vector2((180 - sz) * 0.5, (140 - sz) * 0.5 + 20)
		ring.size = Vector2(sz, sz)
		ring.pivot_offset = Vector2(sz, sz) * 0.5
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dome.add_child(ring)
		# scale-in with back ease
		ring.scale = Vector2(0.3, 0.3)
		ring.modulate.a = 0.0
		var tw := ring.create_tween()
		tw.set_parallel(true)
		tw.tween_property(ring, "scale", Vector2.ONE, 0.3 + float(k) * 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(ring, "modulate:a", 1.0, 0.25)
	# shield icon in center
	var icon := Label.new()
	icon.text = "🛡️"
	icon.add_theme_font_size_override("font_size", 48)
	icon.position = Vector2(66, 46)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dome.add_child(icon)
	icon.scale = Vector2(0.3, 0.3)
	icon.pivot_offset = Vector2(24, 24)
	icon.modulate.a = 0.0
	var itw := icon.create_tween()
	itw.set_parallel(true)
	itw.tween_property(icon, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	itw.tween_property(icon, "modulate:a", 1.0, 0.3)
	# clang shockwave + gentle rise
	_ring(at, 70.0, Color(1, 1, 1, 0.9))
	_ring(at, 110.0, Color(color.r, color.g, color.b, 0.7))
	var rise := dome.create_tween()
	rise.tween_property(dome, "position:y", dome.position.y - 12.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(dur).timeout.connect(_fade_out_shield.bind(dome))


## Fade out + free a shield wall panel (timer callback for _shield_wall).
func _fade_out_shield(t: Control) -> void:
	if not is_instance_valid(t):
		return
	var tw := t.create_tween()
	tw.tween_property(t, "modulate:a", 0.0, 0.4)
	tw.tween_callback(t.queue_free)


## Soft radial glow (DREAM heal light).
func _glow(at: Vector2, color: Color, size := 420.0, dur := 1.2) -> void:
	var t := TextureRect.new()
	t.texture = _dot_tex()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.custom_minimum_size = Vector2(size, size)
	t.size = Vector2(size, size)
	t.pivot_offset = Vector2(size, size) * 0.5
	t.position = at - t.pivot_offset
	t.modulate = Color(color.r, color.g, color.b, 0.0)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_layer.add_child(t)
	var tw := t.create_tween()
	tw.tween_property(t, "modulate:a", 0.5, 0.3)
	tw.tween_property(t, "modulate:a", 0.0, dur - 0.3)
	tw.tween_callback(t.queue_free)


## Motes drifting upward (DREAM).
func _rise_motes(at: Vector2, color: Color, count := 14) -> void:
	for i in range(count):
		var t := TextureRect.new()
		t.texture = _dot_tex()
		t.custom_minimum_size = Vector2(9, 9)
		t.size = Vector2(9, 9)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.modulate = color
		var start := at + Vector2(randf_range(-70, 70), randf_range(-20, 40))
		t.position = start
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_float_layer.add_child(t)
		var tw := t.create_tween()
		tw.set_parallel(true)
		tw.tween_property(t, "position:y", start.y - randf_range(90, 150), randf_range(0.7, 1.1)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(t, "modulate:a", 0.0, 1.0)
		tw.chain().tween_callback(t.queue_free)


## Impact freeze-frame: everything holds for a beat on hit.
func _hit_stop(dur := 0.08) -> void:
	Engine.time_scale = 0.06
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0


func _bez(a: Vector2, c: Vector2, b: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * a + 2.0 * u * t * c + t * t * b


## Flies a card widget along an arc so its CENTER travels the bezier.
func _fly_card_to(flyer: Control, target_c: Vector2, end_scale: float, dur: float, arc_h: float = 150.0, fade: bool = false) -> void:
	var half := Vector2(CardWidget.CARD_W, CardWidget.CARD_H) * 0.5
	var from_c: Vector2 = flyer.position + half * flyer.scale
	var ctrl := (from_c + target_c) * 0.5 + Vector2(0, -arc_h)
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(t: float): flyer.position = _bez(from_c, ctrl, target_c, t) - half * flyer.scale, 0.0, 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(flyer, "scale", Vector2(end_scale, end_scale), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if fade:
		tw.tween_property(flyer, "modulate:a", 0.0, dur)
	await tw.finished


func _knockback(node: Control, dist: float) -> void:
	var home: Vector2 = node.get_meta("home") if node.has_meta("home") else node.position
	node.set_meta("home", home)
	var tw := create_tween()
	tw.tween_property(node, "position:x", home.x + dist, 0.08)
	tw.tween_property(node, "position:x", home.x, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## v5.2: death animation — the sprite tips over and fades out over ~0.5s,
## then the sprite and all its UI (HP strip, name plaque, chips, intents,
## target ring) are hidden. Dead enemies no longer linger on stage.
func _play_death_anim(i: int) -> void:
	if i < 0 or i >= _enemy_sprites.size():
		return
	var sp: Control = _enemy_sprites[i]
	if not is_instance_valid(sp):
		return
	# stop the idle bob so it doesn't fight the death tween
	if i < _enemy_bob_tweens.size():
		var btw: Tween = _enemy_bob_tweens[i]
		if btw and is_instance_valid(btw):
			btw.kill()
		_enemy_bob_tweens[i] = null
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sp, "rotation", 1.35, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(sp, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(sp, "position:y", sp.position.y + 26.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	if not is_instance_valid(sp):
		return
	sp.visible = false
	_hide_enemy_ui(i)


## v5.2: hide every UI element tied to a dead enemy.
func _hide_enemy_ui(i: int) -> void:
	if i < _enemy_strips.size() and is_instance_valid(_enemy_strips[i]):
		(_enemy_strips[i] as Control).visible = false
	if i < _enemy_plaques.size() and is_instance_valid(_enemy_plaques[i]):
		(_enemy_plaques[i] as Control).visible = false
	if i < _enemy_chips.size() and is_instance_valid(_enemy_chips[i]):
		(_enemy_chips[i] as Control).visible = false
	if i < _intent_boxes.size() and is_instance_valid(_intent_boxes[i]):
		(_intent_boxes[i] as Control).visible = false
	if i < _target_rings.size() and is_instance_valid(_target_rings[i]):
		(_target_rings[i] as Control).visible = false


func _animate_card_events(events: Array, card: Dictionary, from_pos: Vector2, armor_before: int) -> void:
	var ctype := ""
	for e in events:
		if e["k"] == "card":
			ctype = e["ctype"]
	# flying card clone: arcs to center stage and grows (Slay-the-Spire style)
	var flyer := CardWidget.new(card, null)
	flyer.inspect_only = true
	flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_layer.add_child(flyer)
	flyer.position = from_pos - Vector2(CardWidget.CARD_W, CardWidget.CARD_H) * 0.5
	_pulse(_note_energy)
	await _fly_card_to(flyer, Vector2(_vsz().x * 0.5, 330), 1.5, 0.38)
	await _wait(0.45)
	# attack strike visuals (aimed at the selected target)
	var tgt := bs.target_idx
	match ctype:
		"ATTACK":
			# Bearer dashes CLOSE to the enemy: slash pose, big arc sweep,
			# hit-stop on impact, enemy hurt pose + stronger knockback.
			_stop_idle_bob()
			_set_player_pose("slash")
			_player_sprite.z_index = 5
			var din := create_tween()
			din.tween_property(_player_sprite, "position:x", _player_home.x + 260.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			await _fly_card_to(flyer, _enemy_center(tgt) + Vector2(-120, -60), 1.1, 0.22, 60.0)
			# NOTE: do NOT `await din.finished` here — the 0.18s dash always
			# finishes during the 0.22s card flight, and awaiting an
			# already-finished tween hangs forever on Godot 4.7.
			_slash_arc(_enemy_center(tgt), Color(1, 1, 1, 0.95), 330.0, 0.28)
			_slash_arc(_enemy_center(tgt), UIH.RED, 250.0, 0.34, true)
			Sfx.play("strike")
			await _hit_stop(0.09)
			_set_enemy_pose(tgt, "hurt")
			Sfx.play("enemy_hit")
			_sync_hp()  # enemy HP drops as the slash lands
			_flash(_enemy_sprites[tgt], Color(1, 1, 1))
			_burst(_enemy_center(tgt), Color(1, 1, 1, 0.95), 22, 340.0)
			_burst(_enemy_center(tgt), UIH.RED, 18, 260.0)
			_shake(self, 14.0)
			_knockback(_enemy_sprites[tgt], 42.0)
			await _wait(0.28)  # enemy holds the hurt pose
			_set_enemy_pose(tgt, "idle")
			var dout := create_tween()
			dout.tween_property(_player_sprite, "position:x", _player_home.x, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			await dout.finished  # safe: just created, 0.28s
			_player_sprite.z_index = 0
			_set_player_pose("guard")
			_start_idle_bob()
		"DEFENSE":
			# Bearer takes a guard stance: shield wall rises, clang shockwave.
			_stop_idle_bob()
			_set_player_pose("guard")
			_shield_wall(_player_center() + Vector2(95, 10), Color("4a7fb5"), 1.4)
			Sfx.play("guard")
			_ring(_player_center(), 130.0, Color("4a7fb5"))
			_burst(_player_center(), Color("4a7fb5"), 14, 200.0)
			_flash(_player_sprite, Color("4a7fb5"))
			await _wait(0.7)  # let the shield wall + clang read
			_start_idle_bob()
		"CONTROL":
			# Bearer casts: purple moon-motes stream to the enemy, big moon mark.
			_stop_idle_bob()
			_set_player_pose("cast")
			Sfx.play("bind")
			_stream(_player_center(), _enemy_center(tgt), Color("7b5fb5"), 14)
			await _wait(0.55)
			_moon_mark(_enemy_center(tgt), 78.0)
			_flash(_enemy_sprites[tgt], Color("7b5fb5"))
			await _wait(0.5)
			_set_player_pose("guard")
			_start_idle_bob()
		"UTILITY":
			# Bearer casts: warm glow, rising motes, healing light.
			_stop_idle_bob()
			_set_player_pose("cast")
			Sfx.play("mend")
			_glow(_player_center(), Color("e8c96a"), 460.0, 1.3)
			_rise_motes(_player_center(), Color("e8c96a"), 16)
			_burst(_player_center(), Color("e8c96a"), 14, 160.0)
			_flash(_player_sprite, Color("55a65e"))
			await _wait(0.9)
			_set_player_pose("guard")
			_start_idle_bob()
	# resolve numbers with pops
	for e in events:
		match e["k"]:
			"dmg_e":
				var dei := int(e.get("target", tgt))
				# enemy hurt: swap to hurt pose, flash red, knock back, recover
				if dei >= 0 and dei < _enemy_sprites.size():
					_set_enemy_pose(dei, "hurt")
					_flash(_enemy_sprites[dei], Color(1, 0.35, 0.35))
					_knockback(_enemy_sprites[dei], 24.0)
					Sfx.play("enemy_hit")
				_float_text(_enemy_center(dei) + Vector2(0, -40), "-%d" % e["n"], UIH.RED, true, true)
				if dei < bs.enemies.size() and bs.enemies[dei].hp <= 0:
					Sfx.play("enemy_death")  # that blow killed it
					_play_death_anim(dei)
				await _wait(0.3)
				if dei >= 0 and dei < _enemy_sprites.size() and dei < bs.enemies.size() and bs.enemies[dei].hp > 0:
					_set_enemy_pose(dei, "idle")
			"dmg_p":
				_float_text(_player_center() + Vector2(0, -40), "-%d" % e["n"], UIH.RED, true, true)
				await _wait(0.3)
			"heal_p":
				_float_text(_player_center() + Vector2(0, -40), "+%d" % e["n"], UIH.GREEN, true, true)
				await _wait(0.25)
			"heal_e":
				_float_text(_enemy_center(int(e.get("target", tgt))) + Vector2(0, -40), "+%d" % e["n"], UIH.GREEN, true, true)
				await _wait(0.25)
			"weak_e":
				_float_text(_enemy_center(int(e.get("target", tgt))) + Vector2(0, -80), "Weak +%d" % e["n"], Color("7b7f96"), false, true)
				await _wait(0.25)
			"weak_p":
				_float_text(_player_center() + Vector2(0, -40), "Weak +%d" % e["n"], Color("7b7f96"), false, true)
				await _wait(0.25)
			"vulnerable_e":
				_float_text(_enemy_center(int(e.get("target", tgt))) + Vector2(0, -80), "Vulnerable +%d" % e["n"], Color(1.0, 0.55, 0.35), false, true)
				await _wait(0.25)
			"vulnerable_p":
				_float_text(_player_center() + Vector2(0, -40), "Vulnerable +%d" % e["n"], Color(1.0, 0.55, 0.35), false, true)
				await _wait(0.25)
			"chord_note":
				_float_text(_player_center() + Vector2(0, -70), "Note %d" % int(e.get("progress", 0)), UIH.LT_GOLD, false, true)
				await _wait(0.2)
			"chord_snap":
				_float_text(_player_center() + Vector2(0, -70), "STRING SNAPPED!", UIH.STAMP, true, true)
				Sfx.play("player_hit")
				await _wait(0.4)
			"chord_hold":
				_float_text(_player_center() + Vector2(0, -70), "Sturdy Strings holds!", UIH.LT_GREEN, false, true)
				await _wait(0.3)
			"chord_done":
				var _ids: Array = e.get("ids", [])
				var _names := []
				for _cid in _ids:
					_names.append(ChordDB.chord_name(str(_cid)))
				_banner(("%s!" % " + ".join(_names)).to_upper())
				Sfx.play("buff")
				_burst(_player_center(), UIH.LT_GOLD, 18, 260.0)
				await _wait(0.6)
			"power_p":
				_float_text(_player_center() + Vector2(0, -70), "POWER: %s" % CardDB.card_name({"id": str(e.get("id", "")), "upgraded": false}), Color("7b5fb5"), true, true)
				await _wait(0.4)
			"evaded":
				_float_text(_enemy_center(int(e.get("target", tgt))) + Vector2(0, -60), "EVADED!", UIH.LT_DIM, true, true)
				await _wait(0.3)
			"strength_p":
				_float_text(_player_center() + Vector2(0, -40), "Strength +%d! ⚔️" % e["n"], Color(1.0, 0.55, 0.35), true, true)
				_burst(_player_center(), Color(1.0, 0.55, 0.35), 14, 220.0)
				Sfx.play("buff")
				await _wait(0.4)
			"kill_e":
				_set_enemy_pose(int(e.get("target", tgt)), "hurt")
				_float_text(_enemy_center(int(e.get("target", tgt))) + Vector2(0, -60), "DEFEATED", UIH.STAMP, true, true)
				await _wait(0.35)

			"phase2":
				_banner("%s is ENRAGED!" % bs.enemies[0].name)
				await _wait(1.0)
			"end":
				await _wait(0.3)
	# armor gained has no event: pop the delta
	var armor_gain: int = bs.player.armor - armor_before
	if armor_gain > 0:
		_float_text(_player_center() + Vector2(0, -40), "+%d ARMOR" % armor_gain, Color("4a7fb5"), false, true)
		await _wait(0.2)
	# card shrinks away to the discard pile
	var disc_c := _discard_pile.get_global_rect().get_center() if is_instance_valid(_discard_pile) else Vector2(80, 640)
	await _fly_card_to(flyer, disc_c, 0.28, 0.4, 40.0, true)
	flyer.queue_free()


func _animate_enemy_events(events: Array) -> void:
	var bi := {}      # ei -> badge index within that enemy's badge row
	var cur_ei := 0   # enemy currently acting (from the latest e_intent)
	for e in events:
		match e["k"]:
			"e_intent":
				var ei: int = int(e.get("ei", 0))
				cur_ei = ei
				var k: int = int(bi.get(ei, 0))
				if ei < _intent_badges.size() and k < _intent_badges[ei].size():
					var badge: Control = _intent_badges[ei][k]
					_flash(badge, Color("e8e0d0") if not e.get("failed", false) else Color("555560"))
					if e.get("failed", false):
						_float_text(_enemy_center(ei), "FAILED", UIH.LT_DIM)
				bi[ei] = k + 1
				await _wait(0.5)
			"dmg_p":
				# the acting enemy lunges with attack pose, red slash arc into
				# the Bearer, who takes a hurt pose; then both recover.
				var esp: Control = _enemy_sprites[cur_ei]
				var sx: float = esp.position.x
				_set_enemy_pose(cur_ei, "attack")
				var ltw := create_tween()
				ltw.tween_property(esp, "position:x", sx - 110, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				await ltw.finished  # safe: just created, 0.14s
				_slash_arc(_player_center(), Color(1, 0.25, 0.2, 0.95), 300.0, 0.28, true)
				await _hit_stop(0.07)
				_stop_idle_bob()
				_set_player_pose("hurt")
				Sfx.play("player_hit")
				_flash(_player_sprite, Color(1, 0.35, 0.35))
				_burst(_player_center(), UIH.RED, 16, 260.0)
				_shake(self, 10.0)
				_knockback(_player_sprite, -26.0)
				if e.get("armor_broke", false):
					# armor shattered on this hit: light shake on the HP strip
					# (separate node — avoids fighting the main shake tween)
					Sfx.play("armor_break")
					_shake(_player_strip, 6.0)
				_sync_hp()  # HP bar drops NOW, in sync with the slash
				_float_text(_player_center(), "-%d" % e["n"], UIH.RED, true, true)
				await _wait(0.3)  # Bearer holds the hurt pose
				_set_player_pose("guard")
				_start_idle_bob()
				_set_enemy_pose(cur_ei, "idle")
				var back := create_tween()
				back.tween_property(esp, "position:x", sx, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				await back.finished  # safe: just created, 0.24s
				await _wait(0.15)
			"heal_e":
				var hei := int(e.get("ei", cur_ei))
				_float_text(_enemy_center(hei), "+%d" % e["n"], UIH.GREEN)
				_burst(_enemy_center(hei), UIH.GREEN, 12, 180.0)
				_ring(_enemy_center(hei), 60.0, Color(0.4, 0.9, 0.4, 0.7))
				Sfx.play("heal")
				await _wait(0.4)
			"armor_e":
				var aei := int(e.get("ei", cur_ei))
				_shield_wall(_enemy_center(aei), Color(0.5, 0.65, 0.85, 0.9), 0.8)
				_float_text(_enemy_center(aei) + Vector2(0, -40), "+%d ARMOR" % e["n"], Color(0.5, 0.65, 0.85))
				Sfx.play("armor_gain")
				await _wait(0.35)
			"weak_p":
				_float_text(_player_center(), "Weak +%d" % e["n"], Color("7b7f96"))
				Sfx.play("bind")
				await _wait(0.4)
			"vulnerable_p":
				_float_text(_player_center(), "Vulnerable +%d" % e["n"], Color(1.0, 0.55, 0.35))
				Sfx.play("bind")
				await _wait(0.4)
			"steal":
				_float_text(_player_center() + Vector2(0, -70), "STOLEN x%d!" % e["n"], UIH.STAMP, true, true)
				Sfx.play("player_hit")
				await _wait(0.4)
			"evade":
				_float_text(_enemy_center(int(e.get("ei", cur_ei))) + Vector2(0, -60), "EVADE!", UIH.LT_GOLD, true, true)
				await _wait(0.4)
			"strength_e":
				_float_text(_enemy_center(int(e.get("ei", cur_ei))) + Vector2(0, -60), "Strength +%d" % e["n"], Color(1.0, 0.55, 0.35), true, true)
				await _wait(0.3)
			"e_stunned":
				_float_text(_enemy_center(int(e.get("ei", cur_ei))) + Vector2(0, -60), "STUNNED", UIH.LT_GOLD, true, true)
				await _wait(0.4)
			"squeeze":
				_banner("Chan Tinh squeezes tighter!")
				await _wait(0.6)
			"break_formation":
				_banner("BREAK FORMATION!")
				await _wait(0.6)
			"divine_melody":
				_banner("DIVINE MELODY!")
				Sfx.play("heal")
				await _wait(0.8)
			"divine_axe":
				_banner("DIVINE AXE!")
				await _wait(0.6)
			"divine_lute":
				_banner("DIVINE LUTE!")
				await _wait(0.6)
			"phase2":
				_banner("The Keeper stops holding back.")
				await _wait(1.2)
			"end":
				await _wait(0.4)


# ------------------------------------------------- intent inspect popup ---

## Long-press (0.5s) an enemy: paper popup explaining its telegraphed intents
## in plain language. Quick tap still selects the target (see _on_enemy_gui).
func _show_intent_pop(i: int, from_tap: bool = false) -> void:
	_hide_intent_pop()
	if bs == null or i < 0 or i >= bs.enemies.size():
		return
	var f = bs.enemies[i]
	var pop := PopupPanel.new()
	pop.add_theme_stylebox_override("panel", UIH.paper_style(UIH.INK, 2, 3))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	pop.add_child(vb)
	vb.add_child(UIH.header("INTENT — " + str(f.name).to_upper(), UIH.STAMP, 15))
	var hp_l := UIH.label("HP %d / %d" % [f.hp, f.max_hp], 13, UIH.DIM)
	vb.add_child(hp_l)
	var intents: Array = bs.intent_summary_for(i)
	if intents.is_empty():
		vb.add_child(UIH.label("No intents telegraphed.", 13, UIH.DIM))
	for it in intents:
		var kind: String = it["kind"]
		var line := ""
		match kind:
			"attack":
				line = "Deal %d damage to you." % _final_intent_dmg(it)
			"defend":
				line = "Gain %d Armor." % it["power"]
			"debuff":
				line = "Apply %d Drowsy to you." % it["power"]
			"heal":
				line = "Heal %d HP." % it["power"]
			_:
				line = "%s %d." % [kind, it["power"]]
		var status := ""
		if it.get("muddled", false):
			status = "  —  Muddled: weakened."
		var col: Color = CardDB.TYPE_COLORS.get(UIH.KIND_TO_CTYPE.get(kind, "ATTACK"), UIH.DIM).darkened(0.25)
		var l := UIH.label("• " + line + status, 14, col)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(320, 0)
		vb.add_child(l)
	var hint := UIH.label("Release to dismiss. Tap an enemy to target it.", 11, UIH.DIM)
	if from_tap:
		hint.text = "Tap CLOSE to dismiss."
	var ccb := UIH.btn("CLOSE", 120)
	ccb.pressed.connect(func(): _hide_intent_pop())
	var ccc := HBoxContainer.new()
	ccc.alignment = BoxContainer.ALIGNMENT_CENTER
	ccc.add_child(ccb)
	if from_tap:
		vb.add_child(ccc)
	vb.add_child(hint)
	add_child(pop)
	# anchor near the enemy, clamped inside the viewport
	var ep := _enemy_center(i)
	var px: float = clampf(ep.x - 180.0, 8.0, _vsz().x - 380.0)
	var py: float = clampf(ep.y - 120.0, 8.0, _vsz().y - 260.0)
	if from_tap:
		pop.popup_centered()
	else:
		pop.position = Vector2(px, py)
		pop.popup()
	_intent_pop = pop


func _hide_intent_pop() -> void:
	if _intent_pop and is_instance_valid(_intent_pop):
		_intent_pop.hide()
		_intent_pop.queue_free()
	_intent_pop = null


func _show_status_pop(kind: String) -> void:
	_hide_intent_pop()
	# kind: "weak"/"weak_p"/"weak_e", "vulnerable"/..., "armor", "strength"
	var pop := PopupPanel.new()
	pop.add_theme_stylebox_override("panel", UIH.paper_style(UIH.INK, 2, 3))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	pop.add_child(vb)
	var title := "WEAK"
	var desc := "Deals 25% less attack damage. Loses 1 each turn."
	if kind == "weak_p":
		title = "WEAK (YOU)"
		desc = "Your attacks deal 25% less damage.\nLoses 1 at the end of your turn."
	elif kind == "weak_e" or kind == "weak":
		title = "WEAK (ENEMY)"
		desc = "Its attacks deal 25% less damage.\nLoses 1 at the end of its turn."
	elif kind == "vulnerable_p":
		title = "VULNERABLE (YOU)"
		desc = "You take +50% damage from attacks.\nLoses 1 at the end of your turn."
	elif kind == "vulnerable_e" or kind == "vulnerable":
		title = "VULNERABLE (ENEMY)"
		desc = "It takes +50% damage from attacks.\nLoses 1 at the end of its turn."
	if kind == "armor":
		title = "ARMOR"
		desc = "Absorbs damage first. Removed at the start of each turn."
	elif kind == "strength":
		title = "STRENGTH"
		desc = "+1 damage on every attack. Lasts the whole battle."

	vb.add_child(UIH.header(title, UIH.STAMP, 15))
	var ds := UIH.label(desc, 13, UIH.DIM)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.custom_minimum_size = Vector2(280, 0)
	vb.add_child(ds)
	var cb := UIH.btn("CLOSE", 120)
	cb.pressed.connect(func(): _hide_intent_pop())
	var cc := HBoxContainer.new()
	cc.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(cb)
	vb.add_child(cc)
	add_child(pop)
	_intent_pop = pop
	pop.popup_centered()
