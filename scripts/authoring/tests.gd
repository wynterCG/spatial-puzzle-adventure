extends RefCounted
const C = preload("res://scripts/authoring/component.gd")
const Links = preload("res://scripts/authoring/connections.gd")
const Validate = preload("res://scripts/authoring/validation.gd")
const H = preload("res://scripts/positioning_tests.gd")
static var finished := false

static func load_level(g: Node3D, id: String) -> void:
	var scene = load("res://scenes/authored/" + id + ".tscn").instantiate()
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
	g.load_trial(6)

static func walk(g: Node3D, direction: Vector3, distance: float) -> void:
	g.architectural = false
	g.walker.forward = direction
	for i in range(int(ceil(distance / (3.5 / 60)))):
		g.walker.walk(Vector2(0, -1), 1.0 / 60)
		g.walker.sync_pose(1.0 / 60)
		g.update_camera(1.0 / 60)
		if not g.won and g.reached_goal():
			g._process(0)
			break

static func run(g: Node3D) -> Array[String]:
	finished = false
	var failures: Array[String] = []
	if g.walker.support == null:
		failures.append("Authored scene did not build a valid start")
		return failures
	g.walker.set_third_person(false)
	g.walker.reduced_motion = false
	var validation := Validate.validate(g.data_source)
	if not validation.errors.is_empty(): failures.append(str(validation.errors))
	var original: Dictionary = g.snapshot()
	# Every orientation keeps the two frame paths separate.
	for state in range(4):
		var data: Dictionary = original.duplicate(true)
		data.states[0] = state
		g.restore(data)
		var upper: SurfacePiece = g.paths[g.definition.get_node("TurningFrame/OuterPassage")]
		var lower: SurfacePiece = g.paths[g.definition.get_node("TurningFrame/InnerLedge")]
		if upper.neighbours.has(g.goal) or upper.neighbours.has(lower) or lower.neighbours.has(g.start): failures.append("Authored frame has a forbidden bypass")
		if lower.neighbours.has(g.goal) != (state == 2): failures.append("Authored frame must dock only at its authored half-roll")
	g.restore(original)
	walk(g, Vector3.RIGHT, 6)
	H.turn(g, 0, 1, failures); H.turn(g, 0, 1, failures)
	walk(g, Vector3.RIGHT, 20)
	if g.won or g.walker.support.get_parent().name != "OuterPassage": failures.append("Wrong path must remain wrong after turning")
	H.turn(g, 0, -1, failures); H.turn(g, 0, -1, failures)
	walk(g, Vector3.LEFT, 9)
	if g.walker.support != g.start: failures.append("Wrong frame choice must recover physically")
	g.restart()
	H.turn(g, 0, 1, failures); H.turn(g, 0, 1, failures)
	walk(g, Vector3.RIGHT, 12)
	if g.walker.support != g.start: failures.append("Remote pre-alignment must remove boarding")
	g.restart()
	walk(g, Vector3.LEFT, 11.5); walk(g, Vector3.RIGHT, 6)
	if g.walker.support.get_parent().name != "InnerLedge": failures.append("Authored curve must lead onto long ledge")
	var aboard: Dictionary = g.snapshot()
	g.architectural = true
	g.rotate_selected(1)
	if not g.busy: failures.append("Frame should be free to rotate")
	else:
		g.tween.custom_step(.4)
		for part in g.pieces:
			if not part.neighbours.is_empty(): failures.append("Intermediate turn must not enable any sockets")
		if g.walker.foot != aboard.player.foot: failures.append("Carrier must preserve local player position")
		g.tween.custom_step(1)
	g.undo()
	if g.snapshot() != aboard: failures.append("Authored undo must restore camera, path and states")
	for direction in [-1, 1]:
		g.restore(aboard)
		H.turn(g, 0, direction, failures); H.turn(g, 0, direction, failures)
		walk(g, Vector3.RIGHT, 8)
		if not g.won: failures.append("Authored frame must complete in either roll direction")
	var saved: Dictionary = bytes_to_var(var_to_bytes(g.progress_data()))
	g.load_trial(6); g.apply_progress(saved)
	if not g.won or g.walker.support != g.goal: failures.append("Authored completion save did not restore")
	var before_bad: Dictionary = g.snapshot()
	var bad: Dictionary = saved.duplicate(true)
	bad.revision += 1
	g.apply_progress(bad)
	if g.snapshot() != before_bad: failures.append("Changed revisions must reject old data")
	bad = saved.duplicate(true); bad.scene.player.foot = Vector3(99, 99, 99)
	g.apply_progress(bad)
	if g.snapshot() != before_bad: failures.append("Invalid saved contact must be rejected")
	g.restart()
	var source_transforms := {}
	for c in g.data_source.components(): source_transforms[str(g.data_source.get_path_to(c))] = c.transform
	if not g.apply_launch({"level": "turning_frame", "marker": "TurningFrame/InnerLedge", "states": {"TurningFrame": 2}}): failures.append("Play From Here must support an inverted/transformed path")
	if g.walker.support.get_parent().name != "InnerLedge" or g.rigs[0].state != 2: failures.append("Play From Here used the wrong path/state")
	for c in g.data_source.components():
		if source_transforms[str(g.data_source.get_path_to(c))] != c.transform: failures.append("Runtime/preview must not mutate authored transforms")
	var launch_before: Dictionary = g.snapshot()
	if g.apply_launch({"level": "turning_frame", "marker": "missing", "states": {"TurningFrame": 0}}) or g.snapshot() != launch_before: failures.append("Invalid play marker must restore the prior state atomically")
	# Sockets require more than coincident positions/normals.
	var sockets := Links.descriptors(g.definition)
	var a: Dictionary = sockets[0].duplicate()
	var b: Dictionary = a.duplicate()
	b.path = g.definition.get_node("TurningFrame/OuterPassage")
	b.direction = -a.direction
	if not Links.compatible(a, b): failures.append("Matching socket contract rejected")
	for property in ["direction", "normal", "width", "type", "active", "position"]:
		var changed: Dictionary = b.duplicate()
		match property:
			"direction": changed.direction = a.direction
			"normal": changed.normal = -a.normal
			"width": changed.width += 1
			"type": changed.type = "other"
			"active": changed.active = false
			"position": changed.position += Vector3.ONE
		if Links.compatible(a, changed): failures.append("Socket ignored " + property)
	# Contact apertures, not the whole touching edges, gate actual crossing.
	g.load_trial(6)
	var outer: SurfacePiece = g.paths[g.definition.get_node("TurningFrame/OuterPassage")]
	var aperture: Dictionary = g.start.connection_apertures.filter(func(value): return value.other == outer)[0]
	aperture.width = .5
	var crossing: Vector3 = aperture.point + aperture.direction * .05
	if not g.start.allows_connection(outer, crossing) or g.start.allows_connection(outer, crossing + aperture.direction.cross(aperture.normal) * .6): failures.append("Socket width must constrain actual crossing")
	# Interaction state belongs to snapshots, and conditions cannot mutate state.
	var brake = C.new()
	brake.name = "Brake"; brake.kind = C.Kind.INTERACTION
	brake.effect = 1; brake.target = NodePath("../TurningFrame")
	brake.position = Vector3(-5, 3, -2)
	g.data_source.add_child(brake)
	var gate = C.new()
	gate.name = "Gate"; gate.kind = C.Kind.INTERACTION
	gate.target = NodePath("../LowerThreshold")
	g.data_source.add_child(gate)
	g.load_trial(6)
	var before_interaction: Dictionary = g.snapshot()
	var press := InputEventKey.new()
	press.physical_keycode = KEY_F; press.pressed = true
	g._unhandled_input(press)
	if not g.rigs[0].locked or not g.interaction_values.Brake: failures.append("Nearby F interaction must toggle its target and persistent value")
	g.architectural = true
	var locked: Dictionary = g.snapshot()
	g.rotate_selected(1)
	if g.busy or g.snapshot() != locked: failures.append("Locked structure must reject rotation atomically")
	g.undo()
	if g.snapshot() != before_interaction: failures.append("Undo must restore interaction, path and lock state")
	var gate_runtime = g.definition.get_node("Gate")
	gate_runtime.condition_structure = NodePath("../TurningFrame"); gate_runtime.condition_state = 2
	if g.activate(gate_runtime) or g.snapshot() != before_interaction: failures.append("Unmet interaction condition must preserve state")
	gate_runtime.condition_state = -1
	if not g.activate(gate_runtime) or g.definition.get_node("LowerThreshold").active: failures.append("Path interaction must close its target")
	var interaction_save: Dictionary = bytes_to_var(var_to_bytes(g.progress_data()))
	g.load_trial(6); g.apply_progress(interaction_save)
	if g.definition.get_node("LowerThreshold").active or not g.interaction_values.Gate: failures.append("Interaction save must restore inactive paths and values")
	g.undo()
	if not g.definition.get_node("LowerThreshold").active: failures.append("Reloaded undo must restore path availability")
	# A path toggle cannot remove the occupied ground.
	gate_runtime = g.definition.get_node("Gate")
	gate_runtime.target = NodePath("../Arrival")
	var occupied: Dictionary = g.snapshot()
	if g.activate(gate_runtime) or g.snapshot() != occupied: failures.append("Interaction cannot deactivate occupied ground")
	# Different monument: leave the moving arm before replacing its connection.
	load_level(g, "bell_cradle")
	if not Validate.validate(g.definition).errors.is_empty(): failures.append("Bell cradle validation failed")
	var bell_initial: Dictionary = g.snapshot()
	walk(g, Vector3.LEFT, 6)
	H.turn(g, 0, 1, failures)
	H.turn(g, 0, 1, failures)
	walk(g, Vector3.RIGHT, 8)
	if g.won: failures.append("Remaining aboard the bell cradle must not solve")
	g.restore(bell_initial)
	walk(g, Vector3.LEFT, 6); H.turn(g, 0, 1, failures)
	walk(g, Vector3.RIGHT, 4)
	if g.walker.support.get_parent().name != "Belfry": failures.append("Bell cradle must reach fixed belfry")
	g._process(0)
	# Move to checkpoint centre if the landing was entered only at its edge.
	walk(g, Vector3.RIGHT, .5); g._process(0)
	H.turn(g, 0, 1, failures)
	walk(g, Vector3.RIGHT, 15.5)
	if g.walker.support.get_parent().name != "InnerArm": failures.append("Fixed curved belfry must reach inner arm: " + str(g.walker.support.get_parent().name) + str(g.walker.foot))
	walk(g, Vector3.RIGHT, 8)
	if not g.won: failures.append("Bell cradle route must complete")
	if g.checkpoint.is_empty(): failures.append("Authored checkpoint must record a valid landing contact")
	else:
		var checkpoint_save: Dictionary = bytes_to_var(var_to_bytes(g.progress_data()))
		g.load_trial(6); g.apply_progress(checkpoint_save)
		var expected_checkpoint: Dictionary = g.checkpoint.duplicate(true)
		press.physical_keycode = KEY_BACKSPACE
		g._unhandled_input(press)
		if g.snapshot() != expected_checkpoint or g.won: failures.append("Checkpoint restore must recover ground, position, camera and structure state after reload")
		g.apply_progress(checkpoint_save)
	if g.progress_path() == "user://authored-turning_frame.save": failures.append("Levels need separate saves")
	g.apply_progress(saved)
	if g.data_source.level_id != "bell_cradle" or not g.won: failures.append("Cross-level saves must not change the level")
	# Different relationship: prepare the receiver before its clearance closes.
	load_level(g, "folded_observatory")
	if g.rigs[1].angles.size() != 2: failures.append("Receiver should expose exactly two legal states")
	walk(g, Vector3.RIGHT, 6); H.turn(g, 0, -1, failures)
	g.select_rig(1)
	var blocked: Dictionary = g.snapshot()
	var history_before: Array = g.history.duplicate(true)
	g.rotate_selected(-1)
	if g.busy or g.snapshot() != blocked or g.history != history_before: failures.append("Docking must physically block receiver without mutating history")
	g.restart(); H.turn(g, 1, -1, failures)
	walk(g, Vector3.RIGHT, 6); H.turn(g, 0, -1, failures)
	walk(g, Vector3.RIGHT, 6)
	if g.walker.support.get_parent().name != "Gallery": failures.append("Prepared observatory dock must connect")
	walk(g, Vector3.BACK, 10)
	if not g.won: failures.append("Folded observatory must complete: " + str(g.walker.support.get_parent().name) + str(g.walker.foot))
	# Both supported curve angles have deterministic frames and reverse travel.
	for degrees in [90, 180]:
		var curve = preload("res://scripts/authoring/gravity_path.gd").new()
		curve.arc = deg_to_rad(degrees); curve.tail_length = 1.25
		for fraction in [0.0, .25, .5, .75, 1.0]:
			var distance: float = fraction * curve.length()
			var point: Vector3 = curve.point_at(distance)
			if absf(curve.distance_at(point) - distance) > .001 or not curve.allows_point(point, curve.surface_frame(point).y): failures.append("Gravity arc contact/frame mismatch")
		var last: Vector3 = curve.point_at(curve.length())
		var reversed: Vector3 = curve.step_contact(last, curve.surface_frame(last).z, curve.length())
		if reversed.length() > .001: failures.append("Gravity curve reverse travel must return to the start")
		curve.free()
	# Reject invalid authoring data with actionable errors.
	var start_node = g.data_source.get_node("Arrival/PlayerStart")
	start_node.ground_normal = Vector3.ZERO
	if Validate.validate(g.data_source).errors.is_empty(): failures.append("Invalid starting gravity must be reported")
	start_node.ground_normal = Vector3.UP
	var receiver_node = g.data_source.get_node("Receiver")
	var allowed: PackedFloat32Array = receiver_node.angles
	receiver_node.angles = PackedFloat32Array([0])
	if Validate.validate(g.data_source).errors.is_empty(): failures.append("Missing rotation states must be reported")
	receiver_node.angles = allowed
	# A real walker crosses a quarter-circle onto a wall and back. This small
	# fixture also exercises valid traversal-only levels with no moving rig.
	var fixture := ElsewhereLevel.new()
	fixture.name = "Level"; fixture.level_id = "quarter_curve_test"
	var arrival = C.new()
	arrival.name = "Arrival"; arrival.dimensions = Vector3(4, .4, 2)
	arrival.position = Vector3(0, 0, 2); arrival.rotation.y = PI / 2
	fixture.add_child(arrival)
	var start_marker = C.new()
	start_marker.kind = C.Kind.START; start_marker.name = "Start"; start_marker.path = NodePath("..")
	arrival.add_child(start_marker)
	var curve_marker = C.new()
	curve_marker.kind = C.Kind.CURVE; curve_marker.name = "QuarterCurve"
	curve_marker.radius = 2; curve_marker.arc_degrees = "90"; curve_marker.dimensions = Vector3(2, .3, 2)
	fixture.add_child(curve_marker)
	var wall = C.new()
	wall.name = "WallPath"; wall.dimensions = Vector3(4, .4, 2)
	wall.position = Vector3(0, -4, -2)
	wall.basis = Basis(Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT)
	fixture.add_child(wall)
	var goal_marker = C.new()
	goal_marker.kind = C.Kind.GOAL; goal_marker.name = "Goal"; goal_marker.path = NodePath("..")
	goal_marker.position.x = 1
	wall.add_child(goal_marker)
	g.remove_child(g.data_source); g.data_source.queue_free()
	g.add_child(fixture); g.data_source = fixture; fixture.hide(); g.load_trial(6)
	walk(g, Vector3.RIGHT, 10)
	if not g.won or g.walker.support != g.goal or (g.walker.support.global_basis * g.walker.normal).dot(Vector3.FORWARD) < .999: failures.append("Quarter-curve traversal must reach wall ground")
	var wall_save: Dictionary = bytes_to_var(var_to_bytes(g.progress_data()))
	g.load_trial(6); g.apply_progress(wall_save)
	if not g.won: failures.append("Traversal-only scene must restore its save")
	g.continue_exploring(); walk(g, Vector3.LEFT, 12)
	if g.walker.support != g.start: failures.append("Quarter-curve route must be physically reversible")
	print("AUTHORING CASES: three scene-authored solutions, wrong paths, order/clearance, two-state rotation, socket apertures, settled graph, carrier pose, interactions/conditions, checkpoints, undo, serialized saves, Play From Here, validation, 90/180 degree curves")
	finished = true
	return failures
