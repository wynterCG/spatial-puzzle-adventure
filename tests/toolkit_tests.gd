extends RefCounted
## The authoring toolkit (docs/designing-a-puzzle.md): Transformable Structures that rotate or
## slide, cyclic or not. Built on a small three-stop lift made in code, so the tests never depend
## on a monument's layout.
const C = preload("res://authoring/component.gd")
const Validate = preload("res://authoring/validation.gd")
const H = preload("res://tests/test_helpers.gd")
const Table = preload("res://authoring/connection_table.gd")
const Graph = preload("res://tests/state_graph.gd")
const RING := "res://monuments/the_ring.tscn"
const THRESHOLD := "res://monuments/the_threshold.tscn"

static func run(g: Node3D, failures: Array[String]) -> void:
	slide_cases(g, failures)
	cyclic_cases(g, failures)
	slide_validation_cases(failures)
	table_cases(g, failures)
	ring_table_cases(g, failures)
	launch_cases(g, failures)

static func path(name: String, at: Vector3, size := Vector3(4, .4, 2)) -> Node3D:
	var c = C.new()
	c.name = name; c.dimensions = size; c.position = at
	return c

static func marker(kind: int, name: String, x: float) -> Node3D:
	var c = C.new()
	c.kind = kind; c.name = name; c.path = NodePath(".."); c.position.x = x
	return c

## A lift between three galleries: Low (west, y 0), Middle (east, y 4) and High (west, y 8). Its
## deck docks Low in state 0 "Low", Middle in 1 "Middle" and High in 2 "High".
static func lift_level(blocker := false) -> Node3D:
	var level := ElsewhereLevel.new()
	level.name = "Level"; level.level_id = "lift_test"
	var low := path("Low", Vector3(-4, 0, 0))
	low.add_child(marker(C.Kind.START, "Start", -1))
	level.add_child(low)
	level.add_child(path("Middle", Vector3(4, 4, 0)))
	var high := path("High", Vector3(-4, 8, 0))
	high.add_child(marker(C.Kind.GOAL, "Goal", -1))
	level.add_child(high)
	var lift = C.new()
	lift.name = "Lift"; lift.kind = C.Kind.ROTATOR; lift.label = "The lift"
	lift.motion = C.Motion.SLIDE
	lift.offsets = PackedVector3Array([Vector3.ZERO, Vector3(0, 4, 0), Vector3(0, 8, 0)])
	lift.wrap_states = false
	lift.state_names = PackedStringArray(["Low", "Middle", "High"])
	lift.duration = 1.0
	level.add_child(lift)
	lift.add_child(path("Deck", Vector3.ZERO))
	# A lever that closes the middle gallery (for Play From Here's interaction values).
	var lever = C.new()
	lever.name = "Lever"; lever.kind = C.Kind.INTERACTION; lever.target = NodePath("../Middle"); lever.position = Vector3(-5, 0, 0)
	level.add_child(lever)
	if blocker:
		var wall = C.new()
		wall.name = "Blocker"; wall.kind = C.Kind.GEOMETRY; wall.dimensions = Vector3(3, .4, 3); wall.position = Vector3(0, 6, 0)
		level.add_child(wall)
	return level

static func use_level(g: Node3D, level: Node3D) -> void:
	if g.data_source:
		g.remove_child(g.data_source)
		g.data_source.queue_free()
	g.add_child(level)
	g.data_source = level
	level.hide()
	g.build_level()

static func piece(g: Node3D, name: String) -> SurfacePiece:
	return g.paths[g.definition.find_child(name, true, false)]

static func deck_joins(g: Node3D) -> Array:
	return piece(g, "Deck").neighbours.map(func(other): return str(other.get_parent().name))

## Slide: each state is a position; the deck docks one gallery per state, carries its rider,
## stops at both ends, is blocked by fixed geometry and comes back with undo, restart and saves.
static func slide_cases(g: Node3D, failures: Array[String]) -> void:
	var level := lift_level()
	if not Validate.validate(level).errors.is_empty(): failures.append("The lift fixture must validate: " + str(Validate.validate(level).errors))
	use_level(g, level)
	var lift: Dictionary = g.rigs[0]
	if g.state_count(lift) != 3: failures.append("A three-stop lift has three states")
	var expected := {0: ["Low"], 1: ["Middle"], 2: ["High"]}
	for state in range(3):
		g.restore_state(lift, state)
		if deck_joins(g) != expected[state]: failures.append("Lift state %d (%s) docks %s, expected %s" % [state, g.state_name(lift, state), deck_joins(g), expected[state]])
		var origin: Vector3 = lift.node.global_position
		if not origin.is_equal_approx(Vector3(0, 4 * state, 0)): failures.append("Lift state %d stands at its offset: %s" % [state, origin])
	g.restore_state(lift, 0)
	# Non-cyclic: no state before Low, none after High (no High -> Low glide).
	if g.turn_obstruction(0, -1).is_empty(): failures.append("A non-cyclic structure stops at its first state")
	g.restore_state(lift, 2)
	if g.turn_obstruction(0, 1).is_empty(): failures.append("A non-cyclic structure stops at its last state")
	g.architectural = true
	g.select_rig(0)
	g.rotate_selected(1)
	if g.busy or lift.state != 2: failures.append("At its last state the lift does not move on")
	if not "High" in g.message: failures.append("The message names the end state: " + g.message)
	g.restore_state(lift, 0)
	# Carrying: a rider rises with the deck.
	var deck := piece(g, "Deck")
	g.walker.place(deck, Vector3(0, deck.half.y, 0), Vector3.UP, Vector3.RIGHT)
	var before: Vector3 = g.walker.support.to_global(g.walker.foot)
	g.history.clear()
	H.turn(g, 0, 1, failures)
	var after: Vector3 = g.walker.support.to_global(g.walker.foot)
	if g.walker.support != deck or not (after - before).is_equal_approx(Vector3(0, 4, 0)): failures.append("The lift carries its rider 4 m up: %s -> %s" % [before, after])
	if deck_joins(g) != ["Middle"]: failures.append("After rising one stop the deck meets the middle gallery")
	# Mid-transition the deck sits between stops and joins nothing.
	g.architectural = true
	g.select_rig(0)
	g.rotate_selected(1)
	g.tween.custom_step(.5)
	var mid: float = lift.node.global_position.y
	if mid <= 4.01 or mid >= 7.99: failures.append("Mid-slide the lift is between stops: %.2f" % mid)
	if not deck.neighbours.is_empty(): failures.append("Nothing joins while the lift moves")
	g.tween.custom_step(60.0)
	if lift.state != 2 or deck_joins(g) != ["High"]: failures.append("The slide settles at High")
	# Undo, restart and saved progress restore the offset.
	g.undo()
	if lift.state != 1 or not lift.node.global_position.is_equal_approx(Vector3(0, 4, 0)): failures.append("Undo restores the lift's position")
	var saved: Dictionary = g.snapshot()
	g.restart()
	if lift.state != 0 or not lift.node.global_position.is_equal_approx(Vector3.ZERO): failures.append("Restart returns the lift to Low")
	g.restore(saved)
	if lift.state != 1 or not lift.node.global_position.is_equal_approx(Vector3(0, 4, 0)): failures.append("A snapshot restores the lift's position")
	# The same pose function serves the editor preview.
	var base := Transform3D(Basis.IDENTITY, Vector3(1, 2, 3))
	if not lift.node.state_local_transform(base, 2).origin.is_equal_approx(Vector3(1, 10, 3)): failures.append("The preview pose of a slide state is its offset from the base")
	# Sweeps: samples follow travel distance; a blocker stops the slide with a reason.
	g.restore_state(lift, 1)
	var samples: int = g.sweep_samples(lift, 1)
	if samples < 60 or g.sweep_travel(lift, 1) / samples > g.SWEEP_STEP + .000001: failures.append("Slide sweeps sample by distance")
	use_level(g, lift_level(true))
	lift = g.rigs[0]
	g.restore_state(lift, 1)
	if not "blocked" in g.turn_obstruction(0, 1): failures.append("A slide through fixed geometry is blocked: " + g.turn_obstruction(0, 1))
	if not g.turn_obstruction(0, -1).is_empty(): failures.append("A clear slide is allowed")

## Cyclic structures (every rotating monument) still wrap; a non-cyclic rotation stops.
static func cyclic_cases(g: Node3D, failures: Array[String]) -> void:
	var scene = load(RING).instantiate()
	var source = scene.get_node("Level")
	scene.remove_child(source)
	source.owner = null
	for child in source.find_children("*", "", true, false): child.owner = null
	scene.free()
	use_level(g, source)
	var ring: Dictionary = g.rigs[1]
	if g.state_count(ring) != 4 or g.next_state(ring, 3, 1) != 0 or g.next_state(ring, 0, -1) != 3: failures.append("A cyclic rotation wraps")
	ring.wrap_states = false
	if g.next_state(ring, 3, 1) != 3 or g.next_state(ring, 0, -1) != 0: failures.append("A non-cyclic rotation stops at its ends")
	ring.wrap_states = true

static func slide_validation_cases(failures: Array[String]) -> void:
	var cases := {
		"one offset": func(lift): lift.offsets = PackedVector3Array([Vector3.ZERO]),
		"repeated offsets": func(lift): lift.offsets = PackedVector3Array([Vector3.ZERO, Vector3.ZERO]),
		"initial state out of range": func(lift): lift.initial_state = 3,
		"a name per state": func(lift): lift.state_names = PackedStringArray(["Low"])}
	for label in cases:
		var level := lift_level()
		cases[label].call(level.get_node("Lift"))
		if Validate.validate(level).errors.is_empty(): failures.append("Slide validation rejects " + label)
		level.free()
	var cyclic := lift_level()
	cyclic.get_node("Lift").wrap_states = true
	var report := Validate.validate(cyclic)
	if not report.errors.is_empty() or not report.warnings.any(func(w): return "cyclic" in w): failures.append("A cyclic slide is allowed but warned about")
	cyclic.free()

static func load_scene_level(g: Node3D, scene_path: String) -> void:
	var scene = load(scene_path).instantiate()
	var source = scene.get_node("Level")
	scene.remove_child(source)
	source.owner = null
	for child in source.find_children("*", "", true, false): child.owner = null
	scene.free()
	use_level(g, source)

## Base (authored) transforms and current states of every structure, keyed by level path.
static func bases(g: Node3D) -> Dictionary:
	var result := {}
	for entry in g.rigs: result[str(g.definition.get_path_to(entry.node))] = entry.base
	return result

static func states(g: Node3D) -> Dictionary:
	var result := {}
	for entry in g.rigs: result[str(g.definition.get_path_to(entry.node))] = entry.state
	return result

## The dock's connection table: what joins now, what each state of a structure adds, removes
## and strands, and where the player can walk from a path right now.
static func table_cases(g: Node3D, failures: Array[String]) -> void:
	use_level(g, lift_level())
	var level: Node3D = g.definition
	var lift: Node3D = level.get_node("Lift")
	var now := states(g)
	Table.pose(level, now, bases(g))
	if Table.joins(level) != [["Deck", "Low"]]: failures.append("Connection table: in Low the deck joins the low gallery: " + str(Table.joins(level)))
	var rows: Array = Table.by_state(level, lift, now, bases(g))
	if rows.size() != 3 or rows.map(func(row): return row.name) != ["Low", "Middle", "High"]: failures.append("Connection table: one named row per state: " + str(rows))
	else:
		if rows[0].added != [] or rows[0].removed != [] or rows[0].unchanged != [["Deck", "Low"]]: failures.append("Connection table: the current state changes nothing: " + str(rows[0]))
		if rows[1].added != [["Deck", "Middle"]] or rows[1].removed != [["Deck", "Low"]]: failures.append("Connection table: Middle adds Deck-Middle and removes Deck-Low: " + str(rows[1]))
		if rows[1].stranded != ["High", "Low"]: failures.append("Connection table: in Middle the low and high galleries are left unjoined: " + str(rows[1].stranded))
		if rows[2].added != [["Deck", "High"]]: failures.append("Connection table: High adds Deck-High: " + str(rows[2]))
	if Table.joins(level) != [["Deck", "Low"]]: failures.append("Connection table: reading every state leaves the current pose alone")
	var low: Node3D = level.get_node("Low")
	var high: Node3D = level.get_node("High")
	if Table.reachable(level, low) != ["Deck", "Low"]: failures.append("Reachable from the low gallery in Low: " + str(Table.reachable(level, low)))
	Table.pose(level, {"Lift": 2}, bases(g))
	if Table.reachable(level, low) != ["Low"] or Table.reachable(level, high) != ["Deck", "High"]: failures.append("Reachable in High: low alone, high with the deck")
	Table.pose(level, now, bases(g))

## The table agrees with the runtime in every one of The Ring's 16 configurations.
static func ring_table_cases(g: Node3D, failures: Array[String]) -> void:
	load_scene_level(g, RING)
	var base := bases(g)
	for config in Graph.adjacency(g):
		Graph.set_states(g, config)
		var runtime: Array = []
		for part in g.pieces:
			for other in part.neighbours:
				var pair: Array = [Table.label(part.get_parent()), Table.label(other.get_parent())]
				pair.sort()
				if not pair in runtime: runtime.append(pair)
		runtime.sort()
		Table.pose(g.definition, states(g), base)
		if Table.joins(g.definition) != runtime: failures.append("Connection table matches the runtime in The Ring %s: %s vs %s" % [config, Table.joins(g.definition), runtime])

## Play From Here can start with interactions set and a link made, not only states and a place.
static func launch_cases(g: Node3D, failures: Array[String]) -> void:
	use_level(g, lift_level())
	var payload := {"level": "lift_test", "marker": "Low", "states": {"Lift": 1}, "interactions": {"Lever": true}}
	if not g.apply_launch(payload): failures.append("A launch with interaction values is accepted: " + g.message)
	if g.rigs[0].state != 1 or not g.interaction_values.get("Lever", false) or g.definition.get_node("Middle").active: failures.append("The launch applies the state and the lever (middle gallery closed)")
	use_level(g, lift_level())
	if g.apply_launch({"level": "lift_test", "marker": "Low", "interactions": {"Nowhere": true}}): failures.append("A launch naming an unknown interaction is refused")
	load_scene_level(g, THRESHOLD)
	var ids: Array = g.thresholds.keys().filter(func(id): return g.threshold_label(id) in ["Ledge door", "Under door"])
	if not g.apply_launch({"level": "the_threshold", "marker": "Entry", "link": ids}): failures.append("A launch with a link pair is accepted: " + g.message)
	if g.link.size() != 2 or not g.link.all(func(id): return id in ids) or g.paths[g.definition.get_node("Sleeve/Ledge")].remote_links.is_empty(): failures.append("The launch makes the link")
	load_scene_level(g, THRESHOLD)
	if g.apply_launch({"level": "the_threshold", "marker": "Entry", "link": [ids[0], ids[0]]}): failures.append("A launch linking a doorway to itself is refused")
