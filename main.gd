extends Control
## Screen router. Owns the current full-screen Control.

var current: Control = null
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = int(Time.get_unix_time_from_system()) % 1000000
	if rng.seed == 0:
		rng.seed = 999
	if "--shotdemo" in OS.get_cmdline_args() or "--shotdemo" in OS.get_cmdline_user_args():
		_shotdemo()
	else:
		show_title()


# --- Debug auto-demo: walks through screens and saves viewport screenshots.
# Only active with the --shotdemo CLI flag. Used for headless UI verification.
var _shot_i := 0


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png("/tmp/shots/%02d_%s.png" % [_shot_i, name])
	_shot_i += 1
	print("SHOT ", name, " err=", err)


func _demo_wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shotdemo() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	Game.set_meta("_tutorial_done", false)  # show tutorial for screenshots
	show_title()
	await _demo_wait(1.2)
	await _shot("title")
	show_equipment()
	await _demo_wait(1.0)
	await _shot("equipment")
	(current as EquipmentScreen)._choose("divine_axe")
	await _demo_wait(1.2)
	await _shot("map")  # KEY: map / stage select
	# Travel to the first available battle node and start the fight.
	# v5.0: random map — find first AVAILABLE battle node dynamically.
	var first_battle := ""
	for oid in (Game.map_graph.get_node("start") as Dictionary).get("out", []):
		var on: Dictionary = Game.map_graph.get_node(str(oid))
		if str(on.get("type", "")) == "BATTLE":
			first_battle = str(oid)
			break
	if first_battle == "":
		first_battle = str((Game.map_graph.get_node("start") as Dictionary).get("out", [])[0])
	Game.map_graph.travel_to(first_battle)
	var node: Dictionary = Game.map_graph.get_node(first_battle)
	Game.act = int(node.get("act", 1))
	show_battle(Game.resolve_encounter(node, rng))
	await _demo_wait(2.5)
	await _shot("tutorial")
	var b = current
	if b.get("_tutorial") and is_instance_valid(b.get("_tutorial")):
		b.get("_tutorial")._finish()
	await _demo_wait(0.5)
	# v3.8: chords auto-detect — just play two attacks via the real UI taps.
	var played := 0
	var guard := 0
	while played < 2 and guard < 6:
		guard += 1
		var target = null
		for ch in b._hand_box.get_children():
			if is_instance_valid(ch) and ch.playable and str(CardDB.get_def(str(ch.card.get("id", ""))).get("ctype", "")) == "ATTACK":
				target = ch
				break
		if target == null:
			break
		b._on_card_clicked(target)  # tap 1: arm
		if is_instance_valid(target):
			b._on_card_clicked(target)  # tap 2: confirm/play
		played += 1
		var wt := 0
		while b.busy and wt < 40:
			await _demo_wait(0.2)
			wt += 1
	await _demo_wait(1.5)
	await _shot("battle")  # KEY: gameplay
	b._on_end_turn()
	var wt2 := 0
	while b.busy and wt2 < 60:
		await _demo_wait(0.3)
		wt2 += 1
	await _shot("battle_enemyturn")
	print("SHOTDEMO DONE")
	get_tree().quit()


func _swap(s: Control) -> void:
	if current:
		current.queue_free()
	current = s
	if "router" in s:
		s.router = self
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(s)


func _bg(color: Color) -> ColorRect:
	var c := ColorRect.new()
	c.color = color
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c


func show_title() -> void:
	_swap(TitleScreen.new())


func show_hero_select() -> void:
	_swap(HeroSelectScreen.new())


func show_collection() -> void:
	_swap(CollectionScreen.new())


func show_equipment() -> void:
	_swap(EquipmentScreen.new())


func show_map() -> void:
	# v5.0: beating an act boss advances to the next act (fresh random map).
	if Game.is_run_complete():
		if Game.act < 3:
			Game.advance_act(rng)
		else:
			show_victory()
			return
	Sfx.ambience("sleepless_city_loop")
	_swap(MapScreen.new())


func show_battle(p_encounter) -> void:
	Sfx.ambience("battle_loop")
	_swap(BattleScreen.new(p_encounter))


func show_reward(p_encounter, bs: BattleState) -> void:
	var enc: Array = p_encounter if p_encounter is Array else [{"id": p_encounter, "hp_mult": 1.0}]
	# v5.0: final boss (act 3 Dai Bang) skips reward -> victory.
	# Act 1/2 bosses go through the normal reward screen.
	if Game.act >= 3 and enc.size() == 1 and str(enc[0].get("id", "")) == "dai_bang":
		show_victory()
		return
	_swap(RewardScreen.new(enc, bs))


func show_event() -> void:
	_swap(EventScreen.new())


func show_shop() -> void:
	_swap(ShopScreen.new())


func show_clinic() -> void:
	_swap(ClinicScreen.new())


func show_rest() -> void:
	_swap(ClinicScreen.new())


func show_treasure() -> void:
	_swap(TreasureScreen.new())


func show_victory() -> void:
	_swap(EndScreen.new(true))


func show_gameover() -> void:
	_swap(EndScreen.new(false))


func enter_current_node() -> void:
	var node: Dictionary = Game.current_node()
	var t: String = node.get("type", "")
	match t:
		"BATTLE", "ELITE", "BOSS":
			show_battle(Game.resolve_encounter(node, rng))
		"EVENT":
			show_event()
		"SHOP":
			show_shop()
		"REST":
			show_rest()
		"TREASURE":
			show_treasure()
		_:
			show_map()

