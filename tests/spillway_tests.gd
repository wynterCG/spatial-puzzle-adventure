extends RefCounted
## The Spillway (monuments/the_spillway.tscn, tools/gen_spillway.py,
## docs/designs/2026-10-02-the-spillway.md): the dock table in all 16 states, the minimum and what
## it needs, the solution played through the runtime, the dead ends, the reactive water, the sight
## lines the design relies on and the opening composition.
const H = preload("res://tests/test_helpers.gd")
const Graph = preload("res://tests/state_graph.gd")
const Validate = preload("res://authoring/validation.gd")
const SPILLWAY := "res://monuments/the_spillway.tscn"
const DRUM := 0
const ARM := 1
enum { WEST, SOUTH, EAST, NORTH }

static func run(g: Node3D, failures: Array[String]) -> void:
	load_level(g)
	var validation := Validate.validate(g.definition)
	if not validation.errors.is_empty(): failures.append("The Spillway must validate: " + str(validation.errors))
	if g.rigs.size() != 2 or g.rigs[DRUM].node.name != "Drum" or g.rigs[ARM].node.name != "Crown": failures.append("The Spillway: the Drum and the Crown are its two structures")
	dock_cases(g, failures)
	minimum_cases(g, failures)
	solution(g, failures)
	dead_ends(g, failures)
	water_cases(g, failures)
	sight_cases(g, failures)
	composition_cases(g, failures)

static func load_level(g: Node3D) -> void:
	var scene = load(SPILLWAY).instantiate()
	var source = scene.get_node("Level")
	scene.remove_child(source)
	source.owner = null
	for child in source.find_children("*", "", true, false): child.owner = null
	if g.data_source:
		g.remove_child(g.data_source)
		g.data_source.queue_free()
	g.add_child(source)
	g.data_source = source
	source.hide()
	scene.free()
	g.build_level()

static func piece(g: Node3D, path: String) -> SurfacePiece:
	return g.paths[g.definition.get_node(path)]

static func joins(g: Node3D) -> Array:
	var result := []
	for part in g.pieces:
		for other in part.neighbours:
			var pair: Array = [str(part.get_parent().name), str(other.get_parent().name)]
			pair.sort()
			if not pair in result: result.append(pair)
	result.sort()
	return result

## Design section 7: what each state of the Drum and the Arm joins.
static func expected_joins(drum: int, arm: int) -> Array:
	var result := [["NorthGallery", "NorthWrap"], ["NorthUnder", "NorthWrap"], ["ThroatRim", "ThroatStair"], ["ThroatRim", "Underside"], ["CrownDeck", "GateCurl"]]
	if drum in [0, 2]:
		var up := "DrumDeck" if drum == 0 else "DrumKeel"
		var down := "DrumKeel" if drum == 0 else "DrumDeck"
		result += [[up, "Intake"], [up, "Landing"], [down, "LandingUnder"]]
	if arm == WEST: result += [["ArmUnder", "LandingUnder"], ["GateCurl", "ThroatStair"]]
	if arm == NORTH: result += [["CrownDeck", "NorthGallery"], ["ArmUnder", "NorthUnder"]]
	for pair in result: pair.sort()
	result.sort()
	return result

static func dock_cases(g: Node3D, failures: Array[String]) -> void:
	for drum in range(4):
		for arm in range(4):
			Graph.set_states(g, [drum, arm])
			if joins(g) != expected_joins(drum, arm): failures.append("The Spillway: Drum %d, Arm %d joins %s, expected %s" % [drum, arm, joins(g), expected_joins(drum, arm)])
			for k in range(2):
				for direction in [-1, 1]:
					var obstruction: String = g.turn_obstruction(k, direction)
					if obstruction != "": failures.append("The Spillway: every turn's sweep is clear (Drum %d, Arm %d, %s %d: %s)" % [drum, arm, g.rigs[k].node.name, direction, obstruction])
	Graph.set_states(g, [0, NORTH])

## 5 turns; unsolvable without rolling the Drum, and without turning the Arm.
static func minimum_cases(g: Node3D, failures: Array[String]) -> void:
	var table := Graph.adjacency(g)
	var start := piece(g, "Intake")
	var goal := piece(g, "Underside")
	var turns := Graph.minimum(g, table, [0, NORTH], start, goal, 1, 0)
	if turns != 5: failures.append("The Spillway minimum must be 5 turns: %d" % turns)
	if Graph.minimum(g, table, [0, NORTH], start, goal, 1, 0, [ARM]) != -1: failures.append("The Spillway must be unsolvable without rolling the Drum")
	if Graph.minimum(g, table, [0, NORTH], start, goal, 1, 0, [DRUM]) != -1: failures.append("The Spillway must be unsolvable without turning the Arm")

static func walk_until(g: Node3D, done: Callable, frames := 1500) -> bool:
	g.architectural = false
	for i in range(frames):
		g.walker.walk(Vector2(0, -1), 1.0 / 60)
		if not g.won and g.reached_goal(): g._process(0)
		if done.call(): return true
	return false

## Stands on a piece at an x1 point given in world coordinates, facing a world direction.
static func stand(g: Node3D, path: String, world: Vector3, heading: Vector3) -> void:
	var part := piece(g, path)
	var local := part.to_local(world * H.RING_SCALE)
	local.y = part.half.y
	g.walker.place(part, local, Vector3.UP, (part.global_basis.inverse() * heading).slide(Vector3.UP).normalized())
	g.walker.pitch = 0
	g.walker.sync_pose(1)

static func ground(g: Node3D) -> Vector3:
	return (g.walker.support.global_basis * g.walker.normal).normalized()

## The intended solution: swing the Arm west, roll under on the Drum's deck, ride north beneath
## the Arm, wrap onto the north gallery, board the Arm from above, ride it west, descend.
static func solution(g: Node3D, failures: Array[String]) -> void:
	load_level(g)
	var deck := piece(g, "Drum/DrumDeck")
	stand(g, "Intake", Vector3(-14, 0, 0), Vector3.RIGHT)
	if not walk_until(g, func(): return g.walker.support == piece(g, "Landing")): failures.append("The Spillway: the Drum's deck bridges the intake to the keeper's landing")
	H.turn(g, ARM, 1, failures)  # north -> west: 6 m below the landing
	if piece(g, "Crown/CrownDeck") in piece(g, "Landing").neighbours: failures.append("The Spillway: the Arm's top never meets the landing")
	stand(g, "Drum/DrumDeck", Vector3(-10, 0, 0), Vector3.RIGHT)
	H.turn(g, DRUM, 1, failures)
	H.turn(g, DRUM, 1, failures)
	if g.walker.support != deck or ground(g).dot(Vector3.DOWN) < .99: failures.append("The Spillway: rolling the Drum carries its rider over, upside down")
	if not walk_until(g, func(): return g.walker.support == piece(g, "Crown/ArmUnder")): failures.append("The Spillway: from under the landing the Arm's underside is reached")
	H.turn(g, ARM, -1, failures)  # west -> north, hanging beneath
	if g.walker.support != piece(g, "Crown/ArmUnder") or ground(g).dot(Vector3.DOWN) < .99: failures.append("The Spillway: the Arm carries a rider beneath it")
	g.walker.forward = Vector3.LEFT  # toward the Arm's tip
	if not walk_until(g, func(): return g.walker.support == piece(g, "NorthUnder")): failures.append("The Spillway: the Arm's underside meets the north gallery's")
	stand_under(g, "NorthUnder", Vector3(2, -1.6, -7.25), Vector3.RIGHT)
	if not walk_until(g, func(): return g.walker.support == piece(g, "NorthGallery")) or ground(g).dot(Vector3.UP) < .99: failures.append("The Spillway: the north wrap leads up onto the gallery, upright")
	stand(g, "NorthGallery", Vector3(0, 0, -7.0), Vector3.BACK)
	if not walk_until(g, func(): return g.walker.support == piece(g, "Crown/CrownDeck")): failures.append("The Spillway: from the north gallery the Arm is boarded on top")
	# Onto the Crown itself (at the Arm's tip the landing's face would stop the turn).
	stand(g, "Crown/CrownDeck", Vector3(0, 0, -2.4), Vector3.BACK)
	H.turn(g, ARM, 1, failures)  # north -> west: the keeper's gate over the stair
	if g.walker.support != piece(g, "Crown/CrownDeck"): failures.append("The Spillway: the Crown carries its rider")
	stand(g, "Crown/CrownDeck", Vector3(2.6, 0, 0), Vector3.LEFT)
	if not walk_until(g, func(): return g.walker.support == piece(g, "Underside")): failures.append("The Spillway: the keeper's gate leads down the throat and out under the basin")
	elif ground(g).dot(Vector3.DOWN) < .99: failures.append("The Spillway: under the basin the player is upside down")
	if not walk_until(g, func(): return g.won): failures.append("The Spillway: the underside leads to the Sanctuary")

static func stand_under(g: Node3D, path: String, world: Vector3, heading: Vector3) -> void:
	var part := piece(g, path)
	var local := part.to_local(world * H.RING_SCALE)
	local.y = part.half.y
	g.walker.place(part, local, Vector3.UP, (part.global_basis.inverse() * heading).slide(Vector3.UP).normalized())
	g.walker.sync_pose(1)

## Recoverable dead ends: each teaches something and turning back undoes it.
static func dead_ends(g: Node3D, failures: Array[String]) -> void:
	load_level(g)
	# Rolling the Drum while standing on the landing carries nobody.
	stand(g, "Landing", Vector3(-7.4, 0, 0), Vector3.RIGHT)
	H.turn(g, DRUM, 1, failures)
	H.turn(g, DRUM, 1, failures)
	if g.walker.support != piece(g, "Landing") or ground(g).dot(Vector3.UP) < .99: failures.append("The Spillway: the Drum carries only those standing on it")
	# One step leaves its rider on a wall with nothing joined; turning back restores the bridge.
	load_level(g)
	var deck := piece(g, "Drum/DrumDeck")
	stand(g, "Drum/DrumDeck", Vector3(-10, 0, 0), Vector3.RIGHT)
	H.turn(g, DRUM, 1, failures)
	if absf(ground(g).y) > .01 or not deck.neighbours.is_empty(): failures.append("The Spillway: one roll leaves the rider on a wall, joined to nothing")
	H.turn(g, DRUM, -1, failures)
	if ground(g).dot(Vector3.UP) < .99 or not piece(g, "Intake") in deck.neighbours: failures.append("The Spillway: rolling back restores the bridge")
	# Beneath the Arm, east and south lead nowhere; on the Crown the gate south leads nowhere.
	for arm in [SOUTH, EAST]:
		Graph.set_states(g, [2, arm])
		if not piece(g, "Crown/ArmUnder").neighbours.is_empty(): failures.append("The Spillway: beneath the Arm, only west and north meet anything (state %d)" % arm)
	Graph.set_states(g, [0, NORTH])
	if piece(g, "ThroatStair") in piece(g, "Crown/GateCurl").neighbours: failures.append("The Spillway: with the Arm north the keeper's gate faces a blank wall")

## The water answers the structures: the open gate pours, the closed gate pools, the aligned
## keeper's gate overflows down beside the stair.
static func water_cases(g: Node3D, failures: Array[String]) -> void:
	load_level(g)
	for drum in range(4):
		for arm in range(4):
			Graph.set_states(g, [drum, arm])
			if g.definition.get_node("GateOpen").visible != (drum in [1, 3]): failures.append("The Spillway: the open gate pours only in Drum states 1 and 3 (%d)" % drum)
			if g.definition.get_node("GateClosed").visible != (drum in [0, 2]): failures.append("The Spillway: the closed gate pools only in Drum states 0 and 2 (%d)" % drum)
			if g.definition.get_node("GateAligned").visible != (arm == WEST): failures.append("The Spillway: the stair overflow runs only with the Arm west (%d)" % arm)
	Graph.set_states(g, [0, NORTH])

static func solids(g: Node3D) -> Array:
	var result: Array = g.obstacles.duplicate()
	for part in g.pieces: result.append_array(part.solid_meshes)
	return result

## From the start the falls and the Sanctuary's spire are seen under the basin; from the Crown
## (arrived from the north) the stair head is seen across the throat.
static func sight_cases(g: Node3D, failures: Array[String]) -> void:
	load_level(g)
	g.walker.sync_pose(1)
	var eye: Vector3 = g.walker.camera.global_position
	for target in [["the falls", Vector3(0, -20, 0)], ["the Sanctuary's spire", Vector3(6.5, -22, 0)]]:
		if not H.visible(eye, target[1] * H.RING_SCALE, solids(g), []): failures.append("The Spillway: %s is seen from the start" % target[0])
	stand(g, "Crown/CrownDeck", Vector3(-1.3, 0, 0), Vector3.RIGHT)
	var head: Vector3 = g.definition.get_node("StairHead").global_position
	if not H.visible(g.walker.camera.global_position, head, solids(g), g.walker.support.solid_meshes): failures.append("The Spillway: from the Crown the stair head is seen across the throat")

## The opening overview shows the player, the Drum, the Arm, the falls and the Sanctuary at once,
## inside the frame and not hidden behind the monument.
static func composition_cases(g: Node3D, failures: Array[String]) -> void:
	load_level(g)
	g.architectural = false
	g.toggle_view()
	var camera: Camera3D = g.overview
	var size := g.get_viewport().get_visible_rect().size
	var aspect := size.x / size.y if size.y > 0 else 16.0 / 9.0
	var landmarks := {
		"the player": g.walker.support.to_global(g.walker.foot) + Vector3.UP,
		"the Drum": piece(g, "Drum/DrumDeck").global_position + Vector3.UP * 2,
		"the Arm": Vector3(0, .1, -5.5) * H.RING_SCALE,
		"the falls": Vector3(0, -24, 0) * H.RING_SCALE,
		"the Sanctuary": Vector3(6.5, -22, 0) * H.RING_SCALE}
	for name in landmarks:
		var point: Vector3 = landmarks[name]
		var local := camera.global_transform.affine_inverse() * point
		var half: float = camera.size / 2 * .95
		if local.z > 0 or absf(local.y) > half or absf(local.x) > half * aspect: failures.append("The Spillway: %s is inside the opening overview (%s)" % [name, local])
		var back: Vector3 = camera.global_basis.z
		var from := point + back * (camera.global_position - point).dot(back)
		if not H.visible(from, point, solids(g), []): failures.append("The Spillway: %s is not hidden in the opening overview" % name)
	g.toggle_view()
