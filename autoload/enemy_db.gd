class_name EnemyDB
extends RefCounted
## Story 1 (Thach Sanh) enemy database.
## Intent = {"kind": String, "power": int}.
## kind: attack / defend / debuff / heal / steal / evade / buff.
## - attack: deal `power` damage.
## - defend: gain `power` Block.
## - debuff: apply `power` stacks of debuff["weak"|"vulnerable"].
## - heal: restore `power` HP.
## - steal: steal `power` random cards from the player's hand (gone for the battle).
## - evade: fly out of reach — evades ALL Attacks during the next player turn.
## - buff: gain `power` Strength.

const ENEMIES := {
	"wild_boar": {
		"name": "Wild Boar", "hp": 42, "kind": "normal", "exp": 20,
		"art": "res://assets/art/vl/enemy_wildboar.png",
		"pattern": [
			{"kind": "attack", "power": 9},
			{"kind": "attack", "power": 12},
			{"kind": "defend", "power": 6},
		],
	},
	"forest_viper": {
		"name": "Forest Viper", "hp": 38, "kind": "normal", "exp": 22,
		"art": "res://assets/art/vl/enemy_viper.png",
		"pattern": [
			{"kind": "debuff", "power": 2, "debuff": "weak"},
			{"kind": "attack", "power": 10},
			{"kind": "attack", "power": 10},
		],
	},
	"timber_bandit": {
		"name": "Timber Bandit", "hp": 46, "kind": "normal", "exp": 25,
		"art": "res://assets/art/vl/enemy_bandit.png",
		"pattern": [
			{"kind": "attack", "power": 8},
			{"kind": "defend", "power": 8},
			{"kind": "attack", "power": 13},
		],
	},
	"ly_thong": {
		"name": "Ly Thong", "hp": 95, "kind": "elite", "exp": 45,
		"art": "res://assets/art/vl/enemy_lythong.png",
		"pattern": [
			{"kind": "steal", "power": 1},
			{"kind": "attack", "power": 12},
			{"kind": "debuff", "power": 2, "debuff": "vulnerable"},
			{"kind": "attack", "power": 14},
			{"kind": "defend", "power": 10},
		],
	},
	"chan_tinh": {
		"name": "Chan Tinh", "hp": 110, "kind": "boss", "exp": 0,
		"art": "res://assets/art/vl/enemy_chantinh.png",
		"squeeze": true,  # squeeze ramp: attacks grow if you deal <12 damage/turn
		"phase1": [
			{"kind": "attack", "power": 10},
			{"kind": "attack", "power": 13},
			{"kind": "defend", "power": 12},
			{"kind": "debuff", "power": 2, "debuff": "vulnerable"},
		],
		"phase2": [
			[{"kind": "attack", "power": 15}, {"kind": "debuff", "power": 2, "debuff": "weak"}],
			[{"kind": "attack", "power": 18}, {"kind": "defend", "power": 16}],
		],
	},
	"dai_bang": {
		"name": "Dai Bang", "hp": 135, "kind": "boss", "exp": 0,
		"art": "res://assets/art/vl/enemy_daibang.png",
		"phase1": [
			{"kind": "attack", "power": 12},
			{"kind": "attack", "power": 15},
			{"kind": "evade", "power": 0},
			{"kind": "attack", "power": 22},
			{"kind": "defend", "power": 14},
		],
		"phase2": [
			[{"kind": "attack", "power": 14}, {"kind": "evade", "power": 0}],
			[{"kind": "attack", "power": 22}, {"kind": "buff", "power": 1}],
		],
	},
	# --- STORY 2: HAI BA TRUNG (v6.0) ---
	"han_soldier": {
		"name": "Han Soldier", "hp": 45, "kind": "normal", "exp": 22,
		"art": "res://assets/art/vl/enemy_hansoldier.png",
		"pattern": [
			{"kind": "attack", "power": 10},
			{"kind": "attack", "power": 12},
			{"kind": "defend", "power": 8},
		],
	},
	"han_archer": {
		"name": "Han Archer", "hp": 38, "kind": "normal", "exp": 24,
		"art": "res://assets/art/vl/enemy_hanarcher.png",
		"pattern": [
			{"kind": "attack", "power": 11},
			{"kind": "debuff", "power": 1, "debuff": "vulnerable"},
			{"kind": "attack", "power": 13},
		],
	},
	"han_general": {
		"name": "Han General", "hp": 75, "kind": "elite", "exp": 45,
		"art": "res://assets/art/vl/enemy_hangeneral.png",
		"pattern": [
			{"kind": "attack", "power": 14},
			{"kind": "buff", "power": 2},
			{"kind": "attack", "power": 16},
			{"kind": "defend", "power": 12},
		],
	},
	"to_dinh": {
		"name": "To Dinh", "hp": 140, "kind": "boss", "exp": 0,
		"art": "res://assets/art/vl/enemy_todinh.png",
		"phase1": [
			{"kind": "attack", "power": 12},
			{"kind": "attack", "power": 15},
			{"kind": "defend", "power": 14},
			{"kind": "debuff", "power": 2, "debuff": "weak"},
		],
		"phase2": [
			[{"kind": "attack", "power": 17}, {"kind": "buff", "power": 2}],
			[{"kind": "attack", "power": 20}, {"kind": "defend", "power": 16}],
		],
	},
}

const NORMAL_POOL := ["wild_boar", "forest_viper", "timber_bandit"]
# v6.0: Story 2 pools (Hai Ba Trung vs Han)
const NORMAL_POOL_HBT := ["han_soldier", "han_archer", "han_soldier"]
const ELITE_POOL_HBT := ["han_general"]
const BOSS_HBT := "to_dinh"

static func normal_pool_for_hero(hero_id: String) -> Array:
	if hero_id == "hai_ba_trung":
		return NORMAL_POOL_HBT
	return NORMAL_POOL

## Minions in elite fights: simple cannon fodder.
const MINION_PATTERN := [
	{"kind": "attack", "power": 6},
	{"kind": "defend", "power": 5},
	{"kind": "attack", "power": 8},
]


static func get_def(enemy_id: String) -> Dictionary:
	return ENEMIES.get(enemy_id, {})


static func intents_for_entry(entry: Dictionary, pattern_index: int, phase: int) -> Array:
	if entry.get("minion", false):
		var one: Dictionary = MINION_PATTERN[pattern_index % MINION_PATTERN.size()]
		return [one.duplicate()]
	return intents_for(str(entry.get("id", "")), pattern_index, phase)


static func intent_count(enemy_id: String, phase: int) -> int:
	if (enemy_id == "chan_tinh" or enemy_id == "dai_bang" or enemy_id == "to_dinh") and phase == 2:
		return 2
	return 1


static func intents_for(enemy_id: String, pattern_index: int, phase: int) -> Array:
	var d := get_def(enemy_id)
	var is_boss: bool = (enemy_id == "chan_tinh" or enemy_id == "dai_bang" or enemy_id == "to_dinh")
	if is_boss and phase == 2:
		var p2: Array = d["phase2"]
		var pair: Array = p2[pattern_index % p2.size()]
		return [pair[0].duplicate(), pair[1].duplicate()]
	var pat: Array = d["phase1"] if (is_boss and phase == 1) else d["pattern"]
	var one: Dictionary = pat[pattern_index % pat.size()]
	return [one.duplicate()]


## Human-readable intent label for UI.
static func intent_label(it: Dictionary) -> String:
	var kind: String = str(it.get("kind", ""))
	match kind:
		"attack":
			return "⚔ %d" % int(it.get("power", 0))
		"defend":
			return "🛡 %d" % int(it.get("power", 0))
		"debuff":
			return "⬇ %s %d" % [str(it.get("debuff", "?")).capitalize(), int(it.get("power", 0))]
		"heal":
			return "✚ %d" % int(it.get("power", 0))
		"steal":
			return "🖐 STEAL"
		"evade":
			return "🕊 EVADE"
		"buff":
			return "⬆ STR %d" % int(it.get("power", 0))
	return "?"
