class_name GameState
extends Node
## Autoload "Game": persistent campaign state for VIET LEGENDS — Story 1.
## HP persists across battles; deck/gold/relics/chords/exp evolve per node.

const LEVEL_THRESHOLDS := [0, 40, 100, 180, 280]  # index = level-1 -> exp needed for that level
const LEVEL_PERKS := [
	{"id": "hp_up", "name": "Sturdy Body", "desc": "+10 max HP and heal 10."},
	{"id": "energy_t1", "name": "Early Bird", "desc": "Turn 1 of each battle: +1 energy."},
	{"id": "heal_up", "name": "Hearty Meals", "desc": "Your healing +3."},
	{"id": "attack_up", "name": "Strong Arms", "desc": "Your Attacks deal +2 damage."},
	{"id": "block_up", "name": "Iron Skin", "desc": "Your Block gains +2."},
	{"id": "armor_start", "name": "Bedrock", "desc": "Start each battle with 6 Block."},
	{"id": "draw_up", "name": "Quick Hands", "desc": "Turn 1 of each battle: draw 1 extra card."},
	{"id": "strength_up", "name": "War Spirit", "desc": "Start each battle with 1 Strength."},
]

const RELICS := {
	"iron_rations": {"name": "Iron Rations", "desc": "Start each battle with 4 Block."},
	"coffee_thermos": {"name": "Coffee Thermos", "desc": "Turn 1 of each battle: +1 energy."},
	"whetstone": {"name": "Whetstone", "desc": "Your Attacks deal +1 damage."},
	"chainmail": {"name": "Chainmail Shirt", "desc": "Start each of your turns with 2 Block."},
	"bandages": {"name": "Bandages", "desc": "Heal 3 HP at the start of each of your turns."},
	"second_breakfast": {"name": "Second Breakfast", "desc": "Turn 1 of each battle: draw 1 extra card."},
	"bramble_crown": {"name": "Bramble Crown", "desc": "When you take HP damage, deal 2 damage to your target."},
	"torn_page": {"name": "Torn Page", "desc": "Whenever you reshuffle, gain 4 Block."},
	"executioner_hood": {"name": "Executioner's Hood", "desc": "Your Attacks deal +3 damage to enemies below half HP."},
	"caltrops": {"name": "Caltrops", "desc": "Enemies start each battle with 5 less HP."},
	"herbal_pouch": {"name": "Herbal Pouch", "desc": "Heal 2 HP whenever you complete a chord."},
	"lucky_coin": {"name": "Lucky Coin", "desc": "Gain 25 gold after each battle."},
}

var map_graph: MapGraph = null
var act: int = 1

var deck: Array = []          # Array of card instances {"id","upgraded","power","uid"}
var gold: int = 0
var relics: Array = []       # Array of relic ids
var items: Array = []        # Array of item ids (max 3, consumables)
var chords: Array = []       # known chord ids (ChordDB)
var exp: int = 0
var level: int = 1
var perks: Array = []        # Array of perk ids
var equipment: String = ""   # currently equipped (1 at a time)
var max_hp: int = 80
var hp: int = 80
var run_active: bool = false
# v5.9: active hero id ("thach_sanh" | "hai_ba_trung"); set by character select.
var hero_id: String = "thach_sanh"


# --- Consumable items (3 slots) ---
# icon: shown on the button; fx: effect id; val: effect value; price: gold
const ITEMS := {
	"rice_ball": {"name": "Rice Ball", "art": "rice_bowl", "fx": "heal", "val": 15, "price": 25,
		"desc": "Restore 15 HP."},
	"herbal_tea": {"name": "Herbal Tea", "art": "pot", "fx": "heal", "val": 30, "price": 50,
		"desc": "Restore 30 HP."},
	"ginseng": {"name": "Ginseng Root", "art": "lotus", "fx": "heal", "val": 50, "price": 80,
		"desc": "Restore 50 HP."},
	"energy_tonic": {"name": "Energy Tonic", "art": "drum", "fx": "energy", "val": 2, "price": 40,
		"desc": "Gain 2 Energy."},
	"smoke_bomb": {"name": "Smoke Bomb", "art": "wind", "fx": "armor", "val": 15, "price": 50,
		"desc": "Gain 15 Block."},
	"throwing_knife": {"name": "Throwing Knife", "art": "dagger", "fx": "dmg_target", "val": 12, "price": 35,
		"desc": "Deal 12 damage to the target."},
	"firecracker": {"name": "Firecracker", "art": "lightning", "fx": "dmg_all", "val": 8, "price": 50,
		"desc": "Deal 8 damage to ALL enemies."},
	"war_drum_item": {"name": "War Drum", "art": "drum", "fx": "strength", "val": 2, "price": 45,
		"desc": "Gain 2 Strength."},
	"lute_string": {"name": "Spare String", "art": "note", "fx": "draw", "val": 2, "price": 35,
		"desc": "Draw 2 cards."},
	"bandage_wrap": {"name": "Bandage", "art": "hand", "fx": "heal", "val": 12, "price": 15,
		"desc": "Restore 12 HP."},
	"iron_plate": {"name": "Iron Plate", "art": "shield", "fx": "armor", "val": 20, "price": 55,
		"desc": "Gain 20 Block."},
	"tiger_balm_item": {"name": "Tiger Balm", "art": "lotus", "fx": "cleanse", "val": 0, "price": 30,
		"desc": "Remove your Weak and Vulnerable."},
}
const MAX_ITEMS := 3


# --- Divine Artifacts (1 equipped at a time; taking a new one replaces the old) ---
# All PASSIVE: always-on effects, no activation needed. v3.4 replaces the
# old active-use equipment.
const EQUIPMENT := {
	"divine_axe": {"name": "Divine Axe", "art": "axe", "price": 250,
		"icon": "res://assets/art/vl3/artifact_divine_axe.png",
		"desc": "Your first Attack each turn deals +6 damage."},
	"divine_lute": {"name": "Divine Lute", "art": "lute", "price": 250,
		"icon": "res://assets/art/vl3/artifact_divine_lute.png",
		"desc": "Whenever you complete a chord, ALL enemies lose 4 HP."},
	"endless_rice_pot": {"name": "Endless Rice Pot", "art": "pot", "price": 250,
		"icon": "res://assets/art/vl3/artifact_rice_pot.png",
		"desc": "Whenever you Heal, heal +6 HP more."},
}


func equip(id: String) -> void:
	if EQUIPMENT.has(id):
		equipment = id


func add_item(id: String) -> bool:
	if items.size() >= MAX_ITEMS or not ITEMS.has(id):
		return false
	items.append(id)
	return true


func has_item_space() -> bool:
	return items.size() < MAX_ITEMS


func remove_item(idx: int) -> String:
	if idx < 0 or idx >= items.size():
		return ""
	var id: String = items[idx]
	items.remove_at(idx)
	return id


func learn_chord(chord_id: String) -> bool:
	if chord_id in chords or not ChordDB.CHORDS.has(chord_id):
		return false
	chords.append(chord_id)
	return true


func new_run(chosen_equipment: String, p_hero_id: String = "thach_sanh", rng: RandomNumberGenerator = null) -> void:
	hero_id = p_hero_id if CharacterDB.CHARACTERS.has(p_hero_id) else "thach_sanh"
	var hdef: Dictionary = CharacterDB.CHARACTERS[hero_id]
	deck.clear()
	for id in CardDB.starter_deck_for_hero(hero_id):
		deck.append(CardDB.make(id))
	gold = 60
	relics.clear()
	items.clear()
	items.append("rice_ball")
	chords = ChordDB.STARTER_CHORDS.duplicate()
	act = 1
	exp = 0
	level = 1
	perks.clear()
	equipment = chosen_equipment
	max_hp = int(hdef.get("hp", 80))
	hp = max_hp
	run_active = true
	# v5.0: procedural map per act (MapGen). Fallback rng when not provided.
	var r: RandomNumberGenerator = rng
	if r == null:
		r = RandomNumberGenerator.new()
		r.seed = int(Time.get_unix_time_from_system()) % 1000000
	map_graph = MapGen.generate(1, r, hero_id)


## v5.0: advance to the next act with a freshly generated map.
func advance_act(rng: RandomNumberGenerator) -> void:
	act = mini(act + 1, 3)
	map_graph = MapGen.generate(act, rng, hero_id)
	# heal a bit between acts
	hp = mini(max_hp, hp + 20)


## Encounter for a graph node: Array of {"id","hp_mult"}.
## node["enc"]: enemy id | "random_normal" | "random_duo".
## v5.0: node["mult"] scales hp for elites/bosses per act.
func resolve_encounter(node: Dictionary, rng: RandomNumberGenerator) -> Array:
	var enc: String = str(node.get("enc", "random_normal"))
	var fmult := 0.7 if act <= 1 else 0.85
	var nmult := float(node.get("mult", 1.0))
	match enc:
		"random_normal":
			var pool := EnemyDB.normal_pool_for_hero(hero_id)
			return [{"id": pool[rng.randi_range(0, pool.size() - 1)],
				"hp_mult": fmult}]
		"random_duo":
			var pool2 := EnemyDB.normal_pool_for_hero(hero_id)
			return [
				{"id": pool2[rng.randi_range(0, pool2.size() - 1)],
					"hp_mult": fmult},
				{"id": pool2[rng.randi_range(0, pool2.size() - 1)],
					"hp_mult": fmult},
			]
		"ly_thong":
			return [
				{"id": "ly_thong", "hp_mult": 1.0},
				{"id": "timber_bandit", "hp_mult": 0.7, "power_mult": 0.6, "minion": true},
			]
		_:
			return [{"id": enc, "hp_mult": fmult * nmult}]


func is_run_complete() -> bool:
	return map_graph != null and map_graph.is_story_complete()


func advance_node() -> void:
	# Legacy no-op: the directed graph map handles node state in travel_to().
	pass


func has_relic(rid: String) -> bool:
	return rid in relics


func has_perk(pid: String) -> bool:
	return pid in perks


func add_relic(rid: String) -> void:
	if not has_relic(rid):
		relics.append(rid)


func add_gold(n: int) -> void:
	gold = maxi(0, gold + n)


func heal(n: int) -> void:
	hp = mini(hp + n, max_hp)


func damage(n: int) -> void:
	hp = maxi(0, hp - n)


func add_card(card_id: String, upgraded: bool = false) -> void:
	deck.append(CardDB.make(card_id, upgraded))


func remove_card_at(idx: int) -> void:
	if idx >= 0 and idx < deck.size():
		deck.remove_at(idx)


func upgrade_card_at(idx: int) -> void:
	# v6.9.13: prevent double-upgrade (Rai: card đã upgrade rồi thì thôi)
	if idx >= 0 and idx < deck.size():
		if not deck[idx].get("upgraded", false):
			deck[idx]["upgraded"] = true


func deck_count(card_id: String) -> int:
	var c := 0
	for card in deck:
		if card["id"] == card_id:
			c += 1
	return c


func add_exp(n: int) -> bool:
	exp += n
	var leveled := false
	while level < 5 and exp >= LEVEL_THRESHOLDS[level]:
		level += 1
		leveled = true
	return leveled


func roll_level_choices(rng: RandomNumberGenerator) -> Array:
	var pool := []
	for p in LEVEL_PERKS:
		if not has_perk(p["id"]):
			pool.append(p)
	pool.shuffle()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	return pool.slice(0, mini(3, pool.size()))


func apply_perk(pid: String) -> void:
	if has_perk(pid):
		return
	perks.append(pid)
	if pid == "hp_up":
		max_hp += 10
		heal(10)
