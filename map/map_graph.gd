class_name MapGraph
extends RefCounted
## Directed graph for the campaign map. Data-driven: UI only reads this.
## Node: {id, type, pos:Vector2, state, out:[ids], in:[ids], loc, wake, reward}
## States: LOCKED, AVAILABLE, CURRENT, CLEARED

const S_LOCKED := "LOCKED"
const S_AVAILABLE := "AVAILABLE"
const S_CURRENT := "CURRENT"
const S_CLEARED := "CLEARED"

var nodes: Dictionary = {}  # id -> node dict
var current_id: String = ""


func _mk(id: String, type: String, x: float, y: float, loc: String,
		out: Array, wake: int = 0, reward: String = "") -> Dictionary:
	return {
		"id": id, "type": type, "pos": Vector2(x, y), "loc": loc,
		"out": out, "in": [], "state": S_LOCKED,
		"wake": wake, "reward": reward,
	}


func build_test_map() -> void:
	nodes.clear()
	# START -> M1 (fixed battle) -> 3 routes
	_add(_mk("start", "START", 80, 360, "Bureau Gate", ["m1"]))
	_add(_mk("m1", "SHOP", 200, 360, "Night Market", ["a1", "b1", "c1"], 0, "Test shop"))
	# Route A (upper)
	_add(_mk("a1", "BATTLE", 330, 200, "Rooftop Row", ["a2"]))
	_add(_mk("a2", "SHOP", 460, 180, "Clock District", ["x1"]))
	_add(_mk("a3", "BATTLE", 710, 180, "Bell Tower", ["a4"]))
	_add(_mk("a4", "EVENT", 840, 300, "Highline", ["boss"]))
	# Route B (middle)
	_add(_mk("b1", "EVENT", 330, 360, "Central Plaza", ["b2"]))
	_add(_mk("b2", "BATTLE", 460, 360, "Grand Avenue", ["x1"]))
	_add(_mk("b3", "SHOP", 710, 360, "Night Market", ["b4"]))
	_add(_mk("b4", "BATTLE", 840, 420, "Old Tramline", ["boss"]))
	# Route C (lower)
	_add(_mk("c1", "BATTLE", 330, 520, "Residential Block", ["c2"]))
	_add(_mk("c2", "EVENT", 460, 540, "Somnolence Ward", ["c3"], -1, "Clinic ahead"))
	_add(_mk("c3", "CLINIC", 710, 540, "Free Clinic", ["c4"], -1, "Heal"))
	_add(_mk("c4", "BATTLE", 840, 520, "Canal Side", ["boss"]))
	# Merge point: A2 + B2 -> X1 (elite)
	_add(_mk("x1", "ELITE", 585, 270, "Crossroads", ["a3", "b3"], 0, "Elite!"))
	# Boss
	_add(_mk("boss", "BOSS", 1100, 360, "Keeper Tower", []))
	# Build incoming links
	for id in nodes:
		for oid in (nodes[id] as Dictionary)["out"]:
			(nodes[oid] as Dictionary)["in"].append(id)
	# Initial state: start is CURRENT
	current_id = "start"
	(nodes["start"] as Dictionary)["state"] = S_CURRENT
	_update_available()


func _add(n: Dictionary) -> void:
	nodes[n["id"]] = n


func get_node(id: String) -> Dictionary:
	return nodes.get(id, {})


func _update_available() -> void:
	# Only outgoing from CURRENT become AVAILABLE. Everything else LOCKED
	# (except CLEARED and CURRENT).
	for id in nodes:
		var n: Dictionary = nodes[id]
		if n["state"] == S_CLEARED or n["state"] == S_CURRENT:
			continue
		n["state"] = S_LOCKED
	if current_id != "" and nodes.has(current_id):
		for oid in (nodes[current_id] as Dictionary)["out"]:
			(nodes[oid] as Dictionary)["state"] = S_AVAILABLE


func can_travel_to(id: String) -> bool:
	if not nodes.has(id):
		return false
	return (nodes[id] as Dictionary)["state"] == S_AVAILABLE


func travel_to(id: String) -> bool:
	# Move CURRENT to a connected AVAILABLE node. No backtracking.
	if not can_travel_to(id):
		return false
	if current_id != "" and nodes.has(current_id):
		(nodes[current_id] as Dictionary)["state"] = S_CLEARED
	current_id = id
	(nodes[id] as Dictionary)["state"] = S_CURRENT
	_update_available()
	return true


func all_connections() -> Array:
	# Returns [{from:Vector2, to:Vector2, from_id, to_id}] for drawing lines.
	var conns := []
	for id in nodes:
		var n: Dictionary = nodes[id]
		for oid in n["out"]:
			if nodes.has(oid):
				conns.append({
					"from": n["pos"], "to": (nodes[oid] as Dictionary)["pos"],
					"from_id": id, "to_id": oid,
				})
	return conns


func is_boss_reached() -> bool:
	return current_id == "boss"


func is_story_complete() -> bool:
	var b := get_node("boss")
	return not b.is_empty() and str(b.get("state", "")) == S_CLEARED


## VIET LEGENDS — Story 1 (Thach Sanh): The Green Forest.
## Act 1: forest (boar/viper/bandit) -> Ly Thong (elite) -> Chan Tinh (mid-boss).
## Act 2: palace road & border -> Dai Bang (final boss).
## Node extra fields: act (int), enc (encounter id / random_normal / random_duo).
## v4.0: pos is a FRACTION (0..1) of the top-down map bg (map-topdown.webp).
## MapScreen converts fractions -> viewport via the bg's COVERED rect, so nodes
## sit on the painted path at any aspect ratio.
func build_story1_map() -> void:
	nodes.clear()
	# Act 1 — The Green Forest (village -> bamboo forest -> bridge)
	# v4.0.1: respread along the painted trail; every pair >= ~70px @1280x720.
	_add(_mk("start", "START", 0.20, 0.74, "Forest Gate", ["f1"]))
	_add(_mk("f1", "BATTLE", 0.31, 0.75, "Bamboo Grove", ["f2a", "f2b"]))
	_add(_mk("f2a", "BATTLE", 0.40, 0.685, "Old Banyan", ["f3"]))
	_add(_mk("f2b", "EVENT", 0.425, 0.775, "Woodcutter's Hut", ["f3"]))
	_add(_mk("f3", "SHOP", 0.49, 0.66, "Forest Market", ["f4a", "f4b"]))
	_add(_mk("f4a", "BATTLE", 0.53, 0.60, "Timber Trail", ["ly"]))
	_add(_mk("f4b", "BATTLE", 0.535, 0.715, "Deep Woods", ["ly"]))
	_add(_mk("ly", "ELITE", 0.585, 0.65, "Ly Thong's Camp", ["cave"], 0, "Elite: Ly Thong!"))
	_add(_mk("cave", "BOSS", 0.575, 0.545, "Python Cave", ["rest1"], 0, "Mid-boss: Chan Tinh"))
	# Act 2 — Palace Road & Border (bridge -> fortress)
	_add(_mk("rest1", "REST", 0.59, 0.445, "Mountain Spring", ["p1a", "p1b"], 0, "Rest & heal"))
	_add(_mk("p1a", "BATTLE", 0.625, 0.385, "Palace Road", ["p2"]))
	_add(_mk("p1b", "EVENT", 0.675, 0.42, "Village Under Siege", ["p2"]))
	_add(_mk("p2", "SHOP", 0.665, 0.325, "Capital Market", ["rest2"]))
	_add(_mk("rest2", "REST", 0.705, 0.27, "Border Camp", ["boss"], 0, "Rest & heal"))
	_add(_mk("boss", "BOSS", 0.745, 0.21, "Eagle Peak", []))
	# Encounters + acts
	(nodes["f1"] as Dictionary)["enc"] = "wild_boar"
	(nodes["f2a"] as Dictionary)["enc"] = "forest_viper"
	(nodes["f4a"] as Dictionary)["enc"] = "timber_bandit"
	(nodes["f4b"] as Dictionary)["enc"] = "random_duo"
	(nodes["ly"] as Dictionary)["enc"] = "ly_thong"
	(nodes["cave"] as Dictionary)["enc"] = "chan_tinh"
	(nodes["p1a"] as Dictionary)["enc"] = "random_duo"
	(nodes["boss"] as Dictionary)["enc"] = "dai_bang"
	for id in ["start", "f1", "f2a", "f2b", "f3", "f4a", "f4b", "ly", "cave"]:
		(nodes[id] as Dictionary)["act"] = 1
	for id in ["rest1", "p1a", "p1b", "p2", "rest2", "boss"]:
		(nodes[id] as Dictionary)["act"] = 2
	# Build incoming links
	for id in nodes:
		for oid in (nodes[id] as Dictionary)["out"]:
			(nodes[oid] as Dictionary)["in"].append(id)
	current_id = "start"
	(nodes["start"] as Dictionary)["state"] = S_CURRENT
	_update_available()
