@tool
extends RefCounted
## Shared by runtime and editor. Travel directions point OUT of each path.
static func compatible(a: Dictionary, b: Dictionary, require_position := true) -> bool:
	if not a.active or not b.active or a.path == b.path: return false
	if a.type != b.type or absf(a.width - b.width) > .05: return false
	var cosine := cos(deg_to_rad(minf(a.angle, b.angle)))
	if a.normal.dot(b.normal) < cosine or a.direction.dot(b.direction) > -cosine: return false
	return not require_position or a.position.distance_to(b.position) <= minf(a.tolerance, b.tolerance)

static func descriptors(level: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in level.components():
		if item.kind in [ElsewhereComponent.Kind.PATH, ElsewhereComponent.Kind.CURVE] and item.end_sockets:
			if item.kind == ElsewhereComponent.Kind.PATH:
				for side in [-1.0, 1.0]:
					result.append(make(item, item, Vector3(side * item.dimensions.x / 2, 0, 0), Vector3.RIGHT * side, Vector3.UP, item.dimensions.z))
			else:
				var curve = preload("res://scripts/authoring/gravity_path.gd").new()
				curve.radius = item.radius
				curve.arc = deg_to_rad(float(item.arc_degrees))
				curve.tail_length = item.tail
				result.append(make(item, item, Vector3.ZERO, Vector3.BACK, Vector3.UP, item.dimensions.z))
				var end: Vector3 = curve.point_at(curve.length())
				var frame: Basis = curve.surface_frame(end)
				result.append(make(item, item, end, -frame.z, frame.y, item.dimensions.z))
				curve.free()
		elif item.kind == ElsewhereComponent.Kind.SOCKET:
			var path = item.get_node_or_null(item.path)
			if path is ElsewhereComponent:
				result.append(make(item, path, Vector3.ZERO, item.travel_direction, item.ground_normal, item.width))
	return result

static func make(node: Node3D, path: Node3D, point: Vector3, direction: Vector3, normal: Vector3, width: float) -> Dictionary:
	return {"node": node, "path": path, "position": node.global_transform * point, "direction": (node.global_basis * direction).normalized(), "normal": (node.global_basis * normal).normalized(), "width": width, "type": node.socket_type, "active": node.active and path.active, "tolerance": node.position_tolerance, "angle": node.angular_tolerance}
