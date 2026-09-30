extends RefCounted

static func blocked(g: Node3D, index: int, direction: int, name: String, failures: Array[String]) -> void:
	g.architectural = true
	g.select_rig(index)
	var before: Dictionary = g.snapshot()
	var history: Array = g.history.duplicate(true)
	g.rotate_selected(direction)
	if g.busy or g.snapshot() != before or g.history != history or name not in g.message:
		failures.append("Rejected turn must name %s and preserve contact, configuration, camera and history: %s" % [name, g.message])
		if g.busy: g.tween.custom_step(1)

static func run(g: Node3D) -> Array[String]:
	var failures: Array[String] = []
	var h = preload("res://scripts/positioning_tests.gd")
	g.load_trial(4)
	g.walker.set_third_person(false)
	if g.progress_path() != "user://chapter-courtyard.save": failures.append("Rebuilt chapter must preserve older chapter/prototype saves")
	# Full terrace is navigable; its outer route has a physically matching end.
	for corner in [Vector3(-1.8, .2, 1.8), Vector3(1.8, .2, -1.8)]:
		if not g.start.allows_point(corner, Vector3.UP): failures.append("No invisible stripe on the arrival terrace")
	var original: Dictionary = g.snapshot()
	g.apply_progress({"version": 1, "scene": original})
	if g.snapshot() != original: failures.append("Old chapter data must not apply to the rebuilt courtyard")
	h.walk(g, Vector3.FORWARD, 13.4)
	if g.walker.support.name != "Underside_gallery": failures.append("Outer gallery must lead beneath the arrival terrace")
	if g.chapter_zone != 1: failures.append("Fixed underside landing must select courtyard question")
	var approach: Dictionary = g.snapshot()
	# Remote turning is legal, but a ring moved before entry removes access.
	h.turn(g, 1, 1, failures)
	h.turn(g, 1, 1, failures)
	h.turn(g, 0, -1, failures)
	h.walk(g, Vector3.RIGHT, 16)
	if g.walker.support.name != "Access_gallery_path": failures.append("Remote pre-rotation must remove the ring boarding connection")
	g.restore(approach)
	h.turn(g, 0, -1, failures)
	h.walk(g, Vector3.RIGHT, 4)
	if g.walker.support.name != "Access_gallery_path": failures.append("Entry gallery must be reachable")
	h.turn(g, 0, 1, failures)
	h.walk(g, Vector3.RIGHT, 12)
	if g.walker.support.name != "Access_gallery_path": failures.append("Board-rotate-continue must not bypass leaving the access gallery")
	g.restore(approach)
	h.turn(g, 0, -1, failures)
	h.walk(g, Vector3.RIGHT, 10)
	if g.walker.support.name != "Inner_gallery": failures.append("Deployed access must let the player enter the ring")
	blocked(g, 1, 1, "Access gallery", failures)
	blocked(g, 1, -1, "Access gallery", failures)
	var before_preview: Dictionary = g.snapshot()
	var before_history: Array = g.history.duplicate(true)
	var obstacle_count: int = g.obstacles.size()
	g.preview_selected_turn(-1)
	if not is_instance_valid(g.clearance_preview) or g.turn_contact.is_empty(): failures.append("Blocked ring hover must show its actual bracket contact")
	if g.snapshot() != before_preview or g.history != before_history or g.obstacles.size() != obstacle_count:
		failures.append("Clearance preview must not mutate the puzzle, undo or collision geometry")
	g.walker.reduced_motion = false
	g.preview_selected_turn(-1)
	var physical_ring: Transform3D = g.rigs[1].node.global_transform
	var passenger: Dictionary = g.walker.snapshot()
	if not g.clearance_preview_motion.global_transform.is_equal_approx(g.clearance_preview_start): failures.append("Animated preview must begin at the actual ring pose")
	for i in range(60): g._process(1.0 / 60.0)
	if not g.clearance_preview_motion.global_transform.is_equal_approx(g.clearance_preview_end): failures.append("Preview must stop at its sampled collision")
	if g.rigs[1].node.global_transform != physical_ring or g.walker.snapshot() != passenger or g.history != before_history:
		failures.append("Animated collision preview must never move the real ring or passenger")
	g.walker.reduced_motion = true
	g.preview_selected_turn(-1)
	if not g.clearance_preview_motion.global_transform.is_equal_approx(g.clearance_preview_end): failures.append("Reduced motion must show the collision pose immediately")
	g._process(8.1)
	if is_instance_valid(g.clearance_preview): failures.append("Preview must expire without leaving ghost geometry")
	h.turn(g, 0, 1, failures)
	if is_instance_valid(g.clearance_preview): failures.append("Changing the gallery must clear stale collision feedback")
	var clear: Dictionary = g.snapshot()
	var saved: Dictionary = bytes_to_var(var_to_bytes(g.progress_data()))
	# Inverting is another valid withdrawal, not a mandatory magic state.
	h.turn(g, 0, 1, failures)
	h.turn(g, 1, 1, failures)
	h.turn(g, 1, 1, failures)
	if g.rigs[1].state != 2: failures.append("An inverted access gallery must also leave the ring sweep clear")
	g.restore(clear)
	# Save/reload retains the exact occupied path and undo across structures.
	g.load_trial(0)
	var prototype: Dictionary = g.snapshot()
	g.apply_progress(saved)
	if g.progress_path() != "user://positioning.save" or g.snapshot() != prototype: failures.append("Courtyard progress must not alter prototype progress")
	g.load_trial(4)
	g.apply_progress(saved)
	if g.snapshot() != clear or g.history != saved.history: failures.append("Courtyard save must retain pose, all rigs, both camera layers and history")
	g.undo()
	if g.rigs[0].state != 0 or g.walker.support.name != "Inner_gallery": failures.append("Reloaded undo must restore the access gallery with player still on ring")
	g.apply_progress(saved)
	# Prematurely connecting the other gallery consumes the departure sweep.
	h.turn(g, 2, -1, failures)
	h.turn(g, 1, 1, failures)
	blocked(g, 1, 1, "Far gallery", failures)
	h.turn(g, 2, 1, failures)
	h.turn(g, 1, 1, failures)
	if g.rigs[1].state != 2: failures.append("Withdrawing far gallery must recover without undo or restart")
	g.restore(clear)
	# Either ring roll direction solves the same physical dependency.
	for direction in [-1, 1]:
		g.restore(clear)
		h.turn(g, 1, direction, failures)
		h.turn(g, 1, direction, failures)
		h.turn(g, 2, -1, failures)
		blocked(g, 1, 1, "Far gallery", failures)
		blocked(g, 1, -1, "Far gallery", failures)
		h.walk(g, Vector3.RIGHT, 10)
		if g.walker.support != g.goal or not g.won: failures.append("Courtyard must complete through either clear half-roll")
	var ending: Dictionary = bytes_to_var(var_to_bytes(g.progress_data()))
	g.load_trial(4)
	g.apply_progress(ending)
	if not g.won or not g.chapter_completed or g.walker.support != g.goal: failures.append("Completion must survive reload")
	g.continue_exploring()
	g.architectural = false
	g._process(0)
	if g.blocks_play() or not g.won: failures.append("Completion must allow revisiting without retriggering the panel")
	# Changed application: get back onto the ring before withdrawing the far
	# gallery, return the ring, restore the access, then revisit the overlook.
	h.walk(g, Vector3.LEFT, 9)
	if g.walker.support.name != "Inner_gallery": failures.append("Return must enter ring from the far terrace")
	h.turn(g, 2, 1, failures)
	h.turn(g, 1, -1, failures)
	h.turn(g, 1, -1, failures)
	h.turn(g, 0, -1, failures)
	h.walk(g, Vector3.LEFT, 10)
	if g.walker.support.name != "Underside_gallery": failures.append("Return must reach underside gallery")
	h.walk(g, Vector3.BACK, 13.4)
	if g.walker.support != g.start: failures.append("Whole courtyard must be reversible without undo")
	g.show_reflection()
	if not g.blocks_play(): failures.append("Reflection must suspend play")
	g.restart()
	if g.won or g.walker.support != g.start or not g.history.is_empty(): failures.append("Restart must restore arrival and configurations")
	# Exhaustive contact audit, including arrangements that may be blocked.
	var initial: Dictionary = g.snapshot()
	var access: SurfacePiece = g.world.get_node("Access_gallery/Access_gallery_path")
	var inner: SurfacePiece = g.world.get_node("Courtyard_ring/Inner_gallery")
	var far: SurfacePiece = g.world.get_node("Far_gallery/Far_gallery_path")
	for a in range(4):
		for r in range(4):
			for f in range(4):
				var state: Dictionary = initial.duplicate(true)
				state.states.assign([a, r, f])
				g.restore(state)
				if access.neighbours.has(inner) != (a == 0 and r == 0): failures.append("Unexpected entry connection in %s" % [state.states])
				if inner.neighbours.has(far) != (r == 2 and f == 0): failures.append("Unexpected departure connection in %s" % [state.states])
	g.restore(initial)
	# One composition stays fixed as the ground frame and manual orbit move.
	g.architectural = true
	g.orbit_overview(Vector2(45, -12))
	var yaw: float = g.overview_yaw
	var elevation: float = g.overview_elevation
	var focus: Vector3 = g.focus
	h.walk(g, Vector3.FORWARD, 13.4)
	if g.focus != focus or g.overview_yaw != yaw or g.overview_elevation != elevation: failures.append("Courtyard must retain its composition and manual orbit across the curve")
	if g.rigs[0].tint == g.rigs[1].tint or g.rigs[1].tint == g.rigs[2].tint: failures.append("Movable assemblies must retain distinct colours")
	if failures.is_empty(): print("CHAPTER SELF TEST PASS: courtyard route, both rolls, access/clearance dependency, remote-order counterexamples, 64 contact configurations, reversible return, save/reload/undo, preserved prototypes, completion, camera, colours")
	return failures
