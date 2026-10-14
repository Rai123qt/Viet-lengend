extends SceneTree
## v5.0: validate MapGen across acts and seeds.

func _initialize() -> void:
	var fails := 0
	for act in [1, 2, 3]:
		for seed in [11, 22, 33, 44, 55]:
			var rng := RandomNumberGenerator.new()
			rng.seed = seed * 1000 + act
			var g: MapGraph = MapGen.generate(act, rng)
			var problems: Array = MapGen.validate(g)
			# count types
			var tc := {"BATTLE": 0, "EVENT": 0, "SHOP": 0, "ELITE": 0, "REST": 0}
			for id in g.nodes:
				var t: String = str((g.nodes[id] as Dictionary).get("type", ""))
				if tc.has(t):
					tc[t] = int(tc[t]) + 1
			var status := "OK" if problems.is_empty() else "FAIL"
			if not problems.is_empty():
				fails += 1
			print("act=%d seed=%d nodes=%d %s types=%s problems=%s" % [
				act, seed, g.nodes.size(), status, str(tc), str(problems)])
	# travel test: walk start -> boss on one map
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 777
	var g2: MapGraph = MapGen.generate(1, rng2)
	var steps := 0
	while g2.current_id != "boss" and steps < 30:
		var cur: Dictionary = g2.get_node(g2.current_id)
		var outs: Array = cur.get("out", [])
		if outs.is_empty():
			break
		# travel to first available
		var moved := false
		for oid in outs:
			if g2.travel_to(str(oid)):
				moved = true
				break
		if not moved:
			break
		steps += 1
	print("travel test: reached=%s steps=%d" % [g2.current_id, steps])
	if g2.current_id != "boss":
		fails += 1
		print("TRAVEL FAIL")
	print("MAPGEN TEST fails=%d" % fails)
	quit(1 if fails > 0 else 0)
