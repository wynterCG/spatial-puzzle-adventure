extends RefCounted
## Puzzle state graph over the real runtime: (one state per rotor, occupied path piece).
## Moves are a single-step turn of any rotor (a carried player stays on the same piece) or a
## step onto a neighbouring piece in the current configuration. Used to pin solution minima so
## a future socket or geometry change cannot silently introduce a shortcut.

## Neighbour lists for every rotor configuration, read from update_links() on the live runtime.
static func adjacency(g: Node3D) -> Dictionary:
	var original: Array = g.rigs.map(func(entry): return entry.state)
	var configs: Array = [[]]
	for entry in g.rigs:
		var next: Array = []
		for config in configs:
			for state in range(entry.angles.size()): next.append(config + [state])
		configs = next
	var table := {}
	for config in configs:
		set_states(g, config)
		var links := {}
		for i in range(g.pieces.size()):
			links[i] = g.pieces[i].neighbours.map(func(other): return g.pieces.find(other))
		table[config] = links
	set_states(g, original)
	return table

static func set_states(g: Node3D, config: Array) -> void:
	for k in range(g.rigs.size()):
		var entry: Dictionary = g.rigs[k]
		entry.state = config[k]
		entry.node.basis = g.rotation_basis(entry, deg_to_rad(entry.angles[config[k]]))
	g.update_links()

## Minimum cost from the start configuration and piece to the goal piece, or -1 if unreachable.
## A 0-1 search: costs are 0 or 1 per move kind (turn_cost, walk_cost). `rotors` limits which
## rotors may turn (empty: all), to show that a solution needs a structure.
static func minimum(g: Node3D, table: Dictionary, start_config: Array, start_piece: SurfacePiece, goal_piece: SurfacePiece, turn_cost: int, walk_cost: int, rotors: Array = []) -> int:
	var start: Array = [start_config, g.pieces.find(start_piece)]
	var goal: int = g.pieces.find(goal_piece)
	var best := {str(start): 0}
	var queue: Array = [start]
	while not queue.is_empty():
		var current: Array = queue.pop_front()
		var cost: int = best[str(current)]
		if current[1] == goal: return cost
		var moves: Array = []
		for k in range(g.rigs.size()):
			if not rotors.is_empty() and not k in rotors: continue
			for direction in [-1, 1]:
				var config: Array = current[0].duplicate()
				config[k] = posmod(config[k] + direction, g.rigs[k].angles.size())
				moves.append([[config, current[1]], turn_cost])
		for other in table[current[0]][current[1]]:
			moves.append([[current[0], other], walk_cost])
		for move in moves:
			var key := str(move[0])
			var next_cost: int = cost + move[1]
			if best.has(key) and best[key] <= next_cost: continue
			best[key] = next_cost
			if move[1] == 0: queue.push_front(move[0])
			else: queue.push_back(move[0])
	return -1
