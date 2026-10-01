extends RefCounted
## The Threshold (monuments/the_threshold.tscn, tools/gen_threshold.py,
## docs/designs/2026-10-01-the-threshold.md): its sight lines in every sleeve state, both
## solutions played through the runtime, the dead ends and the solver's minimum.
const L = preload("res://tests/link_tests.gd")
const H = preload("res://tests/test_helpers.gd")
const Validate = preload("res://authoring/validation.gd")
const SpatialLinks = preload("res://core/spatial_links.gd")
const StateGraph = preload("res://tests/state_graph.gd")
const LinkSolver = preload("res://tests/link_solver.gd")
const THRESHOLD := "res://monuments/the_threshold.tscn"
const OUTSIDE := ["Entry", "Sleeve/Ledge"]
const INSIDE := ["Core/SlabTop", "Core/SlabCurl", "Core/SlabUnder", "Balcony"]

static func run(g: Node3D, failures: Array[String]) -> void:
	L.load_fold(g, THRESHOLD)
	if not Validate.validate(g.definition).errors.is_empty(): failures.append("The Threshold must validate: " + str(Validate.validate(g.definition).errors))
	closed_cases(g, failures)
	sight_cases(g, failures)
	beam_cases(g, failures)
	solution(g, failures)
	alternative(g, failures)
	dead_end(g, failures)
	solver(g, failures)

static func piece(g: Node3D, path: String) -> SurfacePiece:
	return g.paths[g.definition.get_node(path)]

static func label(g: Node3D, id: String) -> String:
	return g.threshold_label(id)

static func set_sleeve(g: Node3D, state: int) -> void:
	StateGraph.set_states(g, [state])

## No ordinary path ever joins the core or the balcony to the outside, in any state.
static func closed_cases(g: Node3D, failures: Array[String]) -> void:
	var table := StateGraph.adjacency(g)
	var outside: Array = OUTSIDE.map(func(name): return g.pieces.find(piece(g, name)))
	var inside: Array = INSIDE.map(func(name): return g.pieces.find(piece(g, name)))
	for config in table:
		for i in outside:
			for other in table[config][i]:
				if other in inside: failures.append("The Threshold: an ordinary path joins outside and inside in state %s" % config)
		if not table[config][g.pieces.find(piece(g, "Balcony"))].is_empty(): failures.append("The Threshold: the balcony is reached only through a link")
		var entry_docked: bool = g.pieces.find(piece(g, "Sleeve/Ledge")) in table[config][outside[0]]
		if entry_docked != (config == [0]): failures.append("The Threshold: the ledge docks with the entry only in state 0 (state %s)" % config)

## Which doorways can be seen from anywhere walkable on a piece, per sleeve state:
## {"state piece label": true}. Looking anywhere (the player can turn).
static func piece_sight(g: Node3D, names: Array) -> Dictionary:
	var table := {}
	for state in range(4):
		set_sleeve(g, state)
		for name in names:
			var part := piece(g, name)
			for region in part.walk_regions:
				for ix in range(int(region.size.x / 2.0) + 1):
					for iz in range(int(region.size.y / 2.0) + 1):
						g.walker.place(part, Vector3(region.position.x + ix * 2.0, part.half.y, region.position.y + iz * 2.0), Vector3.UP, Vector3.RIGHT)
						g.walker.sync_pose(1)
						for id in g.thresholds:
							if g.threshold_seen(id, false): table["%d %s %s" % [state, name.get_file(), label(g, id)]] = true
	set_sleeve(g, 0)
	return table

## The puzzle is its sight lines: each link is possible from one place, in one state.
static func sight_cases(g: Node3D, failures: Array[String]) -> void:
	var survey := LinkSolver.survey(g, failures)
	for state in range(4):
		var links := {}
		for source in survey[[state]]:
			links[label(g, source)] = survey[[state]][source].map(func(id): return label(g, id))
		if ("Ledge door" in links["Gate"]) != (state == 0): failures.append("The Threshold: the Gate sees the Ledge door only in state 0 (state %d)" % state)
		if ("Under door" in links["Ledge door"]) != (state == 1): failures.append("The Threshold: the Ledge door sees the Under door only in state 1 (state %d)" % state)
		if ("Balcony door" in links["High door"]) != (state == 3): failures.append("The Threshold: the High door sees the Balcony door only in state 3 (state %d)" % state)
	var seen := piece_sight(g, ["Entry", "Sleeve/Ledge", "Core/SlabUnder"])
	for state in range(4):
		for name in ["Entry", "Ledge"]:
			for door in ["High door", "Balcony door"]:
				if seen.has("%d %s %s" % [state, name, door]): failures.append("The Threshold: the %s is never seen from the %s (state %d)" % [door, name, state])
		if seen.has("%d Entry Under door" % state): failures.append("The Threshold: the Under door is never seen from the entry (state %d)" % state)
		if seen.has("%d Ledge Under door" % state) != (state == 1): failures.append("The Threshold: the Under door is seen from the ledge only in state 1 (state %d)" % state)
		if seen.has("%d SlabUnder Balcony door" % state): failures.append("The Threshold: the Balcony door is never seen from the slab underside (state %d)" % state)

## The goal beam frames the problem from the start, whatever the sleeve's state: its upper part
## rises clear above the sleeve and the core.
static func beam_cases(g: Node3D, failures: Array[String]) -> void:
	L.load_fold(g, THRESHOLD)
	g.walker.sync_pose(1)
	var eye: Vector3 = g.walker.camera.global_position
	var shaft: MeshInstance3D = g.definition.get_node("Balcony/Goal/LightShaft")
	var beam: Vector3 = shaft.global_position + Vector3.UP * shaft.mesh.size.y * .35
	for state in range(4):
		set_sleeve(g, state)
		var solids: Array = g.obstacles.duplicate()
		for part in g.pieces: solids.append_array(part.solid_meshes)
		if not SpatialLinks.visible(eye, beam, solids, []): failures.append("The Threshold: the goal beam is seen from the start (state %d)" % state)
	set_sleeve(g, 0)

static func walk_until(g: Node3D, done: Callable, frames := 1200) -> bool:
	for i in range(frames):
		g.walker.walk(Vector2(0, -1), 1.0 / 60)
		if not g.won and g.reached_goal(): g._process(0)
		if done.call(): return true
	return false

## Aims at a doorway from where the player stands and links to it with one press.
static func link_to(g: Node3D, target: String) -> void:
	g.architectural = false
	L.look_at_point(g, L.door_centre(g, target))
	g.update_link_view()
	g.use_threshold()

## The intended solution: ride, link in, curl up, turn from inside, link out.
static func solution(g: Node3D, failures: Array[String]) -> void:
	L.load_fold(g, THRESHOLD)
	var ledge := piece(g, "Sleeve/Ledge")
	var under := piece(g, "Core/SlabUnder")
	var top := piece(g, "Core/SlabTop")
	g.architectural = false
	g.walker.forward = Vector3.RIGHT
	g.walker.pitch = 0
	if not walk_until(g, func(): return g.walker.support == ledge): failures.append("The Threshold: the entry leads onto the docked ledge")
	g.walker.place(ledge, Vector3(H.m(.3), ledge.half.y, 0), Vector3.UP, Vector3.RIGHT)
	H.turn(g, 0, 1, failures)
	if g.walker.support != ledge: failures.append("The Threshold: the ledge carries the player round")
	link_to(g, "Under door")
	if g.link != [L.door(g, "Ledge door"), L.door(g, "Under door")]: failures.append("The Threshold: in state 1 the Ledge door links to the Under door: " + str(g.link))
	g.walker.forward = Vector3.RIGHT
	g.walker.pitch = 0
	if not walk_until(g, func(): return g.walker.support == under): failures.append("The Threshold: the Ledge door leads under the slab")
	elif (under.global_basis * g.walker.normal).normalized().dot(Vector3.DOWN) < .99: failures.append("The Threshold: the player arrives upside down")
	# Clear of the doorway, then west along the underside, over the curl, onto the top.
	for i in range(60): g.walker.walk(Vector2(0, -1), 1.0 / 60)
	g.walker.forward = (under.global_basis.inverse() * Vector3.LEFT).normalized()
	if not walk_until(g, func(): return g.walker.support == top): failures.append("The Threshold: the curl leads from the underside onto the slab top")
	if not walk_until(g, func(): return g.link_source() == L.door(g, "High door")): failures.append("The Threshold: the slab top leads to the High door")
	H.turn(g, 0, 1, failures)
	H.turn(g, 0, 1, failures)
	link_to(g, "Balcony door")
	if g.link != [L.door(g, "High door"), L.door(g, "Balcony door")]: failures.append("The Threshold: in state 3 the High door links to the Balcony door: " + str(g.link))
	g.walker.forward = Vector3.RIGHT
	g.walker.pitch = 0
	if not walk_until(g, func(): return g.won) or g.walker.support != piece(g, "Balcony"): failures.append("The Threshold: the High door leads to the balcony and its light")

## The other order: link the Gate first, turn, then come out of the Ledge door on its new side.
static func alternative(g: Node3D, failures: Array[String]) -> void:
	L.load_fold(g, THRESHOLD)
	var entry := piece(g, "Entry")
	var ledge := piece(g, "Sleeve/Ledge")
	g.walker.place(entry, Vector3(-H.m(3), entry.half.y, 0), Vector3.UP, Vector3.RIGHT)
	link_to(g, "Ledge door")
	if g.link != [L.door(g, "Gate"), L.door(g, "Ledge door")]: failures.append("The Threshold: from the Gate, the Ledge door can be linked in state 0")
	H.turn(g, 0, 1, failures)
	g.architectural = false
	g.walker.place(entry, Vector3(-H.m(3), entry.half.y, 0), Vector3.UP, Vector3.LEFT)
	g.walker.forward = Vector3.LEFT
	g.walker.pitch = 0
	if not walk_until(g, func(): return g.walker.support == ledge): failures.append("The Threshold: after turning, the Gate still leads to the Ledge door")
	link_to(g, "Under door")
	if g.link != [L.door(g, "Ledge door"), L.door(g, "Under door")]: failures.append("The Threshold: arriving by the Gate, the Under door can be linked")
	g.walker.forward = Vector3.RIGHT
	g.walker.pitch = 0
	if not walk_until(g, func(): return g.walker.support == piece(g, "Core/SlabUnder")): failures.append("The Threshold: the alternative order reaches the core")

## Turning from the entry strands the ledge; turning back docks it again.
static func dead_end(g: Node3D, failures: Array[String]) -> void:
	L.load_fold(g, THRESHOLD)
	var entry := piece(g, "Entry")
	H.turn(g, 0, 1, failures)
	if not entry.neighbours.is_empty(): failures.append("The Threshold: turned away, the ledge leaves the entry")
	H.turn(g, 0, -1, failures)
	if not piece(g, "Sleeve/Ledge") in entry.neighbours: failures.append("The Threshold: turning back docks the ledge again")

static func solver(g: Node3D, failures: Array[String]) -> void:
	L.load_fold(g, THRESHOLD)
	var sight := LinkSolver.survey(g, failures)
	var entry := piece(g, "Entry")
	var balcony := piece(g, "Balcony")
	var full := LinkSolver.minimum(g, sight, entry, balcony)
	if full.cost != 7 or full.turns != 3 or full.links != 2 or full.crosses != 2: failures.append("The Threshold minimum must be 3 turns, 2 links, 2 crossings: " + str(full))
	if LinkSolver.minimum(g, sight, entry, balcony, false, true).cost != -1: failures.append("The Threshold must be unsolvable without links")
	if LinkSolver.minimum(g, sight, entry, balcony, true, false).cost != -1: failures.append("The Threshold must be unsolvable without turning the sleeve")
