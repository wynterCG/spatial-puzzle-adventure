extends RefCounted

static func run(g: Node3D) -> Array[String]:
	var failures: Array[String] = []
	var h = preload("res://scripts/positioning_tests.gd")
	g.load_trial(4)
	g.walker.set_third_person(false)
	if g.progress_path() != "user://chapter-one.save": failures.append("Chapter needs isolated progress storage")
	h.walk(g, Vector3.FORWARD, 17)
	if g.walker.support.name != "Lower_approach": failures.append("Chapter entrance curve must reach lower approach")
	h.walk(g, Vector3.RIGHT, 6)
	if g.walker.support.name != "Bridge_path": failures.append("Chapter approach must board bridge")
	h.turn(g, 0, 1, failures)
	h.turn(g, 0, 1, failures)
	h.walk(g, Vector3.RIGHT, 5)
	if g.walker.support.name != "Bent_passage": failures.append("Chapter bridge must reach bent passage")
	h.walk(g, Vector3.FORWARD, 4)
	h.walk(g, Vector3.RIGHT, 5)
	if g.walker.support != g.world.get_node("Choice/Arrival"): failures.append("Chapter must walk continuously into choice assembly")
	for i in range(60): g.update_camera(1.0 / 60)
	if g.chapter_zone != 1: failures.append("Fixed threshold must select choice framing")
	var choice: Dictionary = g.snapshot()
	var saved: Dictionary = bytes_to_var(var_to_bytes(g.progress_data()))
	# Walk back across the same fixed threshold and return the occupied bridge.
	h.walk(g, Vector3.LEFT, 5)
	h.walk(g, Vector3.BACK, 4)
	h.walk(g, Vector3.LEFT, 5)
	if g.walker.support.name != "Bridge_path" or g.chapter_zone != 0:
		failures.append("Chapter backtracking must return to the bridge with entrance framing")
	h.turn(g, 0, -1, failures)
	h.turn(g, 0, -1, failures)
	h.walk(g, Vector3.LEFT, 6)
	h.walk(g, Vector3.BACK, 17)
	if g.walker.support != g.start: failures.append("Chapter entrance must be reversible without restart")
	# A real serialized save restores all assemblies and undo across a rebuild.
	g.load_trial(0)
	var prototype: Dictionary = g.snapshot()
	g.apply_progress(saved)
	if g.progress_path() != "user://positioning.save" or g.snapshot() != prototype:
		failures.append("Chapter save must not overwrite a prototype layout")
	g.load_trial(4)
	g.apply_progress(saved)
	if g.snapshot() != choice or g.history != saved.history:
		failures.append("Chapter save must restore all structures, focus, player and history")
	g.undo()
	if g.rigs[0].state != 1 or g.walker.support.name != "Bridge_path":
		failures.append("Chapter undo after reload must restore the earlier assembly and passenger")
	g.apply_progress(saved)
	h.walk(g, Vector3.RIGHT, 9)
	h.turn(g, 1, 1, failures)
	h.turn(g, 1, 1, failures)
	h.walk(g, Vector3.RIGHT, 20)
	if g.walker.support.name != "Short_deck": failures.append("Chapter short path must remain a wrong-position attempt")
	g.restore(choice)
	h.walk(g, Vector3.FORWARD, 17)
	h.walk(g, Vector3.RIGHT, 9)
	if g.walker.support.name != "Long_deck": failures.append("Chapter choice curve must board long deck")
	h.turn(g, 1, 1, failures)
	h.turn(g, 1, 1, failures)
	h.walk(g, Vector3.RIGHT, 15)
	if g.walker.support != g.world.get_node("Transfer/Arrival"): failures.append("Chapter choice must connect physically to relay approach: " + str(g.walker.support.get_path()))
	h.walk(g, Vector3.LEFT, 6)
	if g.walker.support.name != "First_path": failures.append("Chapter relay must initially board first path")
	h.turn(g, 2, 1, failures)
	var first_path: Dictionary = g.snapshot()
	h.turn(g, 2, 1, failures)
	h.walk(g, Vector3.RIGHT, 8)
	if g.walker.support.name != "First_path": failures.append("Remaining aboard must miss the fixed transfer")
	g.restore(first_path)
	h.walk(g, Vector3.RIGHT, 3)
	if g.walker.support.name != "Fixed_landing": failures.append("Chapter relay must reach fixed landing")
	h.turn(g, 2, 1, failures)
	h.walk(g, Vector3.FORWARD, 15.5)
	if g.walker.support.name != "Second_path": failures.append("Chapter fixed curve must reach other carrier path")
	# Align with the visible narrow central landing before crossing inward.
	h.walk(g, Vector3.RIGHT, -g.walker.foot.x)
	h.walk(g, Vector3.BACK, 5.9)
	if g.walker.support.name != "Exit": failures.append("Chapter relay must reach quiet passage entrance")
	h.walk(g, Vector3.LEFT, 11)
	if g.walker.support != g.goal or not g.won: failures.append("Chapter continuous route must reach the far light: " + str(g.walker.support.get_path()) + str(g.walker.foot))
	var ending: Dictionary = bytes_to_var(var_to_bytes(g.progress_data()))
	g.load_trial(4)
	g.apply_progress(ending)
	if not g.won or not g.chapter_completed or g.walker.support != g.goal:
		failures.append("Completed chapter must resume at the destination")
	g.continue_exploring()
	g.architectural = false
	g._process(0)
	if not g.won or g.blocks_play() or g.finish_open:
		failures.append("Chapter arrival must allow looking back without retriggering completion")
	g.show_reflection()
	if not g.blocks_play(): failures.append("Chapter reflection must suspend exploration")
	g.restart()
	if g.won or g.walker.support != g.start or not g.history.is_empty():
		failures.append("Chapter restart must reset the whole route")
	# Framing transitions preserve ground orientation and manual inspection.
	g.architectural = true
	g.orbit_overview(Vector2(45, -12))
	var yaw: float = g.overview_yaw
	var elevation: float = g.overview_elevation
	var frame: Basis = g.camera_frame
	g.walker.place(g.world.get_node("Entrance/Bent_passage"), Vector3(1, .2, -2), Vector3.UP, Vector3.RIGHT)
	var previous: Vector3 = g.overview.position
	for i in range(60):
		g.update_camera(1.0 / 60)
		if g.overview.position.distance_to(previous) > .8: failures.append("Chapter focus transition must not jump")
		previous = g.overview.position
	if g.chapter_zone != 1 or g.overview_yaw != yaw or g.overview_elevation != elevation or not g.camera_frame.is_equal_approx(frame):
		failures.append("Chapter framing must preserve the B ground frame and manual orbit")
	if failures.is_empty(): print("CHAPTER SELF TEST PASS: connected route, three assemblies, position and transfer dependencies, backtracking, focus continuity, isolated save, reload, undo, completion, restart")
	return failures
