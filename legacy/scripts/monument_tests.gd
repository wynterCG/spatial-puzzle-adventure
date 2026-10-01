extends RefCounted

static func check_overview(g: Node3D, failures: Array[String]) -> void:
	# Keep the actual architecture above the footer in both ground directions.
	var viewport: Vector2 = g.get_viewport().get_visible_rect().size
	var usable := Rect2(.02, .12, .96, .79)
	for mesh in g.world.find_children("*", "MeshInstance3D", true, false):
		if not mesh.visible: continue
		var bounds: AABB = mesh.get_aabb()
		for corner in range(8):
			var screen: Vector2 = g.overview.unproject_position(mesh.to_global(bounds.get_endpoint(corner))) / viewport
			if not usable.has_point(screen):
				failures.append("Monument overview crops architecture from %s in state %s: %s" % [g.walker.support.name, g.rigs[0].state, screen])
				return

static func run(g: Node3D) -> Array[String]:
	var failures: Array[String] = []
	var h = preload("res://scripts/positioning_tests.gd")
	g.load_trial(5)
	g.walker.set_third_person(false)
	if g.rigs.size() != 1: failures.append("Monument must have exactly one moving assembly")
	if g.architectural: failures.append("Monument must enter in first person")
	if g.progress_path() != "user://monument-frame.save": failures.append("Monument must keep its own save")
	# Reach is visible in the geometry, never an instruction/progress lock.
	var original: Dictionary = g.snapshot()
	var upper: SurfacePiece = g.world.get_node("Turning_frame/Outer_passage")
	var inner: SurfacePiece = g.world.get_node("Turning_frame/Inner_ledge")
	var lower: SurfacePiece = g.world.get_node("Lower_threshold")
	for state in range(4):
		var data: Dictionary = original.duplicate(true)
		data.states[0] = state
		g.restore(data)
		if upper.neighbours.has(g.goal) or upper.neighbours.has(inner) or inner.neighbours.has(g.start):
			failures.append("Wrong passage must never bypass the positional choice")
		if inner.neighbours.has(g.goal) != (state == 2): failures.append("Only the turned long ledge must reach the lantern")
		if upper.neighbours.has(g.start) != (state == 0) or inner.neighbours.has(lower) != (state == 0):
			failures.append("Turning early must remove both starting connections")
	# A wrong passage must still show the destination on the other face.
	for route in [0, 1]:
		g.restore(original)
		if route == 1: h.walk(g, Vector3.LEFT, 11.5)
		h.walk(g, Vector3.RIGHT, 6)
		for state in range(4):
			check_overview(g, failures)
			h.turn(g, 0, 1, failures)
	g.restore(original)
	h.turn(g, 0, 1, failures)
	h.turn(g, 0, 1, failures)
	h.walk(g, Vector3.RIGHT, 16)
	if g.walker.support != g.start: failures.append("Remote alignment cannot let the arrival board the already-turned frame")
	g.restart()
	h.walk(g, Vector3.RIGHT, 6)
	h.turn(g, 0, 1, failures)
	h.turn(g, 0, 1, failures)
	h.walk(g, Vector3.RIGHT, 20)
	if g.walker.support.name != "Outer_passage" or g.won: failures.append("Board/rotate/continue on the upper passage must stop at its visible gap")
	# Return a wrong choice through ordinary turns and walking, without reset.
	h.turn(g, 0, -1, failures)
	h.turn(g, 0, -1, failures)
	h.walk(g, Vector3.LEFT, 9)
	if g.walker.support != g.start: failures.append("Wrong passage must remain recoverable")
	g.restart()
	# The curved architectural end joins the two fixed thresholds physically.
	h.walk(g, Vector3.LEFT, 11.5)
	if g.walker.support.name != "Lower_threshold": failures.append("Rounded end must reach the underside threshold")
	h.walk(g, Vector3.RIGHT, 6)
	if g.walker.support.name != "Inner_ledge": failures.append("Underside threshold must board the longer ledge")
	var aboard: Dictionary = g.snapshot()
	h.turn(g, 0, 1, failures)
	var saved: Dictionary = bytes_to_var(var_to_bytes(g.progress_data()))
	g.load_trial(4)
	var courtyard: Dictionary = g.snapshot()
	g.apply_progress(saved)
	if g.snapshot() != courtyard or g.progress_path() != "user://chapter-courtyard.save": failures.append("Monument data must not alter courtyard progress")
	g.load_trial(5)
	g.apply_progress(saved)
	if g.snapshot() != saved.scene or g.history != saved.history: failures.append("Monument reload must retain passenger, camera and undo")
	g.undo()
	if g.snapshot() != aboard: failures.append("Monument undo after reload must restore its starting passenger")
	var bad: Dictionary = saved.duplicate(true)
	bad.layout = "courtyard"
	g.apply_progress(bad)
	if g.snapshot() != aboard: failures.append("Incompatible layout data must be rejected")
	for direction in [-1, 1]:
		g.restore(aboard)
		h.turn(g, 0, direction, failures)
		h.turn(g, 0, direction, failures)
		h.walk(g, Vector3.RIGHT, 7)
		if g.walker.support != g.goal or not g.won: failures.append("Either half-roll from the long ledge must complete")
	var ending: Dictionary = bytes_to_var(var_to_bytes(g.progress_data()))
	g.load_trial(5)
	g.apply_progress(ending)
	if not g.won or not g.monument_completed or g.walker.support != g.goal: failures.append("Monument completion must persist")
	g.continue_exploring()
	g.architectural = false
	g._process(0)
	if g.blocks_play(): failures.append("Monument must allow exploration after completion")
	h.walk(g, Vector3.LEFT, 7)
	h.turn(g, 0, -1, failures)
	h.turn(g, 0, -1, failures)
	h.walk(g, Vector3.LEFT, 5)
	if g.walker.support.name != "Lower_threshold": failures.append("Return must reach the fixed rounded end")
	h.walk(g, Vector3.LEFT, 11.5)
	if g.walker.support != g.start: failures.append("The whole monument must be reversible")
	g.restart()
	if g.won or g.walker.support != g.start or not g.history.is_empty(): failures.append("Monument restart must restore the initial route")
	# Exercise the same first-person input/update route as live controls.
	if g.architectural: g.toggle_view()
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(-PI / g.walker.sensitivity, 0)
	# Headless Godot cannot capture the mouse; exercise the same look handler
	# there, and separately verify event dispatch in the live MCP session.
	if DisplayServer.get_name() == "headless": g.walker.look(mouse.relative)
	else: g._unhandled_input(mouse)
	Input.action_press("forward")
	for i in range(198): g._process(1.0 / 60.0)
	Input.action_release("forward")
	g._process(0)
	if g.walker.support.name != "Lower_threshold": failures.append("Mouse turn and held W must traverse the integrated curve: %s %s forward=%s mouse=%s" % [g.walker.support.name, g.walker.foot, g.walker.forward, Input.mouse_mode])
	if failures.is_empty(): print("MONUMENT SELF TEST PASS: one assembly, four configurations, wrong-path and remote-order counterexamples, overview framing from both passages, physical recovery, both rolls, reverse route, first-person input, independent save, reload, undo, completion")
	return failures
