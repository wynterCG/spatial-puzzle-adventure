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
var sensitivity := 0.0022
var reduced_motion := false
var profile: LocomotionProfile = preload("res://core/locomotion.tres")
## Comfort setting: fastest the ground may turn the view on a gravity curve, deg/s.
const TURN_RATES := {"Gentle": 75.0, "Normal": 110.0, "Brisk": 150.0}
var turn_rate := 110.0
var fov := 72.0:
	set(value):
		fov = value
		if camera: camera.fov = value
## Heading-relative velocity (x right, y ahead), m/s, so momentum is carried through ground
## changes exactly as `forward` is.
var velocity := Vector2.ZERO
## The view's ground frame (right, up, back) in the support's space, eased towards the actual
## ground. Stored locally so a turning support carries it; mouse yaw rotates it directly.
var view_ground := Basis.IDENTITY
var bob_phase := 0.0
## Debug readouts (F3): current speed cap and the view's rotation rate, deg/s.
var speed_cap := 0.0
var view_rate := 0.0
## Isometric-only size of the traveller (the runtime sets it from the framing); 1 in first person.
var marker_scale := 1.0
var speed: float:
	get: return profile.walk_speed
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
	# At 0.04 the near plane's corners stay within 0.1 m of the eye even at FOV 95, so the eye
	# may stand 0.1 m from a wall at a dead end without clipping (eye-clearance probe).
	camera.near = 0.04
	add_child(camera)
	fov = profile.fov
	turn_rate = profile.max_gravity_turn_rate
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
	velocity = Vector2.ZERO
	sync_pose(1.0)

## Mouse look is immediate: the eased ground frame turns by exactly the same yaw.
func look(relative: Vector2) -> void:
	var yaw := Basis(normal, -relative.x * sensitivity)
	forward = (yaw * forward).normalized()
	view_ground = (yaw * view_ground).orthonormalized()
	pitch = clampf(pitch - relative.y * sensitivity, -1.35, 1.35)

## The ground frame the view eases towards, in the support's space.
func ground_frame() -> Basis:
	var right := forward.cross(normal).normalized()
	return Basis(right, normal, -forward.slide(normal).normalized()).orthonormalized()

func effective_turn_rate() -> float:
	return minf(turn_rate, TURN_RATES.Gentle) if reduced_motion else turn_rate

## On a gravity curve the ground turns at speed / radius; cap speed so the view never turns
## faster than the comfort rate.
func speed_limit() -> float:
	return minf(speed, deg_to_rad(effective_turn_rate()) * support.curvature_radius(foot))

## Moves the player for one frame of held input; returns the distance covered.
func walk(input: Vector2, delta: float) -> float:
	var wish := Vector2(input.x, -input.y).limit_length(1.0)
	var target := wish * speed
	var rate := speed / maxf(.001, profile.accel_time if wish != Vector2.ZERO else profile.decel_time)
	velocity = velocity.move_toward(target, rate * delta)
	var travelled := 0.0
	var time_left := delta
	var progress := false
	for guard in range(64):
		speed_cap = speed_limit()
		# A curve clamps at once, so the view never turns faster than the cap while slowing.
		velocity = velocity.limit_length(speed_cap)
		var v := velocity.length()
		if v < .001 or time_left <= .00001:
			break
		var step := minf(.08, v * time_left)
		var right := forward.cross(normal).normalized()
		var direction := (right * velocity.x + forward * velocity.y).normalized()
		var moved := advance(direction, step)
		if moved < .00001:
			moved = slide(direction, step)
		travelled += moved
		progress = progress or moved > .00001
		# Time is spent on the distance actually covered, so a step cut short at a seam
		# continues across it in the same frame instead of stuttering.
		time_left -= (moved if moved > .00001 else step) / v
	if not progress and wish != Vector2.ZERO:
		velocity = Vector2.ZERO
	moving = travelled > 0.0001
	bob_phase = fmod(bob_phase + travelled / profile.step_length * PI, TAU)
	step_distance += travelled
	if step_distance > 1.5:
		step_distance = 0.0
		stepped.emit()
	return travelled

## Moves up to `distance` along a support-local direction, crossing at most one seam.
## Returns the distance covered.
func advance(local_direction: Vector3, distance: float) -> float:
	var start := support.to_global(foot)
	var direction := local_direction.slide(normal).normalized()
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
		# Contact tolerance accepts a point a little short of the seam; snapping it onto the
		# neighbour would hop further than asked. Stop at this deck's end instead and cross on
		# the next sub-step.
		if start.distance_to(other.to_global(other.constrain_to_path(local))) > distance + .0001:
			continue
		var to_other := other.global_basis.inverse() * support.global_basis
		forward = to_other * forward
		view_ground = (to_other * view_ground).orthonormalized()
		support = other
		foot = other.constrain_to_path(local)
		var transport := Basis(Quaternion(up, other.surface_frame(foot).y))
		forward = (transport * forward).normalized()
		normal = other.surface_frame(foot).y
		changed_surface.emit()
		return start.distance_to(support.to_global(foot))
	# Ordinary edges are boundaries. No face folding, gravity snapping or wrapping.
	next = support.step_contact(foot, direction, distance)
	var next_normal := support.surface_frame(next).y
	if support.allows_point(next, next_normal) and pose_is_clear(support, next, next_normal):
		var transport := support.surface_frame(next) * support.surface_frame(foot).inverse()
		forward = (transport * forward).normalized()
		foot = next
		normal = next_normal
	return start.distance_to(support.to_global(foot))

## A blocked step slides along whichever of the ground's own axes moves furthest. A projection
## is never longer than the requested step, so sliding can't speed the player up.
func slide(direction: Vector3, step: float) -> float:
	var frame := support.surface_frame(foot)
	var best := 0.0
	var best_state: Array = []
	var origin := [support, foot, normal, forward, view_ground]
	for axis in [frame.x, frame.z]:
		var part: Vector3 = direction.project(axis)
		if part.length() < .05: continue
		var moved := advance(part.normalized(), step * part.length())
		if moved > best:
			best = moved
			best_state = [support, foot, normal, forward, view_ground]
		support = origin[0]; foot = origin[1]; normal = origin[2]; forward = origin[3]; view_ground = origin[4]
	if not best_state.is_empty():
		var crossed: bool = best_state[0] != support
		support = best_state[0]; foot = best_state[1]; normal = best_state[2]; forward = best_state[3]; view_ground = best_state[4]
		if crossed: changed_surface.emit()
	return best

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
	var target := ground_frame()
	var previous := camera.global_basis
	if delta >= 1.0:
		view_ground = target
	else:
		# Only the ground's orientation is eased; position stays rigid on the surface.
		view_ground = view_ground.slerp(target, 1.0 - exp(-delta * profile.view_ease_rate)).orthonormalized()
	var up := (support.global_basis * normal).normalized()
	var contact := support.to_global(foot)
	# The isometric marker is drawn larger on big compositions; first person keeps it at 1.
	avatar.global_transform = Transform3D((support.global_basis * target).scaled(Vector3.ONE * marker_scale), contact)
	camera.cull_mask = 19
	var bob := 0.0
	if not reduced_motion and not support.transports_controls():
		bob = profile.head_bob * sin(bob_phase) * clampf(velocity.length() / speed, 0, 1)
	camera.global_transform = Transform3D((support.global_basis * view_ground * Basis(Vector3.RIGHT, pitch)).orthonormalized(), contact + up * (profile.eye_height + bob))
	if delta > 0 and delta < 1.0:
		view_rate = rad_to_deg(previous.get_rotation_quaternion().angle_to(camera.global_basis.get_rotation_quaternion())) / delta

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
	velocity = Vector2.ZERO
	sync_pose(1.0)
