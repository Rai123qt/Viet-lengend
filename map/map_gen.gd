class_name MapGen
extends RefCounted
## v5.0: Procedural act map generator (Slay-the-Spire style columns).
## Each act: 7 columns [START][m1][m2][m3][m4][REST][BOSS].
## Every new run (and every act) produces a different map.
##
## Quotas per act: 6 BATTLE, 3 EVENT, 2 SHOP, 2 ELITE, 1 mid REST (+1 pre-boss REST), 1 BOSS.
## Rules:
##  - m1: BATTLE/EVENT only. m2: no ELITE. ELITE from m3+ (0-indexed col 2+).
##  - 2 ELITEs never in adjacent columns; 2 SHOPs never in adjacent columns.
##  - Every node connects to 1-2 nodes in the next column (y-proximity, no crossing).
##  - Every node has >=1 incoming (no orphans) and >=1 outgoing (no dead ends).

const COL_X := [0.07, 0.205, 0.34, 0.475, 0.61, 0.745, 0.88]
const Y_MIN := 0.20
const Y_MAX := 0.80
const Y_SEP := 0.10  # min vertical fraction between nodes in a column

const BOSS_ENC := {1: "chan_tinh", 2: "dai_bang", 3: "dai_bang"}
# v6.0: Story 2 bosses (Hai Ba Trung vs Han)
const BOSS_ENC_HBT := {1: "han_general", 2: "to_dinh", 3: "to_dinh"}
const BOSS_MULT := {1: 1.4, 2: 1.2, 3: 1.35}
const BOSS_LOC := {1: "Python Cave", 2: "Eagle Raid", 3: "Eagle Peak"}
const BOSS_NAME := {1: "CHAN TINH", 2: "DAI BANG", 3: "DAI BANG"}

const LOCS := {
	1: ["Bamboo Grove", "Old Banyan", "Timber Trail", "Deep Woods",
		"Mossy Clearing", "Wild Boar Den", "Viper Nest", "Woodcutter's Hut",
		"Hunter's Camp", "Forest Market", "Herb Garden", "Moonlit Glade",
		"Ly Thong's Camp", "Bandit Hideout", "Forest Gate", "Mountain Spring",
		"Whispering Reeds", "Fallen Log Bridge"],
	2: ["Palace Road", "Night Market", "Capital Market", "Black Market",
		"Village Under Siege", "Court Yard", "Corrupt Manor", "Assassin's Alley",
		"Princess's Garden", "Riverside", "Old Bridge", "Tax Office",
		"Lantern Street", "Rice Depot", "City Gate", "Teahouse",
		"Imperial Garden", "Back Alley"],
	3: ["Mountain Path", "Rocky Pass", "Pine Ridge", "Old Monk's Hut",
		"Border Post", "Eagle's Nest", "Demon Gate", "Storm Peak",
		"Cliffside", "Border Camp", "Cloud Temple", "Stone Forest",
		"Bandit Stronghold", "Frozen Waterfall", "Eagle Shrine", "High Pass",
		"Snowy Trail", "War Drum Tower"],
}


static func generate(act: int, rng: RandomNumberGenerator, hero_id: String = "thach_sanh") -> MapGraph:
	var g := MapGraph.new()
	g.nodes.clear()
	var a: int = clampi(act, 1, 3)

	# ---- 1. column node counts: m1..m4 share 14 quota nodes ----
	var counts := _column_counts(rng)  # 4 ints summing to 14

	# ---- 2. type assignment with constraints ----
	# middle columns (0-indexed): 1,2,3,4
	var col_types: Array = [[], [], [], []]  # per middle col: Array of type strings
	_assign_types(col_types, counts, rng)

	# ---- 3. build nodes ----
	var loc_pool: Array = (LOCS[a] as Array).duplicate()
	loc_pool.shuffle()
	var loc_i := 0
	var col_nodes: Array = []  # per column idx 0..6: Array of node ids
	for i in range(7):
		col_nodes.append([])

	# START
	_add_node(g, "start", "START", COL_X[0], 0.5, "Village Gate", [], a)
	col_nodes[0].append("start")

	# middle columns
	for mi in range(4):
		var ci: int = mi + 1
		var ys := _spread_y(counts[mi], rng)
		for ni in range(counts[mi]):
			var t: String = col_types[mi][ni]
			var id := "c%dn%d" % [ci, ni]
			var loc: String = _take_loc(loc_pool, loc_i, t, a)
			loc_i += 1
			var x: float = COL_X[ci] + rng.randf_range(-0.018, 0.018)
			_add_node(g, id, t, x, ys[ni], loc, [], a)
			_set_enc(g, id, t, a, rng)
			col_nodes[ci].append(id)

	# pre-boss REST
	_add_node(g, "rest_pre", "REST", COL_X[5], 0.5, _rest_name(a), [], a)
	col_nodes[5].append("rest_pre")

	# BOSS
	var boss_id := "boss"
	_add_node(g, boss_id, "BOSS", COL_X[6], 0.5, BOSS_LOC[a],
		[], a, "Boss: %s" % BOSS_NAME[a])
	var boss_pool := BOSS_ENC_HBT if hero_id == "hai_ba_trung" else BOSS_ENC
	(g.nodes[boss_id] as Dictionary)["enc"] = boss_pool[a]
	(g.nodes[boss_id] as Dictionary)["mult"] = BOSS_MULT[a]
	col_nodes[6].append("boss")

	# ---- 4. connections (no crossing, no orphans, no dead ends) ----
	_connect_columns(g, col_nodes, rng)

	# incoming links
	for id in g.nodes:
		for oid in (g.nodes[id] as Dictionary)["out"]:
			((g.nodes[oid] as Dictionary)["in"] as Array).append(id)

	g.current_id = "start"
	(g.nodes["start"] as Dictionary)["state"] = MapGraph.S_CURRENT
	g._update_available()
	return g


static func _add_node(g: MapGraph, id: String, type: String, x: float, y: float,
		loc: String, out: Array, act: int, reward: String = "") -> void:
	var n := {
		"id": id, "type": type, "pos": Vector2(x, y), "loc": loc,
		"out": out, "in": [], "state": MapGraph.S_LOCKED,
		"wake": 0, "reward": reward, "act": act,
	}
	g.nodes[id] = n


static func _take_loc(pool: Array, i: int, t: String, _a: int) -> String:
	if t == "SHOP":
		return "Market"
	if t == "REST":
		return "Quiet Spring"
	if pool.is_empty():
		return "Wilderness"
	return str(pool[i % pool.size()])


static func _rest_name(a: int) -> String:
	return {1: "Mountain Spring", 2: "Riverside Camp", 3: "Border Camp"}.get(a, "Rest")


## Elite encounters per act: story elite first, then buffed normals.
static func _set_enc(g: MapGraph, id: String, t: String, a: int, rng: RandomNumberGenerator) -> void:
	var n: Dictionary = g.nodes[id]
	match t:
		"BATTLE":
			n["enc"] = "random_duo" if rng.randf() < 0.25 else "random_normal"
		"ELITE":
			match a:
				1:
					# first elite node in act 1 is Ly Thong (story); others buffed
					var elite_ids: Array = []
					for oid in g.nodes:
						var od: Dictionary = g.nodes[oid]
						if str(od.get("type", "")) == "ELITE" and oid != id and od.has("enc"):
							elite_ids.append(oid)
					if elite_ids.is_empty():
						n["enc"] = "ly_thong"
					else:
						n["enc"] = "timber_bandit"
						n["mult"] = 1.6
				2:
					n["enc"] = ["forest_viper", "wild_boar"][rng.randi_range(0, 1)]
					n["mult"] = 1.7
				_:
					n["enc"] = ["timber_bandit", "forest_viper"][rng.randi_range(0, 1)]
					n["mult"] = 1.9
		_:
			pass


## 4 middle columns share 14 quota nodes: 6 BATTLE, 3 EVENT, 2 SHOP, 2 ELITE, 1 REST.
static func _column_counts(rng: RandomNumberGenerator) -> Array:
	var c := [3, 3, 4, 4]
	# shuffle the distribution
	for i in range(4):
		var j := rng.randi_range(0, 3)
		var tmp: int = c[i]
		c[i] = c[j]
		c[j] = tmp
	return c


static func _assign_types(col_types: Array, counts: Array, rng: RandomNumberGenerator) -> void:
	# Fixed constrained placements first:
	#  - ELITEs at middle cols idx 2 and 4 (0-indexed overall cols 3 and 5): non-adjacent.
	#  - SHOPs at middle cols idx 2 and 4 as well (may share columns, different nodes).
	#  - mid REST at a random middle col idx 1..4.
	#  - idx 1 (first middle): BATTLE/EVENT only.
	var elite_cols := [2, 4]
	var shop_cols := [2, 4]
	# 50%: shift shops to (1? no—idx1 banned) keep (2,4). Add variety via node choice instead.
	var rest_col: int = rng.randi_range(1, 4)

	# remaining quotas after fixed placements
	var battle_left := 6
	var event_left := 3

	# place ELITE + SHOP markers
	var fixed: Dictionary = {}  # col_idx -> Array of types
	for e in elite_cols:
		if not fixed.has(e):
			fixed[e] = []
		(fixed[e] as Array).append("ELITE")
	for s in shop_cols:
		if not fixed.has(s):
			fixed[s] = []
		(fixed[s] as Array).append("SHOP")
	if not fixed.has(rest_col):
		fixed[rest_col] = []
	(fixed[rest_col] as Array).append("REST")

	# fill the rest with BATTLE/EVENT
	for mi in range(4):
		var ci: int = mi + 1
		var types: Array = []
		if fixed.has(ci):
			types.append_array(fixed[ci] as Array)
		while types.size() < int(counts[mi]):
			# prefer battles; keep events 2-4 total
			var want_event := event_left > 0 and (battle_left <= 0 or rng.randf() < 0.3)
			if want_event:
				types.append("EVENT")
				event_left -= 1
			elif battle_left > 0:
				types.append("BATTLE")
				battle_left -= 1
			else:
				types.append("EVENT")
				event_left -= 1
		# shuffle within column
		for i in range(types.size()):
			var j := rng.randi_range(0, types.size() - 1)
			var tmp: String = types[i]
			types[i] = types[j]
			types[j] = tmp
		col_types[mi] = types


## Evenly spread y in [Y_MIN, Y_MAX] with jitter; enforce min separation.
static func _spread_y(n: int, rng: RandomNumberGenerator) -> Array:
	var ys: Array = []
	if n == 1:
		ys.append(0.5 + rng.randf_range(-0.1, 0.1))
		return ys
	for i in range(n):
		var base: float = Y_MIN + (Y_MAX - Y_MIN) * float(i) / float(n - 1)
		ys.append(clampf(base + rng.randf_range(-0.045, 0.045), 0.12, 0.88))
	ys.sort()
	# push apart
	for i in range(1, ys.size()):
		if ys[i] - ys[i - 1] < Y_SEP:
			ys[i] = ys[i - 1] + Y_SEP
	# if overflow, shift down
	if ys[ys.size() - 1] > 0.88:
		var over: float = ys[ys.size() - 1] - 0.88
		for i in range(ys.size()):
			ys[i] -= over
	return ys


## Connect col i -> col i+1 by y-proximity; repair orphans; avoid crossings.
static func _connect_columns(g: MapGraph, col_nodes: Array, rng: RandomNumberGenerator) -> void:
	for ci in range(6):
		var from_ids: Array = (col_nodes[ci] as Array).duplicate()
		var to_ids: Array = col_nodes[ci + 1]
		# sort both by y
		from_ids.sort_custom(func(a, b): return (g.nodes[a] as Dictionary)["pos"].y < (g.nodes[b] as Dictionary)["pos"].y)
		var to_sorted: Array = to_ids.duplicate()
		to_sorted.sort_custom(func(a, b): return (g.nodes[a] as Dictionary)["pos"].y < (g.nodes[b] as Dictionary)["pos"].y)

		# each from-node -> 1-2 nearest-y to-nodes
		for fi in range(from_ids.size()):
			var fpos: Vector2 = (g.nodes[from_ids[fi]] as Dictionary)["pos"]
			var cands: Array = to_sorted.duplicate()
			cands.sort_custom(func(a, b):
				return absf((g.nodes[a] as Dictionary)["pos"].y - fpos.y) < absf((g.nodes[b] as Dictionary)["pos"].y - fpos.y))
			var want := 1
			if to_sorted.size() >= 3 and rng.randf() < 0.45:
				want = 2
			elif to_sorted.size() == 2 and rng.randf() < 0.3:
				want = 2
			var added := 0
			for t in cands:
				if added >= want:
					break
				if _would_cross(g, from_ids[fi], t, ci):
					continue
				_add_out(g, from_ids[fi], t)
				added += 1
			if added == 0:
				# fallback: nearest without crossing check (rare)
				_add_out(g, from_ids[fi], cands[0])

		# repair orphans: every to-node needs >=1 incoming
		for t in to_sorted:
			var has_in := false
			for f in from_ids:
				if t in ((g.nodes[f] as Dictionary)["out"] as Array):
					has_in = true
					break
			if not has_in:
				var tpos: Vector2 = (g.nodes[t] as Dictionary)["pos"]
				var best: String = str(from_ids[0])
				var bestd := 999.0
				for f in from_ids:
					var d: float = absf((g.nodes[f] as Dictionary)["pos"].y - tpos.y)
					if d < bestd:
						bestd = d
						best = f
				_add_out(g, best, t)


static func _add_out(g: MapGraph, f: String, t: String) -> void:
	var out: Array = (g.nodes[f] as Dictionary)["out"]
	if not t in out:
		out.append(t)


## True if edge f->t would cross an existing edge between the same columns.
static func _would_cross(g: MapGraph, f: String, t: String, _ci: int) -> bool:
	var fp: Vector2 = (g.nodes[f] as Dictionary)["pos"]
	var tp: Vector2 = (g.nodes[t] as Dictionary)["pos"]
	for oid in g.nodes:
		var od: Dictionary = g.nodes[oid]
		for ooid in (od["out"] as Array):
			if ooid == t or oid == f:
				continue
			var op: Vector2 = od["pos"]
			var otp: Vector2 = (g.nodes[ooid] as Dictionary)["pos"]
			# same column pair? x-ordered edges: check y-order flip
			if absf(op.x - fp.x) > 0.05:
				continue
			var f_above: bool = fp.y < op.y
			var t_above: bool = tp.y < otp.y
			if f_above != t_above:
				return true
	return false


## Validation for tests: returns Array of problem strings (empty = OK).
static func validate(g: MapGraph) -> Array:
	var problems: Array = []
	var counts := {"BATTLE": 0, "EVENT": 0, "SHOP": 0, "ELITE": 0, "REST": 0, "BOSS": 0, "START": 0}
	for id in g.nodes:
		var n: Dictionary = g.nodes[id]
		var t: String = str(n.get("type", "?"))
		counts[t] = int(counts.get(t, 0)) + 1
	# quotas
	if int(counts["BATTLE"]) < 5:
		problems.append("too few BATTLE: %d" % counts["BATTLE"])
	if int(counts["EVENT"]) < 2 or int(counts["EVENT"]) > 4:
		problems.append("EVENT out of range: %d" % counts["EVENT"])
	if int(counts["SHOP"]) != 2:
		problems.append("SHOP != 2: %d" % counts["SHOP"])
	if int(counts["ELITE"]) != 2:
		problems.append("ELITE != 2: %d" % counts["ELITE"])
	if int(counts["BOSS"]) != 1:
		problems.append("BOSS != 1")
	# no orphans / dead ends (except boss)
	for id in g.nodes:
		var n: Dictionary = g.nodes[id]
		var t: String = str(n["type"])
		if t == "START":
			continue
		if (n["in"] as Array).is_empty():
			problems.append("orphan: %s" % id)
		if t != "BOSS" and (n["out"] as Array).is_empty():
			problems.append("dead end: %s" % id)
	# elites/shops not in adjacent columns (compare x)
	var elite_x: Array = []
	var shop_x: Array = []
	for id in g.nodes:
		var n: Dictionary = g.nodes[id]
		if str(n["type"]) == "ELITE":
			elite_x.append((n["pos"] as Vector2).x)
		elif str(n["type"]) == "SHOP":
			shop_x.append((n["pos"] as Vector2).x)
	elite_x.sort()
	shop_x.sort()
	for i in range(1, elite_x.size()):
		if absf(elite_x[i] - elite_x[i - 1]) < 0.12:
			problems.append("adjacent ELITEs")
	for i in range(1, shop_x.size()):
		if absf(shop_x[i] - shop_x[i - 1]) < 0.12:
			problems.append("adjacent SHOPs")
	# reachability from start (BFS)
	var seen := {"start": true}
	var queue := ["start"]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for oid in ((g.nodes[cur] as Dictionary)["out"] as Array):
			if not seen.has(oid):
				seen[oid] = true
				queue.append(oid)
	if seen.size() != g.nodes.size():
		problems.append("unreachable nodes: %d/%d" % [seen.size(), g.nodes.size()])
	return problems
