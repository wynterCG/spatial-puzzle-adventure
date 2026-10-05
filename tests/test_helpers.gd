extends RefCounted
## Shared helpers for headless runtime tests.

static func turn(g: Node3D, index: int, direction: int, failures: Array[String]) -> void:
	g.architectural = true
	g.select_rig(index)
	g.rotate_selected(direction)
	if not g.busy:
		failures.append("Expected turn of structure %s: %s" % [index, g.message])
	else:
		# Finish the turn regardless of its authored duration.
		g.tween.custom_step(60.0)

## The Ring is generated at this scale (tools/gen_ring.py SCALE); Ring distances in tests are
## written at x1 and passed through m().
const RING_SCALE := 4.0
static func m(metres: float) -> float: return metres * RING_SCALE

## Analytic line of sight between two points against box solids (visible box meshes), ignoring
## the meshes in `exclude`.
static func visible(from: Vector3, to: Vector3, solids: Array, exclude: Array) -> bool:
	for solid in solids:
		if solid in exclude or not solid.is_visible_in_tree() or not solid.mesh is BoxMesh: continue
		var size: Vector3 = solid.mesh.size
		if AABB(-size * .5, size).intersects_segment(solid.to_local(from), solid.to_local(to)) != null: return false
	return true
