class_name EndScreen
extends Control
## Victory / GameOver screen.

var router = null
var won: bool = true


func _init(p_won: bool = true) -> void:
	won = p_won


func _ready() -> void:
	add_child(UIH.screen_bg("res://assets/art/vl/bg_battle.png"))
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	add_child(vb)
	if won:
		vb.add_child(UIH.title("THE EAGLE FALLS", 54))
		var s := UIH.label("Dai Bang is defeated. The lute's last chord fades over the Green Forest.", 20, UIH.LT_TEAL)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(s)
		var stats := UIH.label("Level %d   Gold %d   Deck: %d cards   Chords: %d" % [
			Game.level, Game.gold, Game.deck.size(), Game.chords.size()], 16, UIH.LT_DIM)
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(stats)
	else:
		vb.add_child(UIH.title("THE LEGEND FADES", 48))
		var s := UIH.label("Thach Sanh falls. The forest holds its breath, waiting for another song.", 18, UIH.LT_DIM)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(s)
		var stats := UIH.label("Act %d   Level %d   Chords: %d" % [Game.act, Game.level, Game.chords.size()], 16, UIH.LT_DIM)
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(stats)
	var b := UIH.btn("NEW RUN", 260)
	b.custom_minimum_size = Vector2(260, 60)
	b.pressed.connect(func(): router.show_title())
	var hc := HBoxContainer.new()
	hc.alignment = BoxContainer.ALIGNMENT_CENTER
	hc.add_child(b)
	vb.add_child(hc)
