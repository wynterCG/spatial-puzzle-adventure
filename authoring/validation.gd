@tool
extends RefCounted
const C = preload("res://authoring/component.gd")
const Links = preload("res://authoring/connections.gd")

static func validate(level: Node3D) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var starts: Array = []
	var goals: Array = []
	var rotations := 0
	if level.level_id.is_empty() or not level.level_id.is_valid_identifier(): errors.append("Level ID must be a stable identifier (letters, digits, underscores).")
	for c in level.components():
		var id := str(level.get_path_to(c))
		if not c.transform.is_finite() or not c.scale.is_equal_approx(Vector3.ONE): errors.append(id + ": use dimensions, not node scaling.")
		if c.kind in [C.Kind.PATH, C.Kind.CURVE, C.Kind.GEOMETRY] and (c.dimensions.x <= 0 or c.dimensions.y <= 0 or c.dimensions.z <= 0): errors.append(id + ": dimensions must be positive.")
		if c.kind == C.Kind.CURVE and (not is_finite(c.radius) or c.radius < .5 or c.tail < 0): errors.append(id + ": invalid curve radius or tail.")
		if c.kind == C.Kind.ROTATOR:
			rotations += 1
			if c.state_count() < 2 or c.initial_state < 0 or c.initial_state >= c.state_count(): errors.append(id + ": a transformable structure needs at least two states and an initial state among them.")
			if c.motion == C.Motion.ROTATE:
				if c.axis.length() < .99: errors.append(id + ": invalid rotation axis.")
				var seen: Array = []
				for angle in c.angles:
					var normalized := fposmod(float(angle), 360)
					if not is_finite(angle) or normalized in seen: errors.append(id + ": angles must be finite and distinct modulo 360.")
					seen.append(normalized)
			else:
				for i in range(c.offsets.size()):
					if not c.offsets[i].is_finite(): errors.append(id + ": slide offsets must be finite.")
					for j in range(i):
						if c.offsets[i].is_equal_approx(c.offsets[j]): errors.append(id + ": slide offsets must be distinct (states %d and %d match)." % [j, i])
				if c.wrap_states: warnings.append(id + ": a cyclic slide glides from its last state straight back to its first; turn off Cyclic states unless that is intended.")
			if not c.state_names.is_empty() and c.state_names.size() != c.state_count(): errors.append(id + ": give one state name per state (%d names, %d states)." % [c.state_names.size(), c.state_count()])
			var ancestor: Node = c.get_parent()
			while ancestor != level and ancestor != null:
				if ancestor is C and ancestor.kind == C.Kind.ROTATOR: errors.append(id + ": nested rotating structures are not supported in Phase 1.")
				ancestor = ancestor.get_parent()
		if c.kind in [C.Kind.START, C.Kind.GOAL, C.Kind.CHECKPOINT, C.Kind.SOCKET, C.Kind.THRESHOLD]:
			var path = c.get_node_or_null(c.path)
			if not path is C or not path.kind in [C.Kind.PATH, C.Kind.CURVE]:
				errors.append(id + ": assign a valid path reference.")
			else:
				if not level.is_ancestor_of(path) or not path.is_ancestor_of(c): errors.append(id + ": parent this marker/socket under its referenced path in this level.")
				var point: Vector3 = path.to_local(c.global_position)
				var normal: Vector3 = path.global_basis.inverse() * c.global_basis * c.ground_normal
				if not valid_contact(path, point, normal): errors.append(id + ": marker/socket is not on its path with matching ground.")
				if c.kind in [C.Kind.SOCKET, C.Kind.THRESHOLD]:
					var side: Vector3 = path.global_basis.inverse() * c.global_basis * c.travel_direction.cross(c.ground_normal).normalized() * c.width / 2
					if not valid_contact(path, point + side, normal) or not valid_contact(path, point - side, normal): errors.append(id + ": socket opening extends beyond its walking region.")
				if c.kind == C.Kind.START and not path.active: errors.append(id + ": starting path is inactive.")
				if c.kind == C.Kind.THRESHOLD:
					# A doorway stands at the edge of its walking region: just beyond it is not ground.
					var beyond: Vector3 = path.global_basis.inverse() * c.global_basis * c.travel_direction.normalized() * .1
					if valid_contact(path, point + beyond, normal): errors.append(id + ": a threshold must stand at the edge of its path.")
			if c.kind == C.Kind.START:
				starts.append(c)
				if c.forward.length() < .99 or absf(c.forward.normalized().dot(c.ground_normal.normalized())) > .01: errors.append(id + ": forward must be a nonzero ground tangent.")
			if c.kind == C.Kind.GOAL: goals.append(c)
			if c.kind == C.Kind.THRESHOLD and (c.aperture_height <= 0 or c.link_group.is_empty()): errors.append(id + ": a threshold needs a positive aperture height and a link group.")
			if c.kind in [C.Kind.SOCKET, C.Kind.THRESHOLD] and (c.width <= 0 or c.ground_normal.length() < .99 or c.travel_direction.length() < .99 or absf(c.ground_normal.normalized().dot(c.travel_direction.normalized())) > .01): errors.append(id + ": invalid width or socket frame.")
		if c.kind == C.Kind.INTERACTION:
			var target = c.get_node_or_null(c.target)
			var expected := C.Kind.PATH if c.effect == 0 else C.Kind.ROTATOR
			if not target is C or not level.is_ancestor_of(target) or (target.kind != expected and not (c.effect == 0 and target.kind == C.Kind.CURVE)): errors.append(id + ": interaction target must be a compatible component in this level.")
			if c.condition_state >= 0:
				var condition = c.get_node_or_null(c.condition_structure)
				if not condition is C or not level.is_ancestor_of(condition) or condition.kind != C.Kind.ROTATOR or c.condition_state >= condition.state_count(): errors.append(id + ": invalid required structure state.")
	if starts.size() != 1: errors.append("Author exactly one PlayerStart.")
	if goals.size() != 1: errors.append("Author exactly one Goal.")
	if rotations == 0: warnings.append("No rotatable structure: valid traversal study, but no transformation puzzle.")
	var sockets := Links.descriptors(level)
	for threshold in Links.thresholds(level):
		for socket in sockets:
			if socket.path == threshold.path and socket.position.distance_to(threshold.position) < threshold.width / 2:
				errors.append(threshold.id + ": a threshold's edge must not also be an ordinary socket (turn off end_sockets there).")
	for socket in sockets:
		var joined := false
		for other in sockets:
			if Links.compatible(socket, other): joined = true
		if socket.active and not joined: warnings.append(str(level.get_path_to(socket.path)) + ": open socket in this configuration (may be intentional).")
	return {"errors": errors, "warnings": warnings}

static func valid_contact(path: Node3D, point: Vector3, normal: Vector3) -> bool:
	if path.kind == C.Kind.PATH:
		if absf(point.y) >= .025 or normal.normalized().dot(Vector3.UP) <= .998: return false
		var regions: Array = path.regions if not path.regions.is_empty() else [Rect2(-path.dimensions.x / 2, -path.dimensions.z / 2, path.dimensions.x, path.dimensions.z)]
		for region in regions:
			if region.grow(.001).has_point(Vector2(point.x, point.z)): return true
		return false
	var curve = preload("res://core/gravity_path.gd").new()
	curve.radius = path.radius
	curve.arc = deg_to_rad(float(path.arc_degrees))
	curve.path_width = path.dimensions.z
	curve.tail_length = path.tail
	var valid: bool = curve.allows_point(point, normal.normalized())
	curve.free()
	return valid
