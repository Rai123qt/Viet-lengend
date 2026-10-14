extends Node
## Central sound bank (autoload "Sfx").
##
## Usage:
##   Sfx.play("strike")              # new keys (see KEYS below)
##   Sfx.play("slash")               # legacy names still work (aliased)
##   Sfx.play("strike", -4.0)        # optional volume override
##   Sfx.ambience("battle_loop")     # start/switch an ambience loop
##   Sfx.ambience_stop()             # stop all ambience
##
## Variant files (_01, _02, _03): one is picked at random per play,
## with pitch_scale randomized 0.98-1.02 for organic feel.
## Missing files are skipped defensively (no crash).

const MAX_VOICES := 10
const _BASE := "res://assets/audio/new/"

## key -> list of file paths (variants). Legacy names are aliases.
const BANKS := {
	# --- legacy names (old Sfx.play("x") calls keep working) ---
	"click": ["01_UI/ui_click_01.wav", "01_UI/ui_click_02.wav", "01_UI/ui_click_03.wav"],
	"draw": ["02_Cards/card_draw_01.wav", "02_Cards/card_draw_02.wav", "02_Cards/card_draw_03.wav", "02_Cards/card_draw_04.wav"],
	"card": ["02_Cards/card_play_01.wav", "02_Cards/card_play_02.wav", "02_Cards/card_play_03.wav"],
	"slash": ["03_Combat/strike_01.wav", "03_Combat/strike_02.wav", "03_Combat/strike_03.wav"],
	"hit": ["09_Characters/enemy_hit_01.wav", "09_Characters/enemy_hit_02.wav", "09_Characters/enemy_hit_03.wav"],
	"clang": ["03_Combat/guard_01.wav", "03_Combat/guard_02.wav", "03_Combat/guard_03.wav"],
	"heal": ["03_Combat/mend_01.wav", "03_Combat/mend_02.wav", "03_Combat/mend_03.wav"],
	"lull": ["03_Combat/bind_01.wav", "03_Combat/bind_02.wav", "03_Combat/bind_03.wav"],
	"hurt": ["09_Characters/player_hit_01.wav", "09_Characters/player_hit_02.wav", "09_Characters/player_hit_03.wav"],
	"poof": ["09_Characters/enemy_death.wav"],
	"victory": ["10_Stingers/victory.wav"],
	"defeat": ["10_Stingers/defeat.wav"],
	# --- new keys ---
	"ui_click": ["01_UI/ui_click_01.wav", "01_UI/ui_click_02.wav", "01_UI/ui_click_03.wav"],
	"ui_confirm": ["01_UI/ui_confirm.wav"],
	"ui_error": ["01_UI/ui_error.wav"],
	"card_draw": ["02_Cards/card_draw_01.wav", "02_Cards/card_draw_02.wav", "02_Cards/card_draw_03.wav", "02_Cards/card_draw_04.wav"],
	"card_play": ["02_Cards/card_play_01.wav", "02_Cards/card_play_02.wav", "02_Cards/card_play_03.wav"],
	"card_discard": ["02_Cards/card_discard.wav"],
	"strike": ["03_Combat/strike_01.wav", "03_Combat/strike_02.wav", "03_Combat/strike_03.wav"],
	"strike_heavy": ["03_Combat/strike_heavy_01.wav", "03_Combat/strike_heavy_02.wav", "03_Combat/strike_heavy_03.wav"],
	"guard": ["03_Combat/guard_01.wav", "03_Combat/guard_02.wav", "03_Combat/guard_03.wav"],
	"bind": ["03_Combat/bind_01.wav", "03_Combat/bind_02.wav", "03_Combat/bind_03.wav"],
	"mend": ["03_Combat/mend_01.wav", "03_Combat/mend_02.wav", "03_Combat/mend_03.wav"],
	"armor_break": ["03_Combat/armor_break.wav"],
	"intent_reveal": ["04_Intent/intent_reveal_01.wav", "04_Intent/intent_reveal_02.wav", "04_Intent/intent_reveal_03.wav"],
	"new_turn": ["04_Intent/new_turn.wav"],
	"end_turn": ["04_Intent/end_turn.wav"],
	"map_select": ["07_Map/map_select.wav"],
	"node_battle": ["07_Map/node_battle.wav"],
	"enemy_hit": ["09_Characters/enemy_hit_01.wav", "09_Characters/enemy_hit_02.wav", "09_Characters/enemy_hit_03.wav"],
	"player_hit": ["09_Characters/player_hit_01.wav", "09_Characters/player_hit_02.wav", "09_Characters/player_hit_03.wav"],
	"enemy_death": ["09_Characters/enemy_death.wav"],
}

## Ambience loops (dedicated players, looped).
const AMBIENCE := {
	"battle_loop": "11_Ambience/battle_loop.wav",
	"boss_arena_loop": "11_Ambience/boss_arena_loop.wav",
	"sleepless_city_loop": "11_Ambience/sleepless_city_loop.wav",
	"bureau_interface_loop": "11_Ambience/bureau_interface_loop.wav",
}

var enabled := true

var _banks := {}        # key -> Array[AudioStream]
var _players: Array[AudioStreamPlayer] = []
var _idx := 0
var _amb := {}          # name -> AudioStream
var _amb_players: Array[AudioStreamPlayer] = []
var _amb_cur := -1      # index into _amb_players currently playing, -1 = none


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Load all variant files once, deduped by path.
	var by_path := {}
	for key in BANKS:
		var streams: Array = []
		for rel in BANKS[key]:
			var path: String = _BASE + str(rel)
			if not by_path.has(path):
				by_path[path] = _safe_load(path)
			var s: AudioStream = by_path[path]
			if s != null:
				streams.append(s)
		if not streams.is_empty():
			_banks[key] = streams
	# Ambience loops.
	for aname in AMBIENCE:
		var s := _safe_load(_BASE + AMBIENCE[aname])
		if s != null:
			_amb[aname] = s
	# Voice pool for one-shots.
	for i in range(MAX_VOICES):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	# Two dedicated players for ambience crossfade.
	for i in range(2):
		var ap := AudioStreamPlayer.new()
		ap.bus = "Master"
		add_child(ap)
		_amb_players.append(ap)


func _safe_load(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var r: Resource = ResourceLoader.load(path)
	return r as AudioStream


## Play a one-shot by key. Unknown keys are ignored (defensive).
func play(sound_name: String, vol_db: float = 0.0) -> void:
	if not enabled:
		return
	if not _banks.has(sound_name):
		return
	var variants: Array = _banks[sound_name]
	var p := _players[_idx]
	_idx = (_idx + 1) % MAX_VOICES
	p.stream = variants[randi() % variants.size()]
	p.pitch_scale = randf_range(0.98, 1.02)
	p.volume_db = vol_db
	p.play()


## Alias kept for clarity; identical to play().
func play2(key: String, vol_db: float = 0.0) -> void:
	play(key, vol_db)


## Start (or switch) an ambience loop. Simple crossfade: fade out the old,
## start the new immediately.
func ambience(loop_name: String, vol_db: float = -8.0) -> void:
	if not _amb.has(loop_name):
		return
	var next_idx := 0 if _amb_cur != 0 else 1
	var old_idx := _amb_cur
	_amb_cur = next_idx
	var np := _amb_players[next_idx]
	np.stream = _amb[loop_name]
	np.volume_db = vol_db
	np.pitch_scale = 1.0
	np.play()
	if old_idx >= 0 and old_idx != next_idx:
		var op := _amb_players[old_idx]
		var tw := create_tween()
		tw.tween_property(op, "volume_db", -40.0, 0.6)
		tw.tween_callback(op.stop)


## Stop all ambience loops.
func ambience_stop() -> void:
	_amb_cur = -1
	for ap in _amb_players:
		ap.stop()


func set_enabled(v: bool) -> void:
	enabled = v
