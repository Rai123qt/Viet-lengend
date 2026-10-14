extends SceneTree
## v3.6: render ALL 47 card faces with text overlay, 2 pages (24+23),
## for zoom-inspection of name/desc alignment.

var _step := 0
var _ids: Array = []
var _page := 0
const PER_PAGE := 24


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	_ids = CardDB.CARDS.keys()
	_ids.sort()
	_show_page(0)


func _show_page(p: int) -> void:
	_page = p
	for ch in root.get_children():
		ch.queue_free()
	var bg := ColorRect.new()
	bg.color = Color("1a1410")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var cols := 8
	var start := p * PER_PAGE
	for i in range(PER_PAGE):
		var idx := start + i
		if idx >= _ids.size():
			break
		var cid := str(_ids[idx])
		var w = load("res://ui/card_widget.gd").new(CardDB.make(cid), null)
		w.inspect_only = true
		var cx := 10 + (i % cols) * (140 + 10)
		var cy := 10 + (i / cols) * (204 + 10)
		w.position = Vector2(cx, cy)
		root.add_child(w)
	print("rendering page ", p, " cards ", start, "-", mini(start + PER_PAGE - 1, _ids.size() - 1))


func _process(_delta: float) -> bool:
	_step += 1
	if _step == 30:
		var img := root.get_texture().get_image()
		if img != null:
			img.save_png("/tmp/shots/all_cards_v36_p%d.png" % _page)
			print("Saved page ", _page)
		if (_page + 1) * PER_PAGE < _ids.size():
			_show_page(_page + 1)
			_step = 0
		else:
			print("DONE")
			return true
	return false
