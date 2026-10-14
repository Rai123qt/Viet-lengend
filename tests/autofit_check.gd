extends SceneTree
## Verifies CardWidget._fit_text(): a very long description must shrink the
## font to the 7px minimum; normal cards keep 9px; every real card in the
## pool must end up within [7, 9] and the card layout never breaks
## (clip_text is the final safety net; full text readable via zoom).
## Run: godot --headless --path . --script res://tests/autofit_check.gd

const LONG_TEXT := "Deal 7 damage. Then deal 7 more damage. Then apply 3 Drowsy, gain 2 energy, draw 2 cards, and shuffle a Nightmare into your discard pile for good measure."


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ok := true
	# 1. absurdly long text -> min font 7
	var w := CardWidget.new(CardDB.make("nightmare_cut"), null)
	root.add_child(w)
	w._text_l.text = LONG_TEXT
	w._fit_text()
	var fs: int = w._text_l.get_theme_font_size("font_size")
	print("AUTOFIT long text fs=%d (expect 7)" % fs)
	if fs != 7:
		printerr("AUTOFIT FAIL: long text did not reach min font")
		ok = false
	if not w._text_l.clip_text:
		printerr("AUTOFIT FAIL: clip_text safety not enabled")
		ok = false
	# 2. normal card keeps 9
	var w2 := CardWidget.new(CardDB.make("rest_brace"), null)
	root.add_child(w2)
	var fs2: int = w2._text_l.get_theme_font_size("font_size")
	print("AUTOFIT normal card fs=%d (expect 9)" % fs2)
	if fs2 != 9:
		printerr("AUTOFIT FAIL: normal card font changed")
		ok = false
	# 3. every real card ends within [7, 9]
	var f: Font = UIH.font_reg()
	var worst := ""
	var worst_fs := 9
	for id in CardDB.CARDS.keys():
		var c := CardDB.make(id)
		var w3 := CardWidget.new(c, null)
		root.add_child(w3)
		var f3: int = w3._text_l.get_theme_font_size("font_size")
		if f3 < 7 or f3 > 9:
			printerr("AUTOFIT FAIL: card %s fs=%d out of range" % [id, f3])
			ok = false
		if f3 < worst_fs:
			worst_fs = f3
			worst = id
		w3.queue_free()
	print("AUTOFIT smallest real card: %s fs=%d" % [worst, worst_fs])
	print("AUTOFIT " + ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
