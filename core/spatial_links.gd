extends RefCounted
## Spatial Links (experimental, docs/designs/2026-10-01-spatial-links.md): threshold frames, the
## crossing mapping and line of sight. Pure functions over world-space threshold descriptors
## ({position, direction (out through the doorway), normal (its ground), width, height}).

## How far past the destination's doorway plane a crossing lands, so the next step never sits
## on the plane it just came through.
const EXIT_BIAS := .05

## A threshold read from its current transform: a doorway on a turning structure moves with it.
static func live(node: Node3D) -> Dictionary:
	return {
		"position": node.global_position,
		"direction": (node.global_basis * node.travel_direction).normalized(),
		"normal": (node.global_basis * node.ground_normal).normalized(),
		"width": node.width,
		"height": node.aperture_height,
	}

## Doorway frame: origin on the ground at the aperture centre; x across (player-right walking
## out), y up the ground normal, z back into the path. Always right-handed.
static func frame(doorway: Dictionary) -> Transform3D:
	var up: Vector3 = doorway.normal
	var out: Vector3 = doorway.direction
	return Transform3D(Basis(out.cross(up).normalized(), up, -out).orthonormalized(), doorway.position)

## Walking out through A arrives walking into B's path: A's frame, half a turn about the ground
## normal, then B's frame. A rotation, never a reflection, so player-left stays left.
static func mapping(a: Dictionary, b: Dictionary) -> Transform3D:
	return frame(b) * Transform3D(Basis(Vector3.UP, PI)) * frame(a).affine_inverse()

## Sample points of an aperture: centre, left-mid, right-mid and upper-centre.
static func aperture_points(doorway: Dictionary) -> Array[Vector3]:
	var across: Vector3 = doorway.direction.cross(doorway.normal).normalized() * doorway.width * .4
	var mid: Vector3 = doorway.position + doorway.normal * doorway.height * .5
	return [mid, mid - across, mid + across, doorway.position + doorway.normal * doorway.height * .9]

## Analytic line of sight between two points against box solids, ignoring the meshes listed in
## `exclude` (a doorway's own frame and deck never hide it).
static func visible(from: Vector3, to: Vector3, solids: Array, exclude: Array) -> bool:
	for solid in solids:
		if solid in exclude or not solid.is_visible_in_tree() or not solid.mesh is BoxMesh: continue
		var size: Vector3 = solid.mesh.size
		if AABB(-size * .5, size).intersects_segment(solid.to_local(from), solid.to_local(to)) != null:
			return false
	return true
