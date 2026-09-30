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
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.32
	ring_mesh.outer_radius = 0.40
	ring.mesh = ring_mesh
	ring.material_override = mat
	avatar.add_child(ring)
	ring.position.y = 0.035

func place(piece: SurfacePiece, point: Vector3, up := Vector3.UP, heading := Vector3.FORWARD) -> void:
	support = piece
	foot = point
	normal = up
	forward = heading
	pitch = -0.08
	sync_pose(1.0)

func look(relative: Vector2) -> void:
	forward = forward.rotated(normal, -relative.x * sensitivity).normalized()
	pitch = clampf(pitch - relative.y * sensitivity, -1.35, 1.35)

func walk(input: Vector2, delta: float) -> void:
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
	var target := Transform3D(orientation * Basis(Vector3.RIGHT, pitch), contact + up * 1.55)
	if reduced_motion or delta >= 1.0:
		camera.global_transform = target
	else:
		camera.global_transform = camera.global_transform.interpolate_with(target, 1.0 - exp(-delta * 16.0))

func snapshot() -> Dictionary:
	return {"piece": support.name, "foot": foot, "normal": normal, "forward": forward, "pitch": pitch}

func restore(data: Dictionary, root: Node) -> void:
	support = root.get_node(NodePath(data.piece)) as SurfacePiece
	foot = data.foot
	normal = data.normal
	forward = data.forward
	pitch = data.pitch
	sync_pose(1.0)
