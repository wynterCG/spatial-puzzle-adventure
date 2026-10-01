extends RefCounted
## Headless self-test, launched from the main monument (The Ring) with -- --self-test.
## The Ring covers the generic runtime; tests/fixtures/ cover checkpoints, two-state hinges
## and blocked docking sweeps, which The Ring does not use. Fixtures are not game content.
const C = preload("res://authoring/component.gd")
const Links = preload("res://authoring/connections.gd")
const Validate = preload("res://authoring/validation.gd")
const H = preload("res://tests/test_helpers.gd")
const Graph = preload("res://tests/state_graph.gd")
static var finished := false

static func load_level(g: Node3D, scene_path: String) -> void:
	var scene = load(scene_path).instantiate()
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

## Keeps walking in the current (transported) direction, e.g. after waiting at a path end.
static func walk_on(g: Node3D, distance: float) -> void:
	walk(g, g.walker.forward, distance)

static func run(g: Node3D) -> Array[String]:
	finished = false
	var failures: Array[String] = []
	if g.walker.support == null:
		failures.append("Authored scene did not build a valid start")
		return failures
	g.walker.set_third_person(false)
	g.walker.reduced_motion = false
	if g.data_source.level_id != "the_ring":
		failures.append("Self-test must be launched from monuments/the_ring.tscn")
		return failures
	var validation := Validate.validate(g.data_source)
	if not validation.errors.is_empty(): failures.append("Ring validation failed: " + str(validation.errors))
	ring_cases(g, failures)
	graph_cases(g, failures)
	camera_cases(g, failures)
	selection_cases(g, failures)
	runtime_cases(g, failures)
	socket_cases(g, failures)
	interaction_cases(g, failures)
	fixture_cases(g, failures)
	curve_cases(g, failures)
	print("AUTHORING CASES: ring v3 16-configuration table, dead ends, solution both ways, sweep clearance, 6-turn/16-action minimum, tower necessity, authored camera (no orbit, zoom, bounded pan, Home, Tab, legacy snapshots, turntable heading, ground follow, seam continuity), diegetic selection (pick, click, hover glow, no HUD list), carried pose, settled graph, undo, serialized saves, Play From Here, socket contract and apertures, interactions/conditions, checkpoints, two-state hinge, blocked sweep, validation, 90/180 degree curves")
	finished = true
	return failures

## Index of a rotator by node name, so tests never depend on scene order.
static func rig_index(g: Node3D, name: String) -> int:
	for i in range(g.rigs.size()):
		if g.rigs[i].node.name == name: return i
	return -1

static func piece(g: Node3D, path: String) -> SurfacePiece:
	return g.paths[g.definition.get_node(path)]

static func name_of(g: Node3D) -> String:
	return str(g.walker.support.get_parent().name)

## The Ring v3: two rotors around a hollow tower. The ring arm is walkable on both faces; the
## inner wheel's east arm only on top and its west arm only underneath; the tower interior joins
## its upper and lower west doors. Directions: 0 E, 1 N, 2 W, 3 S; an arm faces (offset + state) % 4.
static func ring_cases(g: Node3D, failures: Array[String]) -> void:
	var inner := rig_index(g, "InnerWheel")
	var ring := rig_index(g, "Ring")
	var initial: Dictionary = g.snapshot()
	var names := ["Entry", "Ring/RingTop", "Ring/RingUnder", "InnerWheel/InnerTop", "InnerWheel/InnerUnder", "TowerTop", "TowerCurl", "TowerUnder", "Balcony", "FarCurve", "Terrace"]
	for i in range(4):
		for o in range(4):
			var data: Dictionary = initial.duplicate(true)
			data.states[inner] = i; data.states[ring] = o
			g.restore(data)
			var expected := {}
			for n in names: expected[n] = []
			var pairs: Array = [["TowerTop", "TowerCurl"], ["TowerCurl", "TowerUnder"], ["Balcony", "FarCurve"], ["FarCurve", "Terrace"]]
			if o == 2: pairs.append(["Entry", "Ring/RingTop"])
			if o == 0: pairs.append(["Balcony", "Ring/RingUnder"])
			if i == 2: pairs.append(["TowerTop", "InnerWheel/InnerTop"])
			if i == 0: pairs.append(["TowerUnder", "InnerWheel/InnerUnder"])
			if i == o: pairs.append(["InnerWheel/InnerTop", "Ring/RingTop"])
			if (2 + i) % 4 == o: pairs.append(["InnerWheel/InnerUnder", "Ring/RingUnder"])
			for pair in pairs:
				expected[pair[0]].append(pair[1]); expected[pair[1]].append(pair[0])
			for n in names:
				var actual: Array = piece(g, n).neighbours.map(func(p): return str(g.definition.get_path_to(p.get_parent())))
				actual.sort(); expected[n].sort()
				if actual != expected[n]: failures.append("Ring config inner %s ring %s: %s joins %s, expected %s" % [i, o, n, actual, expected[n]])
	g.restore(initial)
	# Dead end: turning the ring from the entry removes the only boarding.
	g.restart()
	H.turn(g, ring, -1, failures)
	walk(g, Vector3.RIGHT, 6)
	if name_of(g) != "Entry": failures.append("A ring turned from the entry must not be boardable")
	H.turn(g, ring, 1, failures)
	walk(g, Vector3.RIGHT, 5)
	if name_of(g) != "RingTop": failures.append("Turning the ring back must restore boarding")
	# Dead end: without the inner wheel aligned, the ring arm top leads nowhere inward.
	g.restart()
	walk(g, Vector3.RIGHT, 9)
	if name_of(g) != "RingTop": failures.append("Ring arm top must end at the gap before the inner wheel is aligned: " + name_of(g))
	# Dead end: riding the ring arm top east does not lead to the exit.
	H.turn(g, ring, -1, failures); H.turn(g, ring, -1, failures)
	walk(g, Vector3.RIGHT, 8)
	if g.won: failures.append("Riding the ring arm top east must not solve")
	# Dead end, then recovery: leaving the tower before the underside arm arrives.
	g.restart()
	H.turn(g, inner, 1, failures); H.turn(g, inner, 1, failures)
	walk(g, Vector3.RIGHT, 20)
	if name_of(g) != "TowerUnder": failures.append("The tower floor must curl to its lower door: " + name_of(g))
	walk_on(g, 3)
	if name_of(g) != "TowerUnder": failures.append("The lower door must lead nowhere until the underside arm arrives")
	# Solution, turning each rotor in either direction.
	for direction in [-1, 1]:
		g.restart()
		H.turn(g, inner, direction, failures); H.turn(g, inner, direction, failures)
		walk(g, Vector3.RIGHT, 20)
		H.turn(g, inner, direction, failures); H.turn(g, inner, direction, failures)
		walk_on(g, 6)
		if name_of(g) != "RingUnder": failures.append("Leaving the tower must lead under the same ring arm (%s): %s" % [direction, name_of(g)])
		var hanging: Dictionary = g.snapshot()
		H.turn(g, ring, direction, failures); H.turn(g, ring, direction, failures)
		if name_of(g) != "RingUnder" or g.walker.foot != hanging.player.foot: failures.append("The ring must carry the player underneath in local pose")
		walk(g, Vector3.RIGHT, 16)
		if not g.won: failures.append("Ring v3 route must complete turning %s: %s %s" % [direction, name_of(g), g.walker.foot])
	# No structural sweep blocks any turn in any configuration (narrow necks, r = 5 joint).
	g.restart()
	for i in range(4):
		for o in range(4):
			var data: Dictionary = initial.duplicate(true)
			data.states[inner] = i; data.states[ring] = o
			g.restore(data)
			for k in [inner, ring]:
				for direction in [-1, 1]:
					var reason: String = g.turn_obstruction(k, direction)
					if not reason.is_empty(): failures.append("Turn of %s blocked at inner %s ring %s: %s" % [g.rigs[k].label, i, o, reason])
	g.restore(initial)

static func solve_ring(g: Node3D, failures: Array[String]) -> void:
	var inner := rig_index(g, "InnerWheel")
	var ring := rig_index(g, "Ring")
	g.restart()
	H.turn(g, inner, 1, failures); H.turn(g, inner, 1, failures)
	walk(g, Vector3.RIGHT, 20)
	H.turn(g, inner, 1, failures); H.turn(g, inner, 1, failures)
	walk_on(g, 6)
	H.turn(g, ring, 1, failures); H.turn(g, ring, 1, failures)
	walk(g, Vector3.RIGHT, 16)

## Diegetic selection: point at a movable structure in the isometric view; no HUD list.
static func selection_cases(g: Node3D, failures: Array[String]) -> void:
	var inner := rig_index(g, "InnerWheel")
	var ring := rig_index(g, "Ring")
	g.build_level()
	if not g.architectural: g.toggle_view()
	g.update_camera()
	if "sidebar" in g.hud or "selectors" in g.hud: failures.append("The HUD must not list movable structures")
	var screen := func(point: Vector3) -> Vector2: return g.overview.unproject_position(point)
	var band: Vector3 = g.definition.get_node("Ring/RingArt/Band16").global_position + Vector3.UP * .5
	var arm: Vector3 = g.definition.get_node("InnerWheel/InnerTop").global_position + Vector3.UP * .05
	var entry: Vector3 = g.definition.get_node("Entry").global_position
	if g.pick_rig(screen.call(band)) != ring: failures.append("Pointing at the ring band must pick the ring")
	if g.pick_rig(screen.call(arm)) != inner: failures.append("Pointing at an inner arm must pick the inner wheel")
	if g.pick_rig(screen.call(entry)) != -1: failures.append("Static architecture must not be pickable")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true
	click.position = screen.call(band)
	g._unhandled_input(click)
	if g.selected != ring: failures.append("Clicking the ring must select it")
	click.position = screen.call(arm)
	g._unhandled_input(click)
	if g.selected != inner: failures.append("Clicking the inner wheel must select it")
	click.position = screen.call(entry)
	g._unhandled_input(click)
	if g.selected != inner: failures.append("Clicking static architecture must keep the selection")
	var hover := InputEventMouseMotion.new()
	hover.position = screen.call(band)
	g._unhandled_input(hover)
	var band_mesh: MeshInstance3D = g.definition.get_node("Ring/RingArt/Band16")
	var arm_core: MeshInstance3D = g.definition.get_node("InnerWheel/InnerTopTip")
	if g.hovered != ring or band_mesh.material_overlay == null: failures.append("Hovering the ring must make it glow")
	if arm_core.material_overlay == null or arm_core.material_overlay == band_mesh.material_overlay: failures.append("The selected structure must glow distinctly from the hovered one")
	hover.position = screen.call(entry)
	g._unhandled_input(hover)
	if g.hovered != -1 or band_mesh.material_overlay != null: failures.append("Leaving the ring must clear its hover glow")
	g.toggle_view()
	if arm_core.material_overlay != null: failures.append("First person must show no selection glow")
	g.build_level()

## Minimum-solution regression on the real runtime graph: guards against shortcuts.
static func graph_cases(g: Node3D, failures: Array[String]) -> void:
	g.build_level()
	var table := Graph.adjacency(g)
	var start_config: Array = g.rigs.map(func(entry): return entry.state)
	var turns := Graph.minimum(g, table, start_config, g.start, g.goal, 1, 0)
	if turns != 6: failures.append("Ring v3 must need exactly 6 turns, found %s" % turns)
	# The abstract 12-step solution maps to 16 concrete actions: the tower interior is three
	# pieces (floor, curl, underside) and the exit is three (balcony, curve, terrace), so two
	# abstract walks each become three piece steps.
	var actions := Graph.minimum(g, table, start_config, g.start, g.goal, 1, 1)
	if actions != 16: failures.append("Ring v3 minimum must be 16 concrete actions, found %s" % actions)
	g.set_path_active(g.definition.get_node("TowerCurl"), false)
	if Graph.minimum(g, Graph.adjacency(g), start_config, g.start, g.goal, 1, 1) != -1: failures.append("The tower interior must be necessary")
	g.build_level()

## Authored isometric composition (spec §11) and the camera rules that motivate it.
static func camera_cases(g: Node3D, failures: Array[String]) -> void:
	var inner := rig_index(g, "InnerWheel")
	var ring := rig_index(g, "Ring")
	g.build_level()
	if not g.overview_local_offset.is_equal_approx(g.definition.overview_local_offset()): failures.append("The authored composition offset must come from the level")
	g.architectural = true
	var before: Dictionary = g.snapshot()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT; press.pressed = true
	g._unhandled_input(press)
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(300, 120); drag.button_mask = MOUSE_BUTTON_MASK_RIGHT
	g._unhandled_input(drag)
	g.update_camera()
	var after: Dictionary = g.snapshot()
	if after.camera_frame != before.camera_frame: failures.append("Right-drag must not rotate the authored view")
	if g.overview_pan == Vector2.ZERO: failures.append("Right-drag must pan the isometric view")
	var basis_before: Basis = g.overview.global_basis
	g.pan_overview(Vector2(1000, 1000))
	if g.overview_pan.length() > g.overview_size * g.PAN_LIMIT + .001: failures.append("Pan must stay within its limit")
	if not g.overview.global_basis.is_equal_approx(basis_before): failures.append("Pan must never change the camera angle")
	g.zoom_overview(100)
	if not is_equal_approx(g.overview_zoom, g.ZOOM_MIN): failures.append("Zoom must clamp to the minimum")
	g.zoom_overview(-100)
	if not is_equal_approx(g.overview_zoom, g.ZOOM_MAX): failures.append("Zoom must clamp to the maximum")
	var frame: Basis = g.camera_frame
	g.toggle_view(); g.toggle_view()
	if not is_equal_approx(g.overview_zoom, g.ZOOM_MAX) or g.overview_pan == Vector2.ZERO: failures.append("Tab must not reset zoom or pan")
	g.reset_overview()
	if not is_equal_approx(g.overview_zoom, 1.0) or g.overview_pan != Vector2.ZERO or not g.camera_frame.is_equal_approx(frame): failures.append("Home must reset zoom and pan only")
	var legacy: Dictionary = g.snapshot()
	legacy.overview_yaw = 1.2; legacy.overview_elevation = .5; legacy.overview_zoom = 3.0
	g.restore(legacy)
	if not is_equal_approx(g.overview_zoom, g.ZOOM_MAX) or not g.overview_local_offset.is_equal_approx(g.definition.overview_local_offset()): failures.append("Old orbit snapshots must restore within the authored composition")
	# Seam between pieces with different local axes: Entry -> ring arm (local +X is world -X).
	g.restart()
	walk(g, Vector3.RIGHT, 1.0)
	var seam_before: Basis = g.camera_frame
	walk(g, Vector3.RIGHT, 2.5)
	if name_of(g) != "RingTop" or not g.camera_frame.is_equal_approx(seam_before): failures.append("Crossing onto the ring arm must not flip the camera heading")
	# Turntable: turning the occupied ring about the ground normal keeps the camera heading.
	var turn_before: Basis = g.camera_frame
	var position_before: Vector3 = g.walker.support.to_global(g.walker.foot)
	H.turn(g, ring, 1, failures)
	g.update_camera()
	if not g.camera_frame.is_equal_approx(turn_before) or g.walker.support.to_global(g.walker.foot).distance_to(position_before) < 1: failures.append("A turntable turn must carry the player without rotating the camera heading")
	# Ground change: through the tower curl the camera follows the ground normal, rotating
	# only about the curl's axis (no extra yaw), and the inner arm -> tower seam does not flip.
	g.restart()
	H.turn(g, inner, 1, failures); H.turn(g, inner, 1, failures)
	g.architectural = false
	g.walker.forward = Vector3.RIGHT
	var curl: SurfacePiece = piece(g, "TowerCurl")
	var axis_world: Vector3 = curl.global_basis.x.normalized()
	var axis_in_frame := Vector3.ZERO
	var seam_checked := false
	var previous_name := name_of(g)
	var previous_frame: Basis = g.camera_frame
	for step in range(int(ceil(20 / (3.5 / 60)))):
		g.walker.walk(Vector2(0, -1), 1.0 / 60)
		g.walker.sync_pose(1.0 / 60)
		g.update_camera(1.0 / 60)
		var ground: Basis = g.walker.support.global_basis * g.walker.support.surface_frame(g.walker.foot)
		if g.camera_frame.y.distance_to(ground.y) > .001:
			failures.append("Camera must follow the ground normal on %s" % name_of(g))
			break
		if previous_name == "InnerTop" and name_of(g) == "TowerTop":
			seam_checked = true
			if not g.camera_frame.is_equal_approx(previous_frame): failures.append("Inner arm -> tower seam must not flip the camera heading")
		if g.walker.support == curl:
			var coordinates: Vector3 = g.camera_frame.inverse() * axis_world
			if axis_in_frame == Vector3.ZERO: axis_in_frame = coordinates
			elif coordinates.distance_to(axis_in_frame) > .001:
				failures.append("Camera must rotate only about the curl axis")
				break
		previous_name = name_of(g)
		previous_frame = g.camera_frame
	if not seam_checked: failures.append("Camera seam check did not reach the tower")
	if name_of(g) != "TowerUnder" or g.camera_frame.y.dot(Vector3.DOWN) < .999: failures.append("After the curl the camera must be upside down with the player")
	g.build_level()

## Generic runtime behaviour, exercised on The Ring.
static func runtime_cases(g: Node3D, failures: Array[String]) -> void:
	# Turns disable every connection until settled and carry the player in local pose.
	g.restart()
	walk(g, Vector3.RIGHT, 5)
	g.architectural = true
	g.select_rig(rig_index(g, "Ring"))
	var aboard: Dictionary = g.snapshot()
	g.rotate_selected(-1)
	if not g.busy: failures.append("Ring should be free to turn while boarded")
	else:
		g.tween.custom_step(.4)
		for part in g.pieces:
			if not part.neighbours.is_empty(): failures.append("Intermediate turn must not enable any sockets")
		if g.walker.foot != aboard.player.foot: failures.append("Carrier must preserve local player position")
		g.tween.custom_step(60)
	g.undo()
	if g.snapshot() != aboard: failures.append("Undo must restore camera, path and states")
	# Completion survives serialization; incompatible or invalid saves are rejected atomically.
	solve_ring(g, failures)
	if not g.won: failures.append("Ring solution helper must complete")
	var saved: Dictionary = bytes_to_var(var_to_bytes(g.progress_data()))
	g.build_level(); g.apply_progress(saved)
	if not g.won or g.walker.support != g.goal: failures.append("Completion save did not restore")
	var before_bad: Dictionary = g.snapshot()
	var bad: Dictionary = saved.duplicate(true)
	bad.revision += 1
	g.apply_progress(bad)
	if g.snapshot() != before_bad: failures.append("Changed revisions must reject old data")
	bad = saved.duplicate(true); bad.scene.player.foot = Vector3(99, 99, 99)
	g.apply_progress(bad)
	if g.snapshot() != before_bad: failures.append("Invalid saved contact must be rejected")
	# Play From Here: an inverted path in a transformed state, without mutating the authored source.
	g.restart()
	var source_transforms := {}
	for c in g.data_source.components(): source_transforms[str(g.data_source.get_path_to(c))] = c.transform
	if not g.apply_launch({"level": "the_ring", "marker": "InnerWheel/InnerUnder", "states": {"InnerWheel": 2, "Ring": 0}}): failures.append("Play From Here must support an inverted path on a turned rotor")
	if name_of(g) != "InnerUnder" or g.rigs[rig_index(g, "InnerWheel")].state != 2 or g.rigs[rig_index(g, "Ring")].state != 0: failures.append("Play From Here used the wrong path/state")
	if not g.apply_launch({"level": "the_ring", "marker": "TowerUnder", "states": {}}) or name_of(g) != "TowerUnder": failures.append("Play From Here must reach the hidden tower interior")
	for c in g.data_source.components():
		if source_transforms[str(g.data_source.get_path_to(c))] != c.transform: failures.append("Runtime/preview must not mutate authored transforms")
	var launch_before: Dictionary = g.snapshot()
	if g.apply_launch({"level": "the_ring", "marker": "missing", "states": {"Ring": 0}}) or g.snapshot() != launch_before: failures.append("Invalid play marker must restore the prior state atomically")
	g.build_level()

## Sockets require more than coincident positions/normals; apertures gate actual crossing.
static func socket_cases(g: Node3D, failures: Array[String]) -> void:
	var sockets := Links.descriptors(g.definition)
	var a: Dictionary = sockets[0].duplicate()
	var b: Dictionary = a.duplicate()
	b.path = g.definition.get_node("Terrace")
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
	g.build_level()
	var top: SurfacePiece = g.paths[g.definition.get_node("Ring/RingTop")]
	var aperture: Dictionary = g.start.connection_apertures.filter(func(value): return value.other == top)[0]
	aperture.width = .5
	var crossing: Vector3 = aperture.point + aperture.direction * .05
	if not g.start.allows_connection(top, crossing) or g.start.allows_connection(top, crossing + aperture.direction.cross(aperture.normal) * .6): failures.append("Socket width must constrain actual crossing")

## Interaction state belongs to snapshots, and conditions cannot mutate state.
static func interaction_cases(g: Node3D, failures: Array[String]) -> void:
	var brake = C.new()
	brake.name = "Brake"; brake.kind = C.Kind.INTERACTION
	brake.effect = 1; brake.target = NodePath("../Ring")
	brake.position = Vector3(-11.2, 1, 0)
	g.data_source.add_child(brake)
	var gate = C.new()
	gate.name = "Gate"; gate.kind = C.Kind.INTERACTION
	gate.target = NodePath("../Balcony")
	g.data_source.add_child(gate)
	g.build_level()
	var before_interaction: Dictionary = g.snapshot()
	var press := InputEventKey.new()
	press.physical_keycode = KEY_F; press.pressed = true
	g._unhandled_input(press)
	var ring := rig_index(g, "Ring")
	if not g.rigs[ring].locked or not g.interaction_values.Brake: failures.append("Nearby F interaction must toggle its target and persistent value")
	g.architectural = true
	g.select_rig(ring)
	var locked: Dictionary = g.snapshot()
	g.rotate_selected(1)
	if g.busy or g.snapshot() != locked: failures.append("Locked structure must reject rotation atomically")
	g.undo()
	if g.snapshot() != before_interaction: failures.append("Undo must restore interaction, path and lock state")
	var gate_runtime = g.definition.get_node("Gate")
	gate_runtime.condition_structure = NodePath("../Ring"); gate_runtime.condition_state = 0
	if g.activate(gate_runtime) or g.snapshot() != before_interaction: failures.append("Unmet interaction condition must preserve state")
	gate_runtime.condition_state = -1
	if not g.activate(gate_runtime) or g.definition.get_node("Balcony").active: failures.append("Path interaction must close its target")
	var interaction_save: Dictionary = bytes_to_var(var_to_bytes(g.progress_data()))
	g.build_level(); g.apply_progress(interaction_save)
	if g.definition.get_node("Balcony").active or not g.interaction_values.Gate: failures.append("Interaction save must restore inactive paths and values")
	g.undo()
	if not g.definition.get_node("Balcony").active: failures.append("Reloaded undo must restore path availability")
	# A path toggle cannot remove the occupied ground.
	gate_runtime = g.definition.get_node("Gate")
	gate_runtime.target = NodePath("../Entry")
	var occupied: Dictionary = g.snapshot()
	if g.activate(gate_runtime) or g.snapshot() != occupied: failures.append("Interaction cannot deactivate occupied ground")

## Fixture scenes for features The Ring does not use. They are test data, not monuments.
static func fixture_cases(g: Node3D, failures: Array[String]) -> void:
	var ring_save: Dictionary = bytes_to_var(var_to_bytes(g.progress_data()))
	# Checkpoints, and leaving a moving arm at fixed ground before turning it again.
	load_level(g, "res://tests/fixtures/bell_cradle.tscn")
	if not Validate.validate(g.definition).errors.is_empty(): failures.append("Bell cradle fixture validation failed")
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
		g.build_level(); g.apply_progress(checkpoint_save)
		var expected_checkpoint: Dictionary = g.checkpoint.duplicate(true)
		var press := InputEventKey.new()
		press.physical_keycode = KEY_BACKSPACE; press.pressed = true
		g._unhandled_input(press)
		if g.snapshot() != expected_checkpoint or g.won: failures.append("Checkpoint restore must recover ground, position, camera and structure state after reload")
		g.apply_progress(checkpoint_save)
	if g.progress_path() == "user://authored-the_ring.save": failures.append("Levels need separate saves")
	g.apply_progress(ring_save)
	if g.data_source.level_id != "bell_cradle" or not g.won: failures.append("Cross-level saves must not change the level")
	# Two-state hinge, and docking that physically blocks another structure's sweep.
	load_level(g, "res://tests/fixtures/folded_observatory.tscn")
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

## Both supported curve angles have deterministic frames and reverse travel, and a real
## walker crosses a quarter-circle onto a wall and back in a traversal-only level.
static func curve_cases(g: Node3D, failures: Array[String]) -> void:
	for degrees in [90, 180]:
		var curve = preload("res://core/gravity_path.gd").new()
		curve.arc = deg_to_rad(degrees); curve.tail_length = 1.25
		for fraction in [0.0, .25, .5, .75, 1.0]:
			var distance: float = fraction * curve.length()
			var point: Vector3 = curve.point_at(distance)
			if absf(curve.distance_at(point) - distance) > .001 or not curve.allows_point(point, curve.surface_frame(point).y): failures.append("Gravity arc contact/frame mismatch")
		var last: Vector3 = curve.point_at(curve.length())
		var reversed: Vector3 = curve.step_contact(last, curve.surface_frame(last).z, curve.length())
		if reversed.length() > .001: failures.append("Gravity curve reverse travel must return to the start")
		curve.free()
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
	g.add_child(fixture); g.data_source = fixture; fixture.hide(); g.build_level()
	walk(g, Vector3.RIGHT, 10)
	if not g.won or g.walker.support != g.goal or (g.walker.support.global_basis * g.walker.normal).dot(Vector3.FORWARD) < .999: failures.append("Quarter-curve traversal must reach wall ground")
	var wall_save: Dictionary = bytes_to_var(var_to_bytes(g.progress_data()))
	g.build_level(); g.apply_progress(wall_save)
	if not g.won: failures.append("Traversal-only scene must restore its save")
	g.continue_exploring(); walk(g, Vector3.LEFT, 12)
	if g.walker.support != g.start: failures.append("Quarter-curve route must be physically reversible")
