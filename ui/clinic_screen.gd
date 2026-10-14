class_name ClinicScreen
extends Control
## REST node: heal, tune up (upgrade), or meditate (learn chord for HP).

var router = null


func _ready() -> void:
	add_child(UIH.screen_bg("res://assets/art/vl/bg_forest.png"))
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	add_child(vb)
	vb.add_child(UIH.title("MOUNTAIN SPRING", 34))
	var sub := UIH.label("Clear water, quiet pines. Pick one.", 16, UIH.LT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var opts := [
		["Rest", "Heal 50% of max HP.", func(): Game.heal(int(Game.max_hp * 0.5)); _done()],
		["Sharpen the axe", "Upgrade a card.", func(): _upgrade()],
		["Meditate on music", "Learn a random chord. Lose 12 HP.",
			func(): _meditate()],
	]
	for o in opts:
		var b := UIH.btn("%s\n%s" % [o[0], o[1]], 480)
		b.custom_minimum_size = Vector2(480, 64)
		var fn: Callable = o[2]
		b.pressed.connect(fn)
		var hc := HBoxContainer.new()
		hc.alignment = BoxContainer.ALIGNMENT_CENTER
		hc.add_child(b)
		vb.add_child(hc)


func _upgrade() -> void:
	UIH.choose_card_popup(self, "Upgrade a card", Game.deck,
		func(i): if i >= 0: Game.upgrade_card_at(i); _done())


func _meditate() -> void:
	var pool := ChordDB.learnable_pool(Game.chords)
	if pool.is_empty():
		_done()
		return
	Game.damage(12)
	var cid: String = pool[randi() % pool.size()]
	Game.learn_chord(cid)
	_done()


func _done() -> void:
	router.show_map()
