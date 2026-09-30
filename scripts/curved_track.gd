extends SurfacePiece
## An authored ribbon, not automatic wrapping around arbitrary architecture.
## Distance along the half-circle and its tail determines contact and gravity.

const RADIUS := 3.0
const TAIL := 3.0
const WIDTH := 0.8
const SEGMENTS := 64
var tail_length := TAIL
var deployed := false
var segments: Array[Node3D] = []
var deployment := 0.0
var stowed_roll: Node3D

func length() -> float:
	return PI * RADIUS + tail_length

func point_at(distance: float, across := 0.0) -> Vector3:
	var angle := clampf(distance / RADIUS, 0.0, PI)
	return Vector3(across, RADIUS * (cos(angle) - 1.0), -RADIUS * sin(angle) + maxf(0.0, distance - PI * RADIUS))

func distance_at(point: Vector3) -> float:
	if point.y < -RADIUS and point.z >= 0:
		return PI * RADIUS + clampf(point.z, 0.0, tail_length)
	return clampf(atan2(-point.z, point.y + RADIUS), 0.0, PI) * RADIUS

func surface_frame(point: Vector3) -> Basis:
	return Basis(Vector3.RIGHT, -minf(PI, distance_at(point) / RADIUS))

func allows_point(point: Vector3, up: Vector3) -> bool:
	var contact := constrain_to_path(point)
	return deployed and point.distance_to(contact) < 0.025 and up.dot(surface_frame(contact).y) > 0.998

func constrain_to_path(point: Vector3) -> Vector3:
	return point_at(distance_at(point), clampf(point.x, -WIDTH, WIDTH))

func step_contact(point: Vector3, direction: Vector3, distance: float) -> Vector3:
	var along := direction.dot(-surface_frame(point).z)
	return point_at(clampf(distance_at(point) + along * distance, 0.0, length()), clampf(point.x + direction.x * distance, -WIDTH, WIDTH))

func contains_solid(point: Vector3, padding := 0.0) -> bool:
	for visual in solid_meshes:
		if not visual.is_visible_in_tree():
			continue
		var size: Vector3 = (visual.mesh as BoxMesh).size
		if AABB(-size * 0.5, size).grow(padding).has_point(visual.to_local(to_global(point))):
			return true
	return false

func build() -> void:
	title = "Rounded walkway"
	# Conservative envelope for scenic-background culling; never a walkable box.
	half = Vector3(1.0, 6.2, 3.2)
	var stone := material(Color("ac806e"))
	var paving := material(Color("e4d4b7"))
	var trim_mat := material(Color("c6a77c"), 0.2)
	stowed_roll = Node3D.new()
	add_child(stowed_roll)
	stowed_roll.position = Vector3(0, -0.5, -0.35)
	for i in range(16):
		var angle := TAU * float(i) / 16.0
		var slat := box(stowed_roll, Vector3(0, cos(angle), sin(angle)) * 0.44, Vector3(1.98, 0.12, 0.2), stone)
		slat.rotation.x = angle
	for side in [-1.0, 1.0]:
		var end := MeshInstance3D.new()
		var wheel := CylinderMesh.new()
		wheel.top_radius = 0.46
		wheel.bottom_radius = 0.46
		wheel.height = 0.09
		end.mesh = wheel
		end.material_override = trim_mat
		stowed_roll.add_child(end)
		end.position.x = side * 1.02
		end.rotation.z = PI / 2
	for i in range(SEGMENTS):
		var s := (float(i) + 0.5) * length() / SEGMENTS
		var segment := Node3D.new()
		add_child(segment)
		segment.transform = Transform3D(surface_frame(point_at(s)), point_at(s))
		segments.append(segment)
		var size := length() / SEGMENTS + 0.012
		solid_meshes.append(box(segment, Vector3(0, -0.13, 0), Vector3(2.0, 0.26, size), stone))
		box(segment, Vector3(0, 0.013, 0), Vector3(1.6, 0.025, size), paving)
		for side in [-1.0, 1.0]:
			box(segment, Vector3(side * 0.96, 0.04, 0), Vector3(0.08, 0.12, size), trim_mat)
	set_deployment(0.0)

func set_deployment(amount: float) -> void:
	deployment = clampf(amount, 0.0, 1.0)
	stowed_roll.visible = deployment < 1.0
	stowed_roll.scale = Vector3(1.0, maxf(0.1, 1.0 - deployment), maxf(0.1, 1.0 - deployment))
	for i in range(segments.size()):
		var fraction := clampf(deployment * SEGMENTS - i, 0.0, 1.0)
		segments[i].visible = fraction > 0.0
		segments[i].scale.z = maxf(0.001, fraction)
