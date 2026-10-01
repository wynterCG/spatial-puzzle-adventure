extends RefCounted
## Shared helpers for headless runtime tests.

static func turn(g: Node3D, index: int, direction: int, failures: Array[String]) -> void:
	g.architectural = true
	g.select_rig(index)
	g.rotate_selected(direction)
	if not g.busy:
		failures.append("Expected turn of structure %s: %s" % [index, g.message])
	else:
		g.tween.custom_step(1.0)
