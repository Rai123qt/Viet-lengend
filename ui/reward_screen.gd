class_name RewardScreen
extends Control
## Post-battle rewards: gold, card choice, elite relic, chord learning, EXP/level-up.

var router = null
var encounter: Array = []
var bs: BattleState = null

var _step := 0
var _leveled := false
var _box: VBoxContainer


func _init(p_encounter: Array = [], p_bs: BattleState = null) -> void:
	encounter = p_encounter
	bs = p_bs


func _ready() -> void:
	add_child(UIH.screen_bg("res://assets/art/vl/bg_forest.png"))
	# v5.7.2: dark backdrop behind content (Rai: text hard to read)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 14)
	add_child(_box)

	var kind := "normal"
	var exp := 0
	for e in encounter:
		var d := EnemyDB.get_def(str(e.get("id", "")))
		if d.get("kind", "") == "elite":
			kind = "elite"
		elif d.get("kind", "") == "boss":
			kind = "boss"
		exp += int(round(float(d.get("exp", 20)) * float(e.get("hp_mult", 1.0))))
	var gold := 80 if kind == "elite" else (150 if kind == "boss" else 30)
	Game.add_gold(gold)
	if Game.has_relic("lucky_coin"):
		Game.add_gold(25)
	_leveled = Game.add_exp(exp)
	var relic_txt := ""
	if kind == "elite":
		var rid := _random_relic()
		if rid != "":
			Game.add_relic(rid)
			relic_txt = "\nRelic gained: %s" % GameState.RELICS[rid]["name"]
		else:
			Game.add_gold(100)
			relic_txt = "\n(All relics owned: +100g instead)"
	var item_txt := ""
	if router.rng.randf() < 0.35 and Game.has_item_space():
		var ipool := GameState.ITEMS.keys()
		var iid: String = ipool[router.rng.randi_range(0, ipool.size() - 1)]
		if Game.add_item(iid):
			item_txt = "\nItem found: %s" % GameState.ITEMS[iid]["name"]
	# Elite: 35% to learn a random chord.
	var chord_txt := ""
	if kind == "elite" and router.rng.randf() < 0.35:
		var pool := ChordDB.learnable_pool(Game.chords, 4)
		if not pool.is_empty():
			var cid: String = pool[router.rng.randi_range(0, pool.size() - 1)]
			if Game.learn_chord(cid):
				chord_txt = "\nChord learned: %s!" % ChordDB.chord_name(cid)

	_box.add_child(UIH.title("VICTORY", 44))
	var s := UIH.label("+%d gold   +%d EXP%s%s%s" % [gold, exp, relic_txt, item_txt, chord_txt], 18, UIH.LT_TEAL)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(s)
	# Mid-boss (Chan Tinh): choose 1 of 3 chords.
	if _is_mid_boss():
		_show_chord_choice()
	elif _is_boss():
		_show_legendary_choice()
	else:
		_show_card_choice()


func _is_mid_boss() -> bool:
	return encounter.size() == 1 and str(encounter[0].get("id", "")) == "chan_tinh"


func _is_boss() -> bool:
	if encounter.is_empty():
		return false
	var eid := str(encounter[0].get("id", ""))
	return eid in ["chan_tinh", "dai_bang", "dai_bang_final", "thuy_tinh"]


func _show_legendary_choice() -> void:
	var l := UIH.label("LEGENDARY! Choose 1 of 3:", 20, Color("e74c3c"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(l)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	_box.add_child(hb)
	var pool := CardDB.cards_of_rarity_for_hero("legendary", Game.hero_id)
	pool.shuffle()
	var ids := pool.slice(0, 3)
	for id in ids:
		var w := CardWidget.new(CardDB.make(id), null)
		var cid: String = id
		w.clicked.connect(func(_ww): Game.add_card(cid); _after_card())
		hb.add_child(w)
	var skip := UIH.btn("Skip", 200)
	skip.pressed.connect(_after_card)
	var hc := HBoxContainer.new()
	hc.alignment = BoxContainer.ALIGNMENT_CENTER
	hc.add_child(skip)
	_box.add_child(hc)


func _random_relic() -> String:
	var pool := []
	for rid in GameState.RELICS.keys():
		if not Game.has_relic(rid):
			pool.append(rid)
	if pool.is_empty():
		return ""
	return pool[router.rng.randi_range(0, pool.size() - 1)]


func _show_chord_choice() -> void:
	var l := UIH.label("The Python Demon falls. Choose a chord to learn:", 18, UIH.LT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(l)
	var pool := ChordDB.learnable_pool(Game.chords, 4)
	pool.shuffle()
	var ids: Array = pool.slice(0, mini(3, pool.size()))
	if ids.is_empty():
		_box.add_child(UIH.label("(No new chords to learn.)", 14, UIH.LT_DIM))
		_after_chord()
		return
	for cid in ids:
		var b := UIH.btn("[%s] %s\n%s" % [ChordDB.seq_text(cid), ChordDB.chord_name(cid),
			str(ChordDB.get_def(cid).get("text", ""))], 560)
		b.custom_minimum_size = Vector2(560, 72)
		var cc: String = cid
		b.pressed.connect(func(): Game.learn_chord(cc); _after_chord())
		var hc := HBoxContainer.new()
		hc.alignment = BoxContainer.ALIGNMENT_CENTER
		hc.add_child(b)
		_box.add_child(hc)


func _after_chord() -> void:
	for ch in _box.get_children():
		ch.queue_free()
	# v3.4: Boss reward also includes a Divine Artifact choice.
	if _is_mid_boss() or _is_final_boss():
		_show_artifact_choice()
	else:
		_show_card_choice()


func _is_final_boss() -> bool:
	return encounter.size() == 1 and str(encounter[0].get("id", "")) == "dai_bang_tinh"


## v3.4: Choose 1 of 3 Divine Artifacts (new replaces old).
func _show_artifact_choice() -> void:
	var l := UIH.label("A Divine Artifact glimmers. Choose one (replaces your current):", 18, UIH.LT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(l)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 16)
	_box.add_child(hb)
	for eid in GameState.EQUIPMENT.keys():
		var edef: Dictionary = GameState.EQUIPMENT[eid]
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		cell.custom_minimum_size = Vector2(220, 0)
		var icon_path := str(edef.get("icon", ""))
		if icon_path != "":
			var tex := UIH.try_tex(icon_path)
			if tex != null:
				var img := TextureRect.new()
				img.texture = tex
				img.custom_minimum_size = Vector2(90, 90)
				img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				img.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var imgh := HBoxContainer.new()
				imgh.alignment = BoxContainer.ALIGNMENT_CENTER
				imgh.add_child(img)
				cell.add_child(imgh)
		var nm := UIH.label(str(edef["name"]), 16, UIH.LT)
		nm.add_theme_font_override("font", UIH.font_bold())
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(nm)
		var ds := UIH.label(str(edef["desc"]), 12, UIH.LT_DIM)
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(ds)
		var b := UIH.btn("TAKE", 140)
		var aeid: String = eid
		b.pressed.connect(func(): Game.equip(aeid); _after_artifact())
		var bh := HBoxContainer.new()
		bh.alignment = BoxContainer.ALIGNMENT_CENTER
		bh.add_child(b)
		cell.add_child(bh)
		hb.add_child(cell)


func _after_artifact() -> void:
	for ch in _box.get_children():
		ch.queue_free()
	_show_card_choice()


func _show_card_choice() -> void:
	var l := UIH.label("Choose a card (or skip):", 18, UIH.LT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(l)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	_box.add_child(hb)
	var ids := []
	for i in range(3):
		var id := CardDB.random_card_id(router.rng, "", Game.hero_id)
		while id in ids:
			id = CardDB.random_card_id(router.rng, "", Game.hero_id)
		ids.append(id)
	for id in ids:
		var w := CardWidget.new(CardDB.make(id), null)
		var cid: String = id
		w.clicked.connect(func(_ww): Game.add_card(cid); _after_card())
		hb.add_child(w)
	var skip := UIH.btn("Skip", 200)
	skip.pressed.connect(_after_card)
	var hc := HBoxContainer.new()
	hc.alignment = BoxContainer.ALIGNMENT_CENTER
	hc.add_child(skip)
	_box.add_child(hc)


func _after_card() -> void:
	for ch in _box.get_children():
		ch.queue_free()
	if _leveled:
		_show_levelup()
	else:
		_show_continue()


func _show_levelup() -> void:
	_box.add_child(UIH.title("LEVEL UP! (Lv %d)" % Game.level, 32))
	var l := UIH.label("Choose a perk:", 18, UIH.LT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(l)
	var choices: Array = Game.roll_level_choices(router.rng)
	for p in choices:
		var b := UIH.btn("%s — %s" % [p["name"], p["desc"]], 520)
		var pid: String = p["id"]
		b.pressed.connect(func(): Game.apply_perk(pid); _after_perk())
		var hc := HBoxContainer.new()
		hc.alignment = BoxContainer.ALIGNMENT_CENTER
		hc.add_child(b)
		_box.add_child(hc)


func _after_perk() -> void:
	for ch in _box.get_children():
		ch.queue_free()
	_show_continue()


func _show_continue() -> void:
	var b := UIH.btn("CONTINUE", 260)
	b.custom_minimum_size = Vector2(260, 56)
	if _is_boss() or _is_mid_boss():
		b.text = "NEXT ACT"
		b.pressed.connect(func(): Game.advance_act(router.rng); router.show_map())
	else:
		b.pressed.connect(func(): router.show_map())
	var hc := HBoxContainer.new()
	hc.alignment = BoxContainer.ALIGNMENT_CENTER
	hc.add_child(b)
	_box.add_child(hc)
