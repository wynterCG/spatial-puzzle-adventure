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
var third_person := true
var camera_distance := 5.5
var orbit_yaw := 0.0
var orbit_pitch := 0.42
var orbit_heading := Vector3.FORWARD
var keep_world_horizon := true
var follow_frame := Basis.IDENTITY
var camera_initialized := false
var world_orbit_initialized := false
var world_orbit_heading := Vector3.FORWARD
var avoidance_yaw := 0.0
var avoidance_pitch := 0.42
var arm_length := 5.5
var last_walk_input := Vector2.ZERO
var orbit_changed := false
var movement_frame_initialized := false
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

func place(piece: SurfacePiece, point: Vector3, up := Vector3.UP, heading := Vector3.FORWARD, preserve_orbit := false) -> void:
	var previous_orbit := support.global_basis * orbit_heading if support != null else heading
	support = piece
	foot = point
	normal = up
	forward = heading
	if preserve_orbit:
		orbit_heading = (piece.global_basis.inverse() * previous_orbit).slide(up).normalized()
	else:
		orbit_heading = heading
		orbit_yaw = 0.0
	if not preserve_orbit:
		pitch = -0.08
	moving = false
	last_walk_input = Vector2.ZERO
	movement_frame_initialized = false
	sync_pose(1.0)

func look(relative: Vector2) -> void:
	if third_person:
		orbit_yaw -= relative.x * sensitivity
		orbit_pitch = clampf(orbit_pitch + relative.y * sensitivity, 0.12, 1.0)
		# Pitch changes the view, not the direction of travel on the track.
		if keep_world_horizon and movement_frame_initialized:
			# Apply mouse yaw to the transported control frame continuously. Its
			# tangent component goes to zero on a vertical wall, rather than
			# projecting screen-up again and reversing forward at that point.
			var yaw_on_ground := (support.global_basis * normal).dot(Vector3.UP)
			forward = forward.rotated(normal, -relative.x * sensitivity * yaw_on_ground).normalized()
		else:
			orbit_changed = orbit_changed or absf(relative.x) > 0.001
		return
	forward = forward.rotated(normal, -relative.x * sensitivity).normalized()
	pitch = clampf(pitch - relative.y * sensitivity, -1.35, 1.35)

func align_movement_to_camera(_input: Vector2) -> void:
	if not third_person:
		return
	# Transport the controls with the ground, including across key releases and
	# blocked steps. A world-upright screen reverses its projected 'up' on a loop;
	# recalculating after every stop made W turn around or stall halfway through.
	# Automatic camera avoidance must never establish a new movement frame.
	if movement_frame_initialized and not orbit_changed:
		return
	orbit_changed = false
	var world_up := (support.global_basis * normal).normalized()
	# Screen-up projected onto the surface keeps W intuitive on walls/undersides.
	var screen_up := camera.global_basis.y.slide(world_up)
	if screen_up.length_squared() < 0.02:
		screen_up = (-camera.global_basis.z).slide(world_up)
	if screen_up.length_squared() > 0.001:
		forward = (support.global_basis.inverse() * screen_up.normalized()).normalized()
		movement_frame_initialized = true

func set_third_person(enabled: bool) -> void:
	third_person = enabled
	# Returning from first person must preserve the tangent heading too, rather
	# than reversing it because the world-upright camera sees a different 'up'.
	movement_frame_initialized = enabled and keep_world_horizon
	camera_initialized = false
	sync_pose(1.0)

func walk(input: Vector2, delta: float) -> void:
	last_walk_input = input
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
		var local := other.to_local(world_next)
		var up := (other.global_basis.inverse() * world_normal).normalized()
		if not other.allows_point(local, up) or not pose_is_clear(other, local, up):
			continue
		forward = other.global_basis.inverse() * (support.global_basis * forward)
		orbit_heading = other.global_basis.inverse() * (support.global_basis * orbit_heading)
		support = other
		foot = other.constrain_to_path(local)
		var transport := Basis(Quaternion(up, other.surface_frame(foot).y))
		forward = (transport * forward).normalized()
		orbit_heading = (transport * orbit_heading).normalized()
		normal = other.surface_frame(foot).y
		changed_surface.emit()
		return other.global_basis * transport * (other.global_basis.inverse() * world_direction)
	# Ordinary edges are boundaries. No face folding, gravity snapping or wrapping.
	next = support.step_contact(foot, direction, distance)
	var next_normal := support.surface_frame(next).y
	if support.allows_point(next, next_normal) and pose_is_clear(support, next, next_normal):
		var transport := support.surface_frame(next) * support.surface_frame(foot).inverse()
		forward = (transport * forward).normalized()
		orbit_heading = (transport * orbit_heading).normalized()
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
	camera.cull_mask = 23 if third_person else 19
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
	var heading := (support.global_basis * orbit_heading.rotated(normal, orbit_yaw)).normalized()
	var arm_up := up
	if keep_world_horizon:
		if not world_orbit_initialized:
			world_orbit_heading = (-camera.global_basis.z if camera_initialized else support.global_basis * orbit_heading).slide(Vector3.UP)
			if world_orbit_heading.length_squared() < 0.01:
				world_orbit_heading = Vector3.FORWARD
			else:
				world_orbit_heading = world_orbit_heading.normalized()
			# Capture the base azimuth, avoiding an extra yaw when enabling it.
			if camera_initialized:
				world_orbit_heading = world_orbit_heading.rotated(Vector3.UP, -orbit_yaw)
			world_orbit_initialized = true
		heading = world_orbit_heading.rotated(Vector3.UP, orbit_yaw)
		arm_up = Vector3.UP
		camera.global_position = world_follow_position(pivot, -heading, delta)
		camera.look_at(pivot, Vector3.UP)
		camera_initialized = true
		return
	else:
		world_orbit_initialized = false
	var target_frame := Basis(heading.cross(arm_up).normalized(), arm_up, -heading).orthonormalized()
	var weight := 1.0 if not camera_initialized or delta >= 1.0 or reduced_motion else 1.0 - exp(-delta * 10.0)
	# Ease a transported frame, not world XYZ. This keeps the arm behind the
	# traveller, retains orbit distance, and follows rotating supports as well.
	follow_frame = follow_frame.slerp(target_frame, weight).orthonormalized()
	var offset := (follow_frame.z * cos(orbit_pitch) + follow_frame.y * sin(orbit_pitch)) * camera_distance
	var desired := pivot + offset
	var safe := safe_camera_position(pivot, desired)
	# A slow turn through the old face can obstruct the eased arm. The new face
	# provides a clear fallback, instead of collapsing the camera onto the head.
	if safe.distance_to(pivot) < minf(2.0, camera_distance * 0.5):
		var settled_offset := (target_frame.z * cos(orbit_pitch) + arm_up * sin(orbit_pitch)) * camera_distance
		var fallback := safe_camera_position(pivot, pivot + settled_offset)
		if fallback.distance_to(pivot) > safe.distance_to(pivot):
			safe = fallback
	camera.global_position = safe
	var view_direction := pivot - camera.global_position
	var view_up := follow_frame.y
	if view_direction.length_squared() > 0.001 and view_direction.normalized().cross(view_up).length_squared() > 0.00001:
		camera.look_at(pivot, view_up)
	camera_initialized = true

func world_follow_position(pivot: Vector3, back: Vector3, delta: float) -> Vector3:
	# Stay on a world-up orbit, including during obstruction avoidance. Switching
	# to a surface-relative arm here used to teleport across the player on curves.
	var requested_yaw := atan2(back.x, back.z)
	if not camera_initialized:
		avoidance_yaw = requested_yaw
		avoidance_pitch = orbit_pitch
		arm_length = camera_distance
	var best_yaw := requested_yaw
	var best_pitch := orbit_pitch
	var best_cost := INF
	for yaw_offset in [0.0, 0.35, -0.35, 0.7, -0.7, 1.05, -1.05, 1.57, -1.57, 2.1, -2.1, PI]:
		for elevation in [orbit_pitch, 0.0, -orbit_pitch]:
			var candidate_yaw: float = requested_yaw + yaw_offset
			var candidate_direction := Vector3(sin(candidate_yaw) * cos(elevation), sin(elevation), cos(candidate_yaw) * cos(elevation))
			# Plan with a wider envelope than the final camera collision probe so
			# avoidance starts before a thin edge enters the line of sight.
			var candidate_clearance := pivot.distance_to(safe_camera_position(pivot, pivot + candidate_direction * camera_distance, 0.65))
			var continuity := angle_difference(avoidance_yaw, candidate_yaw)
			var cost: float = pow(camera_distance - candidate_clearance, 2) * 4.0 + yaw_offset * yaw_offset * 0.3 + pow(elevation - orbit_pitch, 2) * 0.3 + continuity * continuity + pow(elevation - avoidance_pitch, 2)
			if cost < best_cost:
				best_cost = cost
				best_yaw = candidate_yaw
				best_pitch = elevation
	if not camera_initialized:
		avoidance_yaw = best_yaw
		avoidance_pitch = best_pitch
	elif delta < 1.0:
		# Bound angular travel even when the best free direction changes suddenly.
		avoidance_yaw += clampf(angle_difference(avoidance_yaw, best_yaw), -4.0 * delta, 4.0 * delta)
		avoidance_pitch = move_toward(avoidance_pitch, best_pitch, 3.0 * delta)
	var direction := Vector3(sin(avoidance_yaw) * cos(avoidance_pitch), sin(avoidance_pitch), cos(avoidance_yaw) * cos(avoidance_pitch))
	var available := pivot.distance_to(safe_camera_position(pivot, pivot + direction * camera_distance))
	# Retract for real obstructions, but ease out as the view clears.
	if not camera_initialized:
		arm_length = available
	elif delta < 1.0:
		arm_length = minf(available, lerpf(arm_length, available, 1.0 - exp(-delta * 7.0)))
	else:
		arm_length = minf(arm_length, available)
	return pivot + direction * maxf(0.001, arm_length)

func safe_camera_position(pivot: Vector3, desired: Vector3, padding := 0.18) -> Vector3:
	var fraction := 1.0
	var solids: Array[Node3D] = []
	for piece in pieces:
		solids.append_array(piece.solid_meshes)
	solids.append_array(camera_obstacles)
	for solid in solids:
		if not solid.is_visible_in_tree():
			continue
		var origin := solid.to_local(pivot)
		var ray := solid.to_local(desired) - origin
		var half_size: Vector3 = (solid.mesh as BoxMesh).size * 0.5
		var bounds := half_size + Vector3.ONE * padding
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
	return {"piece": support.name, "foot": foot, "normal": normal, "forward": forward, "pitch": pitch, "orbit_heading": orbit_heading, "orbit_yaw": orbit_yaw, "orbit_pitch": orbit_pitch, "world_orbit_heading": world_orbit_heading}

func restore(data: Dictionary, root: Node) -> void:
	support = root.get_node(NodePath(data.piece)) as SurfacePiece
	foot = data.foot
	normal = data.normal
	forward = data.forward
	pitch = data.pitch
	orbit_heading = data.get("orbit_heading", forward)
	orbit_yaw = data.get("orbit_yaw", 0.0)
	orbit_pitch = clampf(data.get("orbit_pitch", 0.42), 0.12, 1.0)
	world_orbit_heading = data.get("world_orbit_heading", Vector3.FORWARD)
	world_orbit_initialized = data.has("world_orbit_heading")
	movement_frame_initialized = true
	camera_initialized = false
	sync_pose(1.0)
