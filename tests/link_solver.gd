extends RefCounted
## Minimum solutions for monuments with Spatial Links, over the real runtime. A state is (one
## state per rotor, occupied piece, doorway stood at, active link pair). Walking to a neighbouring
## piece or into a doorway's reach is free; turning a rotor one step, making a link and crossing
## one each cost 1. A turned rotor carries a player on it, so the piece stays the same.
## Sight is measured only from link poses: walkable points within a doorway's reach where the
## runtime itself makes that doorway the source. A link the solver uses is one a player can make.
const StateGraph = preload("res://tests/state_graph.gd")
const STEP := 2.0

## Per configuration, which doorways each doorway can link to: {config: {source: [targets]}}.
## Each doorway must have at least one link pose; otherwise `failures` says so.
static func survey(g: Node3D, failures: Array[String]) -> Dictionary:
	var original: Array = g.rigs.map(func(entry): return entry.state)
	var table := {}
	for config in configs(g):
		StateGraph.set_states(g, config)
		var sight := {}
		for source in g.thresholds:
			var poses := link_poses(g, source)
			if poses.is_empty(): failures.append("No pose links from %s (configuration %s)" % [g.threshold_label(source), config])
			var targets: Array = []
			for pose in poses:
				g.walker.place(pose[0], pose[1], Vector3.UP, Vector3.RIGHT)
				g.walker.sync_pose(1)
				for target in g.thresholds:
					if target != source and not target in targets and g.compatible(source, target) and g.threshold_seen(target, false): targets.append(target)
			sight[source] = targets
		table[config] = sight
	StateGraph.set_states(g, original)
	return table

## Walkable points on a doorway's piece where standing makes it the link source.
static func link_poses(g: Node3D, source: String) -> Array:
	var c: Node3D = g.thresholds[source]
	var part: SurfacePiece = g.paths[c.get_node(c.path)]
	var poses: Array = []
	for region in part.walk_regions:
		for ix in range(int(region.size.x / STEP) + 1):
			for iz in range(int(region.size.y / STEP) + 1):
				var point := Vector3(region.position.x + ix * STEP, part.half.y, region.position.y + iz * STEP)
				if not part.allows_point(point, Vector3.UP) or not g.walker.pose_is_clear(part, point, Vector3.UP): continue
				g.walker.place(part, point, Vector3.UP, Vector3.RIGHT)
				g.walker.sync_pose(1)
				if g.link_source() == source: poses.append([part, point])
	return poses

static func configs(g: Node3D) -> Array:
	var result: Array = [[]]
	for entry in g.rigs:
		var grown: Array = []
		for config in result:
			for state in range(g.state_count(entry)): grown.append(config + [state])
		result = grown
	return result

## The cheapest route from the start piece (in the current configuration) to the goal piece:
## {"cost", "turns", "links", "crosses", "route"}, or {"cost": -1} when there is none.
static func minimum(g: Node3D, sight: Dictionary, start_piece: SurfacePiece, goal_piece: SurfacePiece, links_allowed := true, turns_allowed := true) -> Dictionary:
	var adjacency := StateGraph.adjacency(g)
	var home: Dictionary = {}
	for id in g.thresholds: home[id] = g.pieces.find(g.paths[g.thresholds[id].get_node(g.thresholds[id].path)])
	var goal: int = g.pieces.find(goal_piece)
	var start := [g.rigs.map(func(entry): return entry.state), g.pieces.find(start_piece), "", []]
	var done := {}
	var queue: Array = [[0, start, {"turns": 0, "links": 0, "crosses": 0}, []]]
	while not queue.is_empty():
		var item: Array = queue.pop_front()
		var cost: int = item[0]
		var state: Array = item[1]
		var key := str(state)
		if done.has(key): continue
		done[key] = true
		var counts: Dictionary = item[2]
		if state[1] == goal: return {"cost": cost, "turns": counts.turns, "links": counts.links, "crosses": counts.crosses, "route": item[3]}
		var config: Array = state[0]
		var moves: Array = []
		for other in adjacency[config][state[1]]:
			moves.append([0, [config, other, "", state[3]], {}, "walk to %s" % g.pieces[other].get_parent().name])
		for id in home:
			if home[id] == state[1] and state[2] != id: moves.append([0, [config, state[1], id, state[3]], {}, "stand at " + g.threshold_label(id)])
		if turns_allowed:
			for k in range(g.rigs.size()):
				for direction in [-1, 1]:
					var turned: Array = config.duplicate()
					turned[k] = g.next_state(g.rigs[k], turned[k], direction)
					if turned[k] == config[k]: continue
					moves.append([1, [turned, state[1], state[2], state[3]], {"turns": 1}, "turn %s to %d" % [g.rigs[k].node.name, turned[k]]])
		if links_allowed and state[2] != "":
			for target in sight[config].get(state[2], []):
				var pair: Array = [state[2], target]
				pair.sort()
				if pair != state[3]: moves.append([1, [config, state[1], state[2], pair], {"links": 1}, "link %s to %s" % [g.threshold_label(state[2]), g.threshold_label(target)]])
		if state[2] != "" and state[2] in state[3]:
			var other: String = state[3][0] if state[3][1] == state[2] else state[3][1]
			moves.append([1, [config, home[other], other, state[3]], {"crosses": 1}, "cross to " + g.threshold_label(other)])
		for move in moves:
			var next_counts: Dictionary = counts.duplicate()
			for k in move[2]: next_counts[k] += move[2][k]
			var entry := [cost + move[0], move[1], next_counts, item[3] + [move[3]]]
			# The queue stays ordered by cost.
			queue.insert(queue.bsearch_custom(entry, func(x, y): return x[0] < y[0], false), entry)
	return {"cost": -1}
