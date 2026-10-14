class_name EventScreen
extends Control
## Story 1 random events (Vietnamese folktale flavor, English text).

var router = null
var event_id: String = ""
var _box: VBoxContainer


func _ready() -> void:
	var ids := ["woodcutter_hut", "old_master", "village_siege", "forest_shrine", "traveling_merchant", "divine_altar"]
	event_id = ids[router.rng.randi_range(0, ids.size() - 1)]
	add_child(UIH.screen_bg("res://assets/art/vl/bg_forest.png"))
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 14)
	add_child(_box)
	_show()


func _show() -> void:
	for ch in _box.get_children():
		ch.queue_free()
	match event_id:
		"woodcutter_hut":
			_build("The Woodcutter's Hut",
				"An old woodcutter offers you rice and a place by the fire. He hums an old tune...",
				[
					["Share his meal", "Heal 15 HP.",
						func(): Game.heal(15); _done()],
					["Learn his tune", "Learn a random chord. Lose 10 HP (you chop wood for him all day).",
						func(): _learn_chord_cost_hp(10)],
				])
		"old_master":
			_build("The Old Master's Tomb",
				"Moss covers a stone lute. The inscription promises a divine melody to the worthy.",
				[
					["Play the stone lute (100g)", "Learn a rare 5-note chord.",
						func(): _learn_master_chord(100)],
					["Pay respects and leave", "Gain 40 gold (the master's blessing).",
						func(): Game.add_gold(40); _done()],
				])
		"village_siege":
			_build("Village Under Siege",
				"Bandits surround the village! The elder begs for help.",
				[
					["Drive them off", "Lose 12 HP. Gain 100 gold and a card.",
						func(): Game.damage(12); Game.add_gold(100); _supply_cards()],
					["Sneak past", "Nothing happens.",
						func(): _done()],
				])
		"forest_shrine":
			_build("The Forest Shrine",
				"Incense smoke curls around a small shrine. Someone left offerings.",
				[
					["Take the offerings", "+80 gold. Lose 8 HP (the forest spirits are angry).",
						func(): Game.add_gold(80); Game.damage(8); _done()],
					["Leave an offering (30g)", "Heal 20 HP.",
						func(): _offer(30)],
				])
		"traveling_merchant":
			_build("The Traveling Merchant",
				"A merchant with a bamboo backpack sells songbooks from distant villages.",
				[
					["Buy a songbook (175g)", "Learn a random chord.",
						func(): _buy_songbook(175)],
					["Buy supplies (50g)", "Gain a random item.",
						func(): _buy_supplies(50)],
				])
		"divine_altar":
			# v3.4: special event — a Divine Artifact (replaces current).
			_build("The Divine Altar",
				"Lightning split this ancient tree. Inside the hollow, a Divine Artifact glows...",
				[
					["Take the Divine Axe", "Your first Attack each turn deals +6 damage. (Replaces current artifact.)",
						func(): Game.equip("divine_axe"); _done()],
					["Take the Divine Lute", "Completing a chord deals 4 damage to ALL enemies. (Replaces current artifact.)",
						func(): Game.equip("divine_lute"); _done()],
					["Take the Endless Rice Pot", "Heals give +6 HP more. (Replaces current artifact.)",
						func(): Game.equip("endless_rice_pot"); _done()],
					["Leave it", "Nothing happens.",
						func(): _done()],
				])


func _learn_chord_cost_hp(hp_cost: int) -> void:
	var pool := ChordDB.learnable_pool(Game.chords)
	if pool.is_empty():
		_done()
		return
	Game.damage(hp_cost)
	var cid: String = pool[router.rng.randi_range(0, pool.size() - 1)]
	Game.learn_chord(cid)
	_done()


func _learn_master_chord(cost: int) -> void:
	if Game.gold < cost:
		return
	var pool := ChordDB.learnable_pool(Game.chords, 5)
	if pool.is_empty():
		pool = ChordDB.learnable_pool(Game.chords)
	if pool.is_empty():
		_done()
		return
	Game.add_gold(-cost)
	var cid: String = pool[router.rng.randi_range(0, pool.size() - 1)]
	Game.learn_chord(cid)
	_done()


func _offer(cost: int) -> void:
	if Game.gold < cost:
		return
	Game.add_gold(-cost)
	Game.heal(20)
	_done()


func _buy_songbook(cost: int) -> void:
	if Game.gold < cost:
		return
	var pool := ChordDB.learnable_pool(Game.chords)
	if pool.is_empty():
		return
	Game.add_gold(-cost)
	var cid: String = pool[router.rng.randi_range(0, pool.size() - 1)]
	Game.learn_chord(cid)
	_done()


func _buy_supplies(cost: int) -> void:
	if Game.gold < cost or not Game.has_item_space():
		return
	Game.add_gold(-cost)
	var ipool := GameState.ITEMS.keys()
	Game.add_item(ipool[router.rng.randi_range(0, ipool.size() - 1)])
	_done()


func _build(title: String, flavor: String, options: Array) -> void:
	_box.add_child(UIH.title(title, 34))
	var f := UIH.label(flavor, 17, UIH.LT_DIM)
	f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	f.custom_minimum_size = Vector2(700, 60)
	var fc := HBoxContainer.new()
	fc.alignment = BoxContainer.ALIGNMENT_CENTER
	fc.add_child(f)
	_box.add_child(fc)
	for o in options:
		var b := UIH.btn("%s\n%s" % [o[0], o[1]], 560)
		b.custom_minimum_size = Vector2(560, 64)
		var fn: Callable = o[2]
		b.pressed.connect(fn)
		var hc := HBoxContainer.new()
		hc.alignment = BoxContainer.ALIGNMENT_CENTER
		hc.add_child(b)
		_box.add_child(hc)
	var leave := UIH.btn("Leave", 200)
	leave.pressed.connect(_done)
	var lc := HBoxContainer.new()
	lc.alignment = BoxContainer.ALIGNMENT_CENTER
	lc.add_child(leave)
	_box.add_child(lc)


func _supply_cards() -> void:
	var ids := []
	for i in range(3):
		var id := CardDB.random_card_id(router.rng, "", Game.hero_id)
		while id in ids:
			id = CardDB.random_card_id(router.rng, "", Game.hero_id)
		ids.append(id)
	var cards := []
	for id in ids:
		cards.append(CardDB.make(id))
	UIH.choose_card_popup(self, "Choose a card", cards, func(i): if i >= 0: Game.deck.append(cards[i]); _done())


func _done() -> void:
	router.show_map()
