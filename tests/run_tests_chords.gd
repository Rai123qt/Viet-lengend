extends SceneTree
## Chord system logic tests — v3.8 AUTO-DETECT (no compose step).
## Playing Attack/Skill cards builds the note string automatically;
## completing a known chord's sequence triggers it (max 1/turn).
## A note matching no known chord's prefix snaps the string.
## Run: godot --headless --path . --script res://tests/run_tests_chords.gd

var passed := 0
var failed := 0


func check(cond: bool, name: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: " + name)


func new_game() -> GameState:
	var g := GameState.new()
	g.new_run("")  # no artifact by default; artifact tests set it explicitly
	return g


func new_battle(p_encounter = "wild_boar", seed := 12345, game: GameState = null) -> BattleState:
	if game == null:
		game = new_game()
	var bs := BattleState.new()
	bs.setup(game.deck.duplicate(true), p_encounter, game, seed)
	bs.start_player_turn()
	return bs


func find_in_hand(bs: BattleState, card_id: String) -> int:
	for i in range(bs.hand.size()):
		if bs.hand[i]["id"] == card_id:
			return i
	return -1


func give(bs: BattleState, card_id: String) -> int:
	var c := CardDB.make(card_id)
	bs.hand.append(c)
	return bs.hand.size() - 1


func play_id(bs: BattleState, card_id: String) -> Dictionary:
	var i := find_in_hand(bs, card_id)
	if i < 0:
		i = give(bs, card_id)
	bs.energy = 99
	return bs.play_card(i)


func _init() -> void:
	_run_all()
	print("==== CHORD TESTS: %d passed, %d failed ====" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _run_all() -> void:
	# --- prefix-free DB: no chord is a prefix of another ---
	var ids: Array = ChordDB.CHORDS.keys()
	var clash := false
	for i in range(ids.size()):
		for j in range(ids.size()):
			if i == j:
				continue
			var a: Array = ChordDB.seq(ids[i])
			var b: Array = ChordDB.seq(ids[j])
			if a.size() <= b.size():
				var pre := true
				for k in range(a.size()):
					if str(a[k]) != str(b[k]):
						pre = false
						break
				if pre:
					clash = true
					printerr("PREFIX CLASH: %s is prefix of %s" % [ids[i], ids[j]])
	check(not clash, "chord DB is prefix-free")
	# --- auto-detect: WAR DRUM (A A A), no compose step ---
	var bs := new_battle()
	var ehp: int = bs.enemy.hp
	play_id(bs, "strike")   # A
	check(bs.chord_seq == ["A"], "seq tracks [A]")
	check(bs.chord_target() == "war_drum", "target war_drum after A")
	play_id(bs, "strike")   # A
	check(bs.chord_seq == ["A", "A"], "seq tracks [A, A]")
	play_id(bs, "strike")   # A -> complete: 10 to all
	check(bs.chord_completed, "war drum auto-completed")
	check(bs.chord_seq.is_empty(), "seq cleared after completion")
	check(bs.enemy.hp < ehp - 18, "war drum dealt 10 + strikes (ehp %d -> %d)" % [ehp, bs.enemy.hp])
	# --- max 1 chord per turn ---
	play_id(bs, "defend"); play_id(bs, "defend"); play_id(bs, "defend")  # S S S
	check(bs.turn_notes == ["A", "A", "A", "S", "S", "S"], "tracker keeps recording")
	check(bs.chord_seq.is_empty(), "no second chord tracked after completion")
	check(bs.player.armor < 20, "lullaby did not trigger twice (armor %d)" % bs.player.armor)
	# --- wrong note snaps ---
	var bs4 := new_battle()
	play_id(bs4, "strike")  # A: prefix of AAA/AAS
	check(bs4.chord_seq == ["A"], "seq [A] ok")
	play_id(bs4, "defend")  # S: "AS" matches no starter prefix -> snap
	check(bs4.chord_seq.is_empty(), "wrong note snaps string")
	check(bs4.chord_snapped, "snapped flag set")
	play_id(bs4, "defend")  # S: fresh prefix of SSS/SSA
	check(bs4.chord_seq == ["S"], "string rebuilds after snap")
	check(not bs4.chord_snapped, "snapped flag cleared on new note")
	# --- Power is a grace note ---
	var bs5 := new_battle()
	play_id(bs5, "sturdy_strings")  # POWER
	check(bs5.chord_seq.is_empty(), "power does not advance seq")
	check(bs5.turn_notes == ["P"], "power tracked for display")
	check(bs5.sturdy_strings, "sturdy strings active")
	play_id(bs5, "strike")  # A vs nothing yet... A is prefix -> ok
	check(bs5.chord_seq == ["A"], "A after power is fine")
	play_id(bs5, "defend")  # S: "AS" wrong, but sturdy holds (1/battle)
	check(not bs5.chord_snapped, "sturdy strings holds first wrong note")
	check(bs5.chord_seq == ["A"], "seq kept after hold")
	play_id(bs5, "defend")  # wrong again -> snap
	check(bs5.chord_snapped, "second wrong note snaps")
	check(bs5.chord_seq.is_empty(), "seq cleared after snap")
	# --- LULLABY effect (S S S -> 10 block) ---
	var bs6 := new_battle()
	play_id(bs6, "defend")
	play_id(bs6, "defend")
	var b0: int = bs6.player.armor
	play_id(bs6, "defend")
	check(bs6.player.armor >= b0 + 10, "lullaby gives 10 block")
	# --- CHARGE effect (A A S -> next attack +10) ---
	var bs7 := new_battle()
	play_id(bs7, "strike")
	play_id(bs7, "strike")
	play_id(bs7, "defend")  # complete
	check(bs7.next_attack_bonus == 10, "charge banks +10")
	var ehp7: int = bs7.enemy.hp
	play_id(bs7, "strike")  # 7 + 10 = 17
	check(ehp7 - bs7.enemy.hp == 17, "charge bonus applied (17 dmg)")
	check(bs7.next_attack_bonus == 0, "charge consumed")
	# --- STEADFAST (S S A -> draw 2) ---
	var bs8 := new_battle()
	var h0: int = bs8.hand.size()
	play_id(bs8, "defend")
	play_id(bs8, "defend")
	play_id(bs8, "strike")
	check(bs8.hand.size() == h0 - 1, "steadfast draws 2 (net)")
	# --- victory_song gating ---
	var bs9 := new_battle()
	var i9 := give(bs9, "victory_song")
	bs9.energy = 99
	var chk: Dictionary = bs9.can_play(i9)
	check(not chk["ok"], "victory song blocked before chord")
	play_id(bs9, "strike"); play_id(bs9, "strike"); play_id(bs9, "strike")
	i9 = find_in_hand(bs9, "victory_song")
	if i9 < 0:
		i9 = give(bs9, "victory_song")
	chk = bs9.can_play(i9)
	check(chk["ok"], "victory song playable after chord")
	# --- divine_lute power: 3-note chords finish at 2 notes ---
	var bs10 := new_battle()
	play_id(bs10, "divine_lute")
	bs10.end_player_turn()
	bs10.start_player_turn()
	play_id(bs10, "strike")
	play_id(bs10, "strike")  # AA -> war_drum + charge complete
	check(bs10.chord_completed, "divine lute completes 3-note chords at 2 notes")
	# --- learn_chord ---
	var g10 := new_game()
	check(g10.chords.size() == 4, "start with 4 chords")
	check(g10.learn_chord("thunder"), "learn thunder")
	check(not g10.learn_chord("thunder"), "no duplicate learn")
	check(not g10.learn_chord("nope"), "invalid chord rejected")
	# --- thunder effect (A S A A -> 20 target + 8 others) ---
	var g12 := new_game()
	g12.learn_chord("thunder")
	var bs12 := new_battle([{"id": "wild_boar", "hp_mult": 1.0}, {"id": "forest_viper", "hp_mult": 1.0}], 42, g12)
	play_id(bs12, "strike")  # A
	play_id(bs12, "defend")  # S
	play_id(bs12, "strike")  # A
	var t0: int = bs12.enemies[0].hp
	var o0: int = bs12.enemies[1].hp
	play_id(bs12, "strike")  # A -> complete
	check(bs12.chord_completed, "thunder completed")
	check(t0 - bs12.enemies[0].hp >= 20, "thunder 20 to target")
	check(o0 - bs12.enemies[1].hp >= 8, "thunder 8 to other")
	# --- divine_melody stuns (S A S S A) ---
	var g13 := new_game()
	g13.learn_chord("divine_melody")
	var bs13 := new_battle("timber_bandit", 7, g13)
	play_id(bs13, "defend")  # S
	play_id(bs13, "strike")  # A
	play_id(bs13, "defend")  # S
	play_id(bs13, "defend")  # S
	var hpb: int = bs13.player.hp
	play_id(bs13, "strike")  # A -> complete
	check(bs13.chord_completed, "divine melody completed")
	bs13.end_player_turn()  # enemy phase: stunned, no damage
	check(bs13.player.hp == hpb, "stunned enemy deals no damage")
	# --- steal intent (ly thong) ---
	var bs14 := new_battle("ly_thong", 99)
	bs14.enemy_intents[0] = [{"kind": "steal", "power": 1}]
	var h14: int = bs14.hand.size()
	bs14.end_player_turn()
	check(bs14.stolen_pile.size() == 1, "ly thong steals 1 card")
	# --- evade (dai bang) ---
	var bs15 := new_battle("dai_bang", 5)
	bs15.enemies[0].evading = true
	var ehp15: int = bs15.enemy.hp
	play_id(bs15, "strike")
	check(bs15.enemy.hp == ehp15, "evade dodges attack card")
	# chord damage still lands (not an Attack card) — fresh battle
	var bs15b := new_battle("dai_bang", 6)
	bs15b.enemies[0].evading = true
	var ehp15b: int = bs15b.enemy.hp
	play_id(bs15b, "strike"); play_id(bs15b, "strike"); play_id(bs15b, "strike")
	check(bs15b.enemy.hp < ehp15b, "chord damage ignores evade")
	# --- weak / vulnerable math ---
	var bs16 := new_battle()
	bs16.enemy.vulnerable = 2
	var ehp16: int = bs16.enemy.hp
	play_id(bs16, "strike")  # 7 * 1.5 = 10.5 -> 11
	check(ehp16 - bs16.enemy.hp == 11, "vulnerable x1.5")
	bs16.enemy.weak = 2
	bs16.enemy_intents[0] = [{"kind": "attack", "power": 20}]
	var php: int = bs16.player.hp
	bs16.end_player_turn()
	check(php - bs16.player.hp == 15, "weak x0.75 on enemy attack (20->15)")
	# --- chan tinh squeeze ---
	var bs17 := new_battle("chan_tinh", 11)
	bs17.end_player_turn()
	bs17.start_player_turn()  # dealt 0 dmg last turn -> squeeze +1
	check(bs17.enemies[0].squeeze_bonus == 1, "chan tinh squeezes when hit softly")
	# --- seq resets each turn ---
	var bs18 := new_battle()
	play_id(bs18, "strike")
	bs18.end_player_turn()
	bs18.start_player_turn()
	check(bs18.chord_seq.is_empty(), "seq resets on new turn")
	check(bs18.turn_notes.is_empty(), "turn notes reset on new turn")
	check(not bs18.chord_completed, "completed resets on new turn")
	print("ALL CHORD TESTS DONE")
