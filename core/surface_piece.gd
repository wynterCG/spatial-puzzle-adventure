@tool
class_name SurfacePiece
extends Node3D
## Architecture and its explicitly authored local-UP walking regions.

var half := Vector3.ONE
var title := ""
var movable := false
var state := 0
var mesh: MeshInstance3D
var trim: Array[MeshInstance3D] = []
var base_color := Color.WHITE
var walk_regions: Array[Rect2] = []
var neighbours: Array[SurfacePiece] = []
var path_visuals: Array[MeshInstance3D] = []
var solid_boxes: Array[AABB] = []
var solid_meshes: Array[MeshInstance3D] = []
var pick_body: StaticBody3D
var strict_connections := false
var connection_apertures: Array[Dictionary] = []

func allows_connection(other: SurfacePiece, world_point: Vector3) -> bool:
	if not strict_connections: return true
	for aperture in connection_apertures:
		if aperture.other != other: continue
		var delta: Vector3 = world_point - aperture.point
		var across: Vector3 = aperture.direction.cross(aperture.normal).normalized()
		if absf(delta.dot(across)) <= aperture.width / 2 + .001 and absf(delta.dot(aperture.normal)) < .04 and absf(delta.dot(aperture.direction)) < .13: return true
	return false

func surface_frame(_point: Vector3) -> Basis:
	return Basis.IDENTITY

func transports_controls() -> bool:
	return false

func step_contact(point: Vector3, direction: Vector3, distance: float) -> Vector3:
	return constrain_to_path(point + direction * distance)

func contains_solid(point: Vector3, padding := 0.0) -> bool:
	for bounds in solid_boxes:
		if bounds.grow(padding).has_point(point):
			return true
	return false

func set_solid_boxes(boxes: Array[AABB]) -> void:
	# Visible mass, selection collision and analytic body/camera queries agree.
	for visual in solid_meshes:
		visual.hide()
		visual.queue_free()
	solid_meshes.clear()
	for edge in trim:
		edge.hide()
	for shape in pick_body.get_children():
		shape.queue_free()
	solid_boxes = boxes
	for bounds in solid_boxes:
		solid_meshes.append(box(self, bounds.get_center(), bounds.size, material(base_color)))
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = bounds.size
		collision.shape = shape
		pick_body.add_child(collision)
		collision.position = bounds.get_center()
	mesh = solid_meshes[0]

func allows_point(point: Vector3, up: Vector3) -> bool:
	if not up.is_equal_approx(Vector3.UP) or absf(point.y - half.y) > 0.025:
		return false
	for region in walk_regions:
		if region.grow(0.001).has_point(Vector2(point.x, point.z)):
			return true
	return false

func constrain_to_path(point: Vector3) -> Vector3:
	var nearest := point
	var nearest_distance := INF
	for region in walk_regions:
		var candidate := Vector3(clampf(point.x, region.position.x, region.end.x), half.y, clampf(point.z, region.position.y, region.end.y))
		if candidate.distance_squared_to(point) < nearest_distance:
			nearest = candidate
			nearest_distance = candidate.distance_squared_to(point)
	return nearest

func draw_paths() -> void:
	for visual in path_visuals:
		visual.queue_free()
	path_visuals.clear()
	for region in walk_regions:
		path_visuals.append(box(self, Vector3(region.get_center().x, half.y + 0.018, region.get_center().y), Vector3(region.size.x, 0.025, region.size.y), material(Color("d8c8ac"))))

func setup(label_text: String, dimensions: Vector3, tint: Color, can_move := false) -> void:
	title = label_text
	half = dimensions * 0.5
	movable = can_move
	base_color = tint
	mesh = box(self, Vector3.ZERO, dimensions, material(tint))
	solid_boxes = [AABB(-half, dimensions)]
	solid_meshes = [mesh]
	var body := StaticBody3D.new()
	pick_body = body
	add_child(body)
	body.set_meta("piece", self)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	# Fine corner seams make all six faces readable without axis colours.
	for axis in range(3):
		var a := (axis + 1) % 3
		var b := (axis + 2) % 3
		for sa in [-1.0, 1.0]:
			for sb in [-1.0, 1.0]:
				var p := Vector3.ZERO
				p[a] = half[a] * sa
				p[b] = half[b] * sb
				var size := Vector3.ONE * 0.035
				size[axis] = dimensions[axis]
				trim.append(box(self, p, size, material(Color("858cac"), 0.15)))

func highlight(active: bool) -> void:
	for edge in trim:
		edge.material_override = material(Color("f3cc8c") if active else Color("858cac"), 0.8 if active else 0.15)

static func material(color: Color, glow := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.78
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat

static func box(parent: Node3D, at: Vector3, dimensions: Vector3, mat: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = dimensions
	instance.mesh = shape
	instance.material_override = mat
	parent.add_child(instance)
	instance.position = at
	return instance
