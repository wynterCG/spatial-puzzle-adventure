class_name SurfacePiece
extends Node3D
## A closed, fully traversable cuboid. Decorative meshes never enter the graph.

var half := Vector3.ONE
var title := ""
var movable := false
var state := 0
var mesh: MeshInstance3D
var trim: Array[MeshInstance3D] = []
var base_color := Color.WHITE

func setup(label_text: String, dimensions: Vector3, tint: Color, can_move := false) -> void:
	title = label_text
	half = dimensions * 0.5
	movable = can_move
	base_color = tint
	mesh = box(self, Vector3.ZERO, dimensions, material(tint))
	var body := StaticBody3D.new()
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
