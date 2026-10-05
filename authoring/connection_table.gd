@tool
extends RefCounted
## What joins, per structure state, for the Elsewhere dock (docs/designing-a-puzzle.md). Pure
## reads of socket descriptors on a level whose structures are posed here; shared by the editor
## and the tests. It never plans or solves: it answers "what is joined now?" and "what does each
## state of this structure change?".
const C = preload("res://authoring/component.gd")
const Links = preload("res://authoring/connections.gd")

static func label(c: Node) -> String:
	return c.label if c is C and not c.label.is_empty() else str(c.name)

static func structures(level: Node3D) -> Array:
	return level.components().filter(func(c): return c.kind == C.Kind.ROTATOR)

## Poses every structure: `states` and `bases` are keyed by path from the level; a structure
## without an entry keeps its initial state.
static func pose(level: Node3D, states: Dictionary, bases: Dictionary) -> void:
	for c in structures(level):
		var id := str(level.get_path_to(c))
		var base: Transform3D = bases.get(id, c.transform)
		c.transform = c.state_local_transform(base, clampi(states.get(id, c.initial_state), 0, c.state_count() - 1))

## Joined path pairs in the current pose, as sorted [label, label] pairs.
static func join_nodes(level: Node3D) -> Array:
	var sockets := Links.descriptors(level)
	var result: Array = []
	for i in range(sockets.size()):
		for j in range(i + 1, sockets.size()):
			if Links.compatible(sockets[i], sockets[j]):
				var pair: Array = [sockets[i].path, sockets[j].path]
				if not pair in result and not [pair[1], pair[0]] in result: result.append(pair)
	return result

static func joins(level: Node3D) -> Array:
	var result: Array = []
	for pair in join_nodes(level):
		var named: Array = [label(pair[0]), label(pair[1])]
		named.sort()
		if not named in result: result.append(named)
	result.sort()
	return result

## One row per state of `structure`: {state, name, joins, added, removed, unchanged, stranded}.
## Added/removed/unchanged compare with the current `states`. Stranded lists paths that join
## nothing in that state but do join something in another state of this structure.
static func by_state(level: Node3D, structure: Node3D, states: Dictionary, bases: Dictionary) -> Array:
	var id := str(level.get_path_to(structure))
	pose(level, states, bases)
	var current := joins(level)
	var rows: Array = []
	var ever_joined := {}
	for state in range(structure.state_count()):
		var trial := states.duplicate()
		trial[id] = state
		pose(level, trial, bases)
		var now := joins(level)
		for pair in now:
			ever_joined[pair[0]] = true; ever_joined[pair[1]] = true
		rows.append({"state": state, "name": structure.state_label(state), "joins": now,
			"added": now.filter(func(pair): return not pair in current),
			"removed": current.filter(func(pair): return not pair in now),
			"unchanged": now.filter(func(pair): return pair in current)})
	for row in rows:
		var joined := {}
		for pair in row.joins:
			joined[pair[0]] = true; joined[pair[1]] = true
		var stranded: Array = ever_joined.keys().filter(func(name): return not joined.has(name))
		stranded.sort()
		row["stranded"] = stranded
	pose(level, states, bases)
	return rows

## Labels of every path joined to `from_path` through the current pose (it included). A flood
## fill over present joins only: no structure moves, nothing is planned.
static func reachable(level: Node3D, from_path: Node3D) -> Array:
	var pairs := join_nodes(level)
	var seen: Array = [from_path]
	var frontier: Array = [from_path]
	while not frontier.is_empty():
		var here = frontier.pop_back()
		for pair in pairs:
			for k in range(2):
				if pair[k] == here and not pair[1 - k] in seen:
					seen.append(pair[1 - k]); frontier.append(pair[1 - k])
	var names: Array = seen.map(label)
	names.sort()
	return names
