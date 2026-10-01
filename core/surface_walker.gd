class_name SurfaceWalker
extends Node3D
## Deterministic surface constraint, not nearest-object gravity.
## Position, normal and heading are stored in the support's coordinate frame.

var support: SurfacePiece
var pieces: Array[SurfacePiece] = []
var camera_obstacles: Array[MeshInstance3D] = []
var foot := Vector3.ZERO
var normal := Vector3.UP
var forward := Vector3.FORWARD
var pitch := -0.08
var speed := 3.5
var sensitivity := 0.0022
var reduced_motion := false
var camera: Camera3D
var avatar: Node3D
var overview_silhouette: Node3D
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
	# A separate overview-only layer keeps the traveller readable behind masonry.
	overview_silhouette = Node3D.new()
	avatar.add_child(overview_silhouette)
	var silhouette_material := StandardMaterial3D.new()
	silhouette_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	silhouette_material.no_depth_test = true
	silhouette_material.albedo_color = Color("ffd89a")
	for source in [torso, dot, ring]:
		var silhouette := MeshInstance3D.new()
		silhouette.mesh = source.mesh
		silhouette.transform = source.transform
		silhouette.material_override = silhouette_material
		silhouette.layers = 8
		silhouette.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		overview_silhouette.add_child(silhouette)
	overview_silhouette.hide()

func update_overview_visibility(view: Camera3D, enabled: bool) -> void:
	overview_silhouette.visible = false
	if not enabled:
		return
	# Parallel rays are essential for orthographic projection. Perspective camera
	# position would incorrectly classify masonry beside the actual sightline.
	for height in [0.65, 1.3]:
		var point := avatar.to_global(Vector3(0, height, 0))
		var origin := view.project_ray_origin(view.unproject_position(point))
		for piece in pieces:
			for solid in piece.solid_meshes:
				if not solid.is_visible_in_tree():
					continue
				var size: Vector3 = (solid.mesh as BoxMesh).size
				if AABB(-size * 0.5, size).intersects_segment(solid.to_local(origin), solid.to_local(point)):
					overview_silhouette.visible = true
					return
		for solid in camera_obstacles:
			if not solid.is_visible_in_tree() or (solid.layers & view.cull_mask) == 0:
				continue
			var size: Vector3 = (solid.mesh as BoxMesh).size
			if AABB(-size * 0.5, size).intersects_segment(solid.to_local(origin), solid.to_local(point)):
				overview_silhouette.visible = true
				return

func place(piece: SurfacePiece, point: Vector3, up := Vector3.UP, heading := Vector3.FORWARD) -> void:
	support = piece
	foot = point
	normal = up
	forward = heading
	pitch = -0.08
	moving = false
	sync_pose(1.0)

func look(relative: Vector2) -> void:
	forward = forward.rotated(normal, -relative.x * sensitivity).normalized()
	pitch = clampf(pitch - relative.y * sensitivity, -1.35, 1.35)

func walk(input: Vector2, delta: float) -> void:
	if input.length() < 0.01:
		moving = false
		return
	var right := forward.cross(normal).normalized()
	var direction := (right * input.x - forward * input.y).normalized()
	var distance := speed * delta
	var count := maxi(1, int(ceil(distance / 0.08)))
	var world_direction := support.global_basis * direction
	var travelled := 0.0
	for i in range(count):
		var before := support.to_global(foot)
		world_direction = advance(world_direction, distance / count)
		travelled += before.distance_to(support.to_global(foot))
	moving = travelled > 0.0001
	step_distance += travelled
	if step_distance > 1.5:
		step_distance = 0.0
		stepped.emit()

func advance(world_direction: Vector3, distance: float) -> Vector3:
	var direction := (support.global_basis.inverse() * world_direction).slide(normal).normalized()
	var next := foot + direction * distance
	var world_next := support.to_global(next)
	var world_normal := support.global_basis * normal
	# Authored, settled graph AND touching compatible walking regions are required.
	for other in support.neighbours:
		if not support.allows_connection(other, world_next): continue
		var local := other.to_local(world_next)
		var up := (other.global_basis.inverse() * world_normal).normalized()
		if not other.allows_point(local, up) or not pose_is_clear(other, local, up):
			continue
		forward = other.global_basis.inverse() * (support.global_basis * forward)
		support = other
		foot = other.constrain_to_path(local)
		var transport := Basis(Quaternion(up, other.surface_frame(foot).y))
		forward = (transport * forward).normalized()
		normal = other.surface_frame(foot).y
		changed_surface.emit()
		return other.global_basis * transport * (other.global_basis.inverse() * world_direction)
	# Ordinary edges are boundaries. No face folding, gravity snapping or wrapping.
	next = support.step_contact(foot, direction, distance)
	var next_normal := support.surface_frame(next).y
	if support.allows_point(next, next_normal) and pose_is_clear(support, next, next_normal):
		var transport := support.surface_frame(next) * support.surface_frame(foot).inverse()
		forward = (transport * forward).normalized()
		foot = next
		normal = next_normal
		return support.global_basis * transport * direction
	return world_direction

func pose_is_clear(piece: SurfacePiece, point: Vector3, up: Vector3) -> bool:
	for height in [0.18, 0.8, 1.55]:
		var centre: Vector3 = piece.to_global(point + up * height)
		for other in pieces:
			if other == piece:
				continue
			var local := other.to_local(centre)
			if other.contains_solid(local, 0.10):
				return false
	for obstacle in camera_obstacles:
		if not obstacle.is_visible_in_tree():
			continue
		var bounds: Vector3 = (obstacle.mesh as BoxMesh).size * 0.5
		for height in [0.25, 0.8, 1.55]:
			var local := obstacle.to_local(piece.to_global(point + up * height)).abs()
			if local.x < bounds.x + 0.16 and local.y < bounds.y + 0.16 and local.z < bounds.z + 0.16:
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
	camera.cull_mask = 19
	var target := Transform3D(orientation * Basis(Vector3.RIGHT, pitch), contact + up * 1.55)
	if reduced_motion or delta >= 1.0:
		camera.global_transform = target
	else:
		camera.global_transform = camera.global_transform.interpolate_with(target, 1.0 - exp(-delta * 16.0))

func snapshot() -> Dictionary:
	return {"piece": support.name, "foot": foot, "normal": normal, "forward": forward, "pitch": pitch}

## Older saves may carry third-person keys; they are ignored.
func restore(data: Dictionary, root: Node) -> void:
	support = root.get_node(NodePath(data.piece)) as SurfacePiece
	foot = data.foot
	normal = data.normal
	forward = data.forward
	pitch = data.pitch
	moving = false
	sync_pose(1.0)
