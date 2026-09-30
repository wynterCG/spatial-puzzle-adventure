class_name SurfaceWalker
extends Node3D
## Deterministic surface constraint, not nearest-object gravity.
## Position, normal and heading are stored in the support's coordinate frame.

var support: SurfacePiece
var pieces: Array[SurfacePiece] = []
var foot := Vector3.ZERO
var normal := Vector3.UP
var forward := Vector3.FORWARD
var pitch := -0.08
var speed := 3.5
var sensitivity := 0.0022
var reduced_motion := false
var third_person := true
var camera_distance := 5.5
var orbit_yaw := 0.0
var orbit_pitch := 0.42
var camera_initialized := false
var last_walk_input := Vector2.ZERO
var orbit_changed := false
var camera: Camera3D
var avatar: Node3D
var moving := false
var edge_count := 0
var step_distance := 0.0
signal stepped
signal changed_surface

func _ready() -> void:
	camera = Camera3D.new()
	camera.near = 0.07
	camera.fov = 76
	add_child(camera)
	avatar = Node3D.new()
	add_child(avatar)
	var mat := SurfacePiece.material(Color("ffe2ac"), 0.5)
	var torso := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.18
	capsule.height = 0.85
	torso.mesh = capsule
	torso.material_override = mat
	avatar.add_child(torso)
	torso.position.y = 0.65
	var dot := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.21
	sphere.height = 0.42
	dot.mesh = sphere
	dot.material_override = mat
	avatar.add_child(dot)
	dot.position.y = 1.3
	# A small visor makes heading readable from the follow camera.
	SurfacePiece.box(avatar, Vector3(0, 1.32, -0.19), Vector3(0.28, 0.11, 0.07), SurfacePiece.material(Color("29374f")))
	SurfacePiece.box(avatar, Vector3(0, 0.88, 0.19), Vector3(0.3, 0.38, 0.12), SurfacePiece.material(Color("b57d67")))
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.32
	ring_mesh.outer_radius = 0.40
	ring.mesh = ring_mesh
	ring.material_override = mat
	avatar.add_child(ring)
	ring.position.y = 0.035
	for part in avatar.get_children():
		if part is MeshInstance3D:
			part.layers = 4

func place(piece: SurfacePiece, point: Vector3, up := Vector3.UP, heading := Vector3.FORWARD) -> void:
	support = piece
	foot = point
	normal = up
	forward = heading
	pitch = -0.08
	moving = false
	last_walk_input = Vector2.ZERO
	sync_pose(1.0)

func look(relative: Vector2) -> void:
	if third_person:
		orbit_yaw -= relative.x * sensitivity
		orbit_pitch = clampf(orbit_pitch + relative.y * sensitivity, -1.0, 1.0)
		orbit_changed = true
		return
	forward = forward.rotated(normal, -relative.x * sensitivity).normalized()
	pitch = clampf(pitch - relative.y * sensitivity, -1.35, 1.35)

func align_movement_to_camera(input: Vector2) -> void:
	if not third_person:
		return
	# Keep a held direction parallel-transported across an edge. Reprojecting W
	# halfway through a fold would immediately send the player back up the wall.
	if input.length_squared() > 0.01 and moving and input.is_equal_approx(last_walk_input) and not orbit_changed:
		return
	orbit_changed = false
	var world_up := (support.global_basis * normal).normalized()
	# Screen-up projected onto the surface keeps W intuitive on walls/undersides.
	var screen_up := camera.global_basis.y.slide(world_up)
	if screen_up.length_squared() < 0.02:
		screen_up = (-camera.global_basis.z).slide(world_up)
	if screen_up.length_squared() > 0.001:
		forward = (support.global_basis.inverse() * screen_up.normalized()).normalized()

func set_third_person(enabled: bool) -> void:
	third_person = enabled
	camera_initialized = false
	sync_pose(1.0)

func walk(input: Vector2, delta: float) -> void:
	last_walk_input = input
	if input.length() < 0.01:
		moving = false
		return
	moving = true
	var right := forward.cross(normal).normalized()
	var direction := (right * input.x - forward * input.y).normalized()
	var distance := speed * delta
	# Small substeps prevent skipping seams at low frame rates.
	var count := maxi(1, int(ceil(distance / 0.08)))
	var world_direction := support.global_basis * direction
	for i in range(count):
		world_direction = advance(world_direction, distance / count)
	step_distance += distance
	if step_distance > 1.5:
		step_distance = 0.0
		stepped.emit()

func advance(world_direction: Vector3, distance: float) -> Vector3:
	var direction := (support.global_basis.inverse() * world_direction).slide(normal).normalized()
	var next := foot + direction * distance
	var world_next := support.to_global(next)
	var world_normal := support.global_basis * normal
	# Real contact on a matching plane is the only cross-piece transfer.
	for other in pieces:
		if other == support:
			continue
		var local := other.to_local(world_next)
		var up := other.global_basis.inverse() * world_normal
		var face := up.abs().max_axis_index()
		if absf(up[face]) < 0.999:
			continue
		if absf(local[face] - signf(up[face]) * other.half[face]) > 0.025:
			continue
		var inside := true
		for axis in range(3):
			if axis != face and absf(local[axis]) > other.half[axis] + 0.001:
				inside = false
		if inside:
			if not pose_is_clear(other, local, up.round()):
				return world_direction
			forward = other.global_basis.inverse() * (support.global_basis * forward)
			support = other
			foot = local
			normal = up.round()
			changed_surface.emit()
			return world_direction
	# Fold excess distance around the first crossed edge. Tie-break uses XYZ order.
	var face_axis := normal.abs().max_axis_index()
	var next_normal := normal
	var next_forward := forward
	var folded := false
	for axis in range(3):
		if axis == face_axis or absf(next[axis]) <= support.half[axis]:
			continue
		var sign_axis := signf(next[axis])
		var excess := absf(next[axis]) - support.half[axis]
		var new_normal := Vector3.ZERO
		new_normal[axis] = sign_axis
		var rotation_axis := normal.cross(new_normal).normalized()
		next_forward = forward.rotated(rotation_axis, PI * 0.5).normalized()
		direction = direction.rotated(rotation_axis, PI * 0.5).normalized()
		next[axis] = sign_axis * support.half[axis]
		next[face_axis] -= normal[face_axis] * excess
		next_normal = new_normal
		folded = true
		break
	# Shared internal faces are solid, not a route through the adjoining volume.
	if not pose_is_clear(support, next, next_normal):
		return world_direction
	foot = next
	normal = next_normal
	forward = next_forward
	if folded:
		edge_count += 1
		# Observers and checkpoints must see the committed contact and frame.
		changed_surface.emit()
	return support.global_basis * direction

func pose_is_clear(piece: SurfacePiece, point: Vector3, up: Vector3) -> bool:
	for height in [0.18, 0.8, 1.55]:
		var centre: Vector3 = piece.to_global(point + up * height)
		for other in pieces:
			if other == piece:
				continue
			var local := other.to_local(centre)
			if absf(local.x) < other.half.x + 0.10 and absf(local.y) < other.half.y + 0.10 and absf(local.z) < other.half.z + 0.10:
				return false
	return true

func sync_pose(delta: float) -> void:
	if support == null:
		return
	var up := (support.global_basis * normal).normalized()
	var heading := (support.global_basis * forward).normalized()
	var right := heading.cross(up).normalized()
	var orientation := Basis(right, up, -heading).orthonormalized()
	var contact := support.to_global(foot)
	avatar.global_transform = Transform3D(orientation, contact)
	camera.cull_mask = 7 if third_person else 3
	if third_person:
		sync_follow_camera(contact, up, delta)
		return
	var target := Transform3D(orientation * Basis(Vector3.RIGHT, pitch), contact + up * 1.55)
	if reduced_motion or delta >= 1.0:
		camera.global_transform = target
	else:
		camera.global_transform = camera.global_transform.interpolate_with(target, 1.0 - exp(-delta * 16.0))

func sync_follow_camera(contact: Vector3, up: Vector3, delta: float) -> void:
	var pivot := contact + up * 0.85
	var orbit := Vector3(sin(orbit_yaw) * cos(orbit_pitch), sin(orbit_pitch), cos(orbit_yaw) * cos(orbit_pitch))
	var offset := orbit * camera_distance
	# Stay on the exposed side of the supporting face while retaining world-up roll.
	offset += up * maxf(0.0, 1.8 - offset.dot(up))
	# A wall turn should not unexpectedly zoom in just because the offset changed.
	offset = offset.normalized() * camera_distance
	var desired := pivot + offset
	var weight := 1.0 if not camera_initialized or delta >= 1.0 or reduced_motion else 1.0 - exp(-delta * 7.0)
	var smoothed := camera.global_position.lerp(desired, weight)
	# Clamp after smoothing: an edge turn must not sweep through the solid.
	camera.global_position = safe_camera_position(pivot, smoothed)
	var view_direction := pivot - camera.global_position
	if view_direction.length_squared() > 0.001 and Vector2(view_direction.x, view_direction.z).length_squared() > 0.00001:
		# Retain the last stable orientation at a pole; never substitute a rolled up-axis.
		camera.look_at(pivot, Vector3.UP)
	camera_initialized = true

func safe_camera_position(pivot: Vector3, desired: Vector3) -> Vector3:
	var fraction := 1.0
	for piece in pieces:
		var origin := piece.to_local(pivot)
		var ray := piece.to_local(desired) - origin
		var bounds := piece.half + Vector3.ONE * 0.18
		var enter := 0.0
		var leave := 1.0
		var intersects := true
		for axis in range(3):
			if absf(ray[axis]) < 0.00001:
				if absf(origin[axis]) > bounds[axis]:
					intersects = false
					break
			else:
				var first := (-bounds[axis] - origin[axis]) / ray[axis]
				var second := (bounds[axis] - origin[axis]) / ray[axis]
				enter = maxf(enter, minf(first, second))
				leave = minf(leave, maxf(first, second))
				if enter > leave:
					intersects = false
					break
		if intersects and leave > 0.0 and enter <= 1.0:
			fraction = minf(fraction, maxf(0.0, enter - 0.025))
	return pivot.lerp(desired, fraction)

func snapshot() -> Dictionary:
	return {"piece": support.name, "foot": foot, "normal": normal, "forward": forward, "pitch": pitch}

func restore(data: Dictionary, root: Node) -> void:
	support = root.get_node(NodePath(data.piece)) as SurfacePiece
	foot = data.foot
	normal = data.normal
	forward = data.forward
	pitch = data.pitch
	sync_pose(1.0)
