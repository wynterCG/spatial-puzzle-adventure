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
var follow_elevation := 0.42
var arm_length := 5.5
var last_walk_input := Vector2.ZERO
var orbit_changed := false
var movement_frame_initialized := false
var movement_right_sign := 1.0
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
	for piece in pieces:
		if piece.transports_controls():
			piece.update_camera_cutaway(camera, avatar.to_global(Vector3(0, .85, 0)), not enabled and third_person and keep_world_horizon)
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
		orbit_changed = orbit_changed or absf(relative.x) > 0.001
		return
	forward = forward.rotated(normal, -relative.x * sensitivity).normalized()
	pitch = clampf(pitch - relative.y * sensitivity, -1.35, 1.35)

func align_movement_to_camera(input: Vector2) -> void:
	if not third_person:
		return
	# Only the authored curve transports the control frame through key releases.
	# On flat platforms, each fresh gesture is relative to the visible camera.
	if support.transports_controls() and movement_frame_initialized:
		orbit_changed = false
		return
	if input.length_squared() < .01:
		movement_frame_initialized = false
		return
	# A blocked held key is still the same gesture: don't reverse it at an edge.
	if movement_frame_initialized and last_walk_input.length_squared() > .01 and not orbit_changed:
		return
	if orbit_changed and keep_world_horizon:
		# Input is handled before the frame's camera update. Apply the requested
		# yaw first so a single mouse event cannot latch yesterday's direction.
		sync_pose(0.0)
	orbit_changed = false
	var world_up := (support.global_basis * normal).normalized()
	# Screen-up projected onto the surface keeps W intuitive on walls/undersides.
	var screen_up := camera.global_basis.y.slide(world_up)
	if screen_up.length_squared() < 0.02:
		screen_up = (-camera.global_basis.z).slide(world_up)
	if screen_up.length_squared() > 0.001:
		forward = (support.global_basis.inverse() * screen_up.normalized()).normalized()
		var world_right := support.global_basis * forward.cross(normal)
		movement_right_sign = 1.0 if world_right.dot(camera.global_basis.x) >= 0 else -1.0
		movement_frame_initialized = true

func set_third_person(enabled: bool) -> void:
	third_person = enabled
	# Returning from first person must preserve the tangent heading too, rather
	# than reversing it because the world-upright camera sees a different 'up'.
	movement_frame_initialized = enabled and support.transports_controls()
	camera_initialized = false
	sync_pose(1.0)

func walk(input: Vector2, delta: float) -> void:
	last_walk_input = input
	if input.length() < 0.01:
		moving = false
		return
	var right := forward.cross(normal).normalized() * (movement_right_sign if third_person else 1.0)
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
		camera.global_position = world_follow_position(pivot, -heading, up, delta)
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

func world_follow_position(pivot: Vector3, back: Vector3, up: Vector3, delta: float) -> Vector3:
	# Mouse yaw owns the azimuth. Obstacles may shorten the arm, never orbit it.
	# Lower the arm continuously as the ground turns upside down; keep the
	# screen world-upright and avoid the poles of a world-up look-at frame.
	var target_elevation := orbit_pitch * up.dot(Vector3.UP)
	if not camera_initialized:
		follow_elevation = target_elevation
	elif delta < 1.0:
		follow_elevation = lerpf(follow_elevation, target_elevation, 1.0 - exp(-delta * 12.0))
	var direction := back * cos(follow_elevation) + Vector3.UP * sin(follow_elevation)
	var available := pivot.distance_to(safe_camera_position(pivot, pivot + direction * camera_distance, .18, true))
	var anticipated := available
	if moving and last_walk_input.length_squared() > .01:
		var right := forward.cross(normal) * movement_right_sign
		var travel := (right * last_walk_input.x - forward * last_walk_input.y).normalized()
		# Look ahead along the same authored path. Start shortening before a
		# corner enters the sightline instead of snapping inward at that frame.
		for seconds in [.2, .4, .6, .8]:
			var ahead := support.step_contact(foot, travel, speed * seconds)
			var ahead_up := support.global_basis * support.surface_frame(ahead).y
			var ahead_pivot := support.to_global(ahead) + ahead_up * .85
			var ahead_elevation := orbit_pitch * ahead_up.dot(Vector3.UP)
			var ahead_direction := back * cos(ahead_elevation) + Vector3.UP * sin(ahead_elevation)
			anticipated = minf(anticipated, ahead_pivot.distance_to(safe_camera_position(ahead_pivot, ahead_pivot + ahead_direction * camera_distance, .18, true)))
	# Real geometry remains the hard limit; anticipation makes normal traversal
	# reach that limit gradually. No sideways search changes the mouse's azimuth.
	if not camera_initialized:
		arm_length = available
	elif delta < 1.0:
		arm_length = minf(available, move_toward(arm_length, anticipated, delta * (12.0 if anticipated < arm_length else 4.0)))
	else:
		arm_length = minf(arm_length, available)
	return pivot + direction * maxf(0.001, arm_length)

func safe_camera_position(pivot: Vector3, desired: Vector3, padding := 0.18, cutaway_curves := false) -> Vector3:
	var fraction := 1.0
	var solids: Array[Node3D] = []
	for piece in pieces:
		if cutaway_curves and piece.transports_controls():
			continue
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
	return {"piece": support.name, "foot": foot, "normal": normal, "forward": forward, "pitch": pitch, "orbit_heading": orbit_heading, "orbit_yaw": orbit_yaw, "orbit_pitch": orbit_pitch, "world_orbit_heading": world_orbit_heading, "movement_right_sign": movement_right_sign}

func restore(data: Dictionary, root: Node) -> void:
	support = root.get_node(NodePath(data.piece)) as SurfacePiece
	foot = data.foot
	normal = data.normal
	forward = data.forward
	movement_right_sign = data.get("movement_right_sign", 1.0)
	pitch = data.pitch
	orbit_heading = data.get("orbit_heading", forward)
	orbit_yaw = data.get("orbit_yaw", 0.0)
	orbit_pitch = clampf(data.get("orbit_pitch", 0.42), 0.12, 1.0)
	world_orbit_heading = data.get("world_orbit_heading", Vector3.FORWARD)
	world_orbit_initialized = data.has("world_orbit_heading")
	movement_frame_initialized = true
	camera_initialized = false
	sync_pose(1.0)
