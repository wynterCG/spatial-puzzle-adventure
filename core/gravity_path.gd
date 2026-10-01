@tool
extends SurfacePiece
## Parameterized analytic arc, with a tangent tail. No arbitrary edge wrapping.
var radius := 3.0
var arc := PI
var path_width := 2.0
var thickness := .4
var tail_length := 0.0
var colour := Color("879bad")
var enabled := true
var sections: Array[Node3D] = []

func transports_controls() -> bool: return true
func curvature_radius(point: Vector3) -> float: return radius if distance_at(point) < arc * radius - .001 else INF
func length() -> float: return radius * arc + tail_length
func point_at(distance: float, across := 0.0) -> Vector3:
	var angle := clampf(distance / radius, 0, arc)
	var end := Vector3(across, radius * (cos(angle) - 1), -radius * sin(angle))
	return end + Basis(Vector3.RIGHT, -arc) * Vector3.FORWARD * maxf(0, distance - arc * radius)
func distance_at(point: Vector3) -> float:
	var end := point_at(arc * radius)
	var tangent := Basis(Vector3.RIGHT, -arc) * Vector3.FORWARD
	var along := (point - end).dot(tangent)
	if along >= 0 and point.distance_to(end + tangent * along + Vector3.RIGHT * point.x) < .1:
		return arc * radius + clampf(along, 0, tail_length)
	return clampf(atan2(-point.z, point.y + radius), 0, arc) * radius
func surface_frame(point: Vector3) -> Basis:
	return Basis(Vector3.RIGHT, -minf(arc, distance_at(point) / radius))
func constrain_to_path(point: Vector3) -> Vector3:
	return point_at(distance_at(point), clampf(point.x, -path_width / 2, path_width / 2))
func allows_point(point: Vector3, up: Vector3) -> bool:
	return enabled and point.distance_to(constrain_to_path(point)) < .025 and up.dot(surface_frame(point).y) > .998
func step_contact(point: Vector3, direction: Vector3, distance: float) -> Vector3:
	return point_at(clampf(distance_at(point) + direction.dot(-surface_frame(point).z) * distance, 0, length()), clampf(point.x + direction.x * distance, -path_width / 2, path_width / 2))
func contains_solid(point: Vector3, padding := 0.0) -> bool:
	for visual in solid_meshes:
		var local := visual.to_local(to_global(point))
		if visual.get_aabb().grow(padding).has_point(local): return true
	return false
func build() -> void:
	title = "Curved passage"
	half = Vector3(path_width / 2, radius * 2, radius + tail_length)
	var steps := maxi(24, int(length() * 7))
	for i in range(steps):
		var distance := (i + .5) * length() / steps
		var section := Node3D.new()
		add_child(section)
		sections.append(section)
		section.transform = Transform3D(surface_frame(point_at(distance)), point_at(distance))
		var span := length() / steps + .015
		solid_meshes.append(box(section, Vector3(0, -thickness / 2, 0), Vector3(path_width, thickness, span), material(colour)))
		box(section, Vector3(0, .014, 0), Vector3(maxf(path_width - 2 * SurfacePiece.PAVING_RIM, path_width * .5), .025, span), material(Color("dfceb0")))
