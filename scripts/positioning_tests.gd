extends RefCounted

static func walk(g: Node3D, direction: Vector3, distance: float) -> void:
	g.walker.forward = direction
	for i in range(int(ceil(distance / (3.5 / 60.0)))):
		g.walker.walk(Vector2(0, -1), 1.0 / 60.0)
		g.walker.sync_pose(1.0 / 60.0)
		g.update_camera()
		if g.walker.support == g.goal and Vector2(g.walker.foot.x, g.walker.foot.z).length() < 1.0:
			g.architectural = false
			g._process(0.0)
			break

static func turn(g: Node3D, index: int, direction: int, failures: Array[String]) -> void:
	g.architectural = true
	g.select_rig(index)
	g.rotate_selected(direction)
	if not g.busy:
		failures.append("Expected turn %s in study %s: %s" % [index, g.trial, g.message])
	else:
		g.tween.custom_step(1.0)

static func run(g: Node3D) -> Array[String]:
	var failures: Array[String] = []
	g.walker.keep_world_horizon = false
	g.walker.reduced_motion = true
	g.load_trial(0)
	# A correct arrangement is insufficient from the short path.
	walk(g, Vector3.RIGHT, 9)
	if g.walker.support.name != "Short_deck": failures.append("Study 1: initial route must board the short deck")
	turn(g, 0, 1, failures)
	turn(g, 0, 1, failures)
	walk(g, Vector3.RIGHT, 20)
	if g.walker.support == g.goal or not g.walker.support.neighbours.is_empty(): failures.append("Study 1: short deck must not reach the exit")
	g.restart()
	walk(g, Vector3.FORWARD, 17)
	if g.walker.support.name != "Lower_landing": failures.append("Study 1: rounded path must reach lower landing, got " + str(g.walker.support.name))
	walk(g, Vector3.RIGHT, 9)
	if g.walker.support.name != "Long_deck": failures.append("Study 1: lower route must board the long deck")
	var before: Dictionary = g.snapshot()
	turn(g, 0, 1, failures)
	g.undo()
	if g.snapshot() != before: failures.append("Undo must restore passenger, camera and arrangement")
	turn(g, 0, 1, failures)
	turn(g, 0, 1, failures)
	walk(g, Vector3.RIGHT, 10)
	if g.walker.support != g.goal or not g.won: failures.append("Study 1 solution must complete at the physical exit")
	g.load_trial(1)
	walk(g, Vector3.LEFT, 6)
	if g.walker.support.name != "First_path": failures.append("Study 2: arrival must board the first path")
	turn(g, 0, 1, failures)
	walk(g, Vector3.RIGHT, 3)
	if g.walker.support.name != "Fixed_landing": failures.append("Study 2: leave the first path onto the landing")
	# Standing on fixed ground permits the empty carrier to replace its connection.
	turn(g, 0, 1, failures)
	walk(g, Vector3.FORWARD, 15.5)
	if g.walker.support.name != "Second_path": failures.append("Study 2: landing must reach the second path, got " + str(g.walker.support.name) + str(g.walker.foot))
	walk(g, Vector3.BACK, 7)
	if g.walker.support != g.goal or not g.won: failures.append("Study 2 solution must complete at the exit")
	g.load_trial(2)
	walk(g, Vector3.RIGHT, 6)
	turn(g, 0, -1, failures)
	g.select_rig(1)
	var blocked_snapshot: Dictionary = g.snapshot()
	var blocked_history: Array = g.history.duplicate(true)
	g.rotate_selected(-1)
	if g.busy or g.snapshot() != blocked_snapshot or g.history != blocked_history:
		failures.append("Rejected docking turn must preserve arrangement, passenger and undo history")
	# The fork is a real obstruction in both directions, without lock flags.
	for direction in [-1, 1]:
		g.rigs[1].state = 0
		g.rigs[1].node.basis = Basis.IDENTITY
		if g.turn_obstruction(1, direction).is_empty(): failures.append("Study 3: docking arms must obstruct either departure from aligned receiver")
	g.restart()
	turn(g, 1, -1, failures)
	walk(g, Vector3.RIGHT, 6)
	turn(g, 0, -1, failures)
	walk(g, Vector3.RIGHT, 6)
	if g.walker.support.name != "Receiver_path": failures.append("Study 3: prepared dock must connect physically")
	walk(g, Vector3.BACK, 10)
	if g.walker.support != g.goal or not g.won: failures.append("Study 3 solution must complete at the exit, got " + str(g.walker.support.name) + str(g.walker.foot))
	# No camera mode changes configuration; all saved contacts remain authored.
	var saved: Dictionary = g.snapshot()
	g.toggle_view()
	g.toggle_view()
	g.walker.set_third_person(false)
	g.walker.set_third_person(true)
	if g.snapshot() != saved: failures.append("Camera switches must not change puzzle state")
	if not g.walker.support.allows_point(g.walker.foot, g.walker.normal): failures.append("Winning contact must remain on the authored route")
	# Exhaust all settled orientations: neither the wrong deck nor the initial
	# landing can bypass the required path change in the first two studies.
	for study in [0, 1]:
		g.load_trial(study)
		for state in range(4):
			g.rigs[0].state = state
			g.rigs[0].node.basis = Basis(g.rigs[0].axis, state * PI / 2)
			g.update_links()
			var wrong: SurfacePiece = g.world.get_node("Twin_deck/Short_deck" if study == 0 else "Split_carrier/First_path")
			var right: SurfacePiece = g.world.get_node("Twin_deck/Long_deck" if study == 0 else "Split_carrier/Second_path")
			if wrong.neighbours.has(g.goal) or right.neighbours.has(g.start) or wrong.neighbours.has(right):
				failures.append("Settled orientation bypasses positioning dependency in study %s" % study)
	g.load_trial(0)
	g.walker.keep_world_horizon = true
	g.walker.world_orbit_initialized = false
	g.walker.place(g.start, Vector3(0, 0.2, 0), Vector3.UP, Vector3.FORWARD)
	for i in range(280):
		g.walker.walk(Vector2(0, -1), 1.0 / 60.0)
		g.walker.sync_pose(1.0 / 60.0)
		g.update_camera()
		var pivot: Vector3 = g.walker.avatar.global_position + g.walker.avatar.global_basis.y * 0.85
		if not g.walker.camera.global_transform.is_finite() or g.walker.camera.global_position.distance_to(pivot) < 0.45 or g.walker.camera.global_basis.y.dot(Vector3.UP) < -0.01:
			failures.append("World-aligned camera must remain clear and upright around the curve")
			break
	if g.walker.avatar.global_basis.y.dot(Vector3.DOWN) < 0.99 or g.overview.global_basis.y.dot(Vector3.DOWN) < 0.5:
		failures.append("Inverted traveller needs world-up traversal and ground-up overview")
	failures.append_array(preload("res://scripts/camera_tests.gd").run(g))
	return failures
