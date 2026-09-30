extends RefCounted

static func run(g: Node3D) -> Array[String]:
	var failures: Array[String] = []
	var previous_completion: Array = g.completed.duplicate()
	g.restore_completed([true, false, true])
	if g.completed != [true, false, true, false]: failures.append("Lantern: old three-study completion saves must migrate without marking the new puzzle complete")
	g.restore_completed(previous_completion)
	var helper = preload("res://scripts/positioning_tests.gd")
	g.load_trial(3)
	g.walker.set_third_person(false)
	# A prepared receiver does not make the upper route long enough.
	helper.turn(g, 1, -1, failures)
	helper.walk(g, Vector3.RIGHT, 9)
	helper.turn(g, 0, 1, failures)
	helper.turn(g, 0, 1, failures)
	helper.walk(g, Vector3.RIGHT, 20)
	if g.walker.support.name != "Upper_path" or not g.walker.support.neighbours.is_empty() or g.won:
		failures.append("Lantern: the prepared dock must still require the long path")
	g.restart()
	# All settled arrangements preserve the separation between the two paths.
	var upper: SurfacePiece = g.world.get_node("Turnover/Upper_path")
	var lower: SurfacePiece = g.world.get_node("Turnover/Long_path")
	var receiver: SurfacePiece = g.world.get_node("Receiver/Receiver_path")
	for a in range(4):
		for b in range(4):
			g.rigs[0].node.basis = Basis(Vector3.RIGHT, a * PI / 2)
			g.rigs[1].node.basis = Basis(Vector3.UP, b * PI / 2)
			g.update_links()
			if upper.neighbours.has(receiver) or upper.neighbours.has(lower) or lower.neighbours.has(g.start) or lower.neighbours.has(g.goal):
				failures.append("Lantern: configuration bypasses the path/receiver dependency")
	g.restart()
	# Docking too soon is recoverable by withdrawing the turnover, without R.
	helper.walk(g, Vector3.FORWARD, 17)
	if g.walker.support.name != "Underside_landing": failures.append("Lantern: curve must reach the underside landing")
	helper.walk(g, Vector3.RIGHT, 9)
	if g.walker.support.name != "Long_path": failures.append("Lantern: underside must board the long path")
	helper.turn(g, 0, 1, failures)
	helper.turn(g, 0, 1, failures)
	g.select_rig(1)
	var blocked: Dictionary = g.snapshot()
	var history: Array = g.history.duplicate(true)
	g.rotate_selected(-1)
	if g.busy or g.snapshot() != blocked or g.history != history:
		failures.append("Lantern: unprepared receiver turn must be blocked without changing state")
	helper.turn(g, 0, -1, failures)
	helper.turn(g, 1, -1, failures)
	g.select_rig(0)
	var prepared: Dictionary = g.snapshot()
	helper.turn(g, 0, 1, failures)
	g.undo()
	if g.snapshot() != prepared: failures.append("Lantern: undo must restore the full arrangement and passenger")
	helper.turn(g, 0, 1, failures)
	for direction in [-1, 1]:
		if g.turn_obstruction(1, direction).is_empty(): failures.append("Lantern: dock arms must prevent either receiver departure")
	helper.walk(g, Vector3.RIGHT, 9)
	if g.walker.support.name != "Receiver_path": failures.append("Lantern: long path must join prepared receiver")
	var checkpoint: Dictionary = g.snapshot()
	g.restore(checkpoint)
	if g.snapshot() != checkpoint: failures.append("Lantern: settled save must restore exactly")
	helper.walk(g, Vector3.BACK, 10)
	if g.walker.support != g.goal or not g.won or not g.completed[3]:
		failures.append("Lantern: complete physical route must reach the final lantern")
	g.restart()
	if g.won or g.walker.support != g.start or not g.history.is_empty(): failures.append("Lantern: restart must reset the complete puzzle")
	# The direct solution must work with either half-roll direction as well.
	for direction in [-1, 1]:
		g.load_trial(3)
		helper.turn(g, 1, -1, failures)
		helper.walk(g, Vector3.FORWARD, 17)
		helper.walk(g, Vector3.RIGHT, 9)
		helper.turn(g, 0, direction, failures)
		helper.turn(g, 0, direction, failures)
		helper.walk(g, Vector3.RIGHT, 9)
		helper.walk(g, Vector3.BACK, 10)
		if not g.won: failures.append("Lantern: direct solution failed with roll direction %s" % direction)
	if failures.is_empty(): print("LANTERN SELF TEST PASS: path choice, receiver preparation, wrong-order recovery, all arrangements, undo, save migration, both roll directions, complete route, restart")
	return failures
