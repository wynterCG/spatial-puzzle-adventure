@tool
class_name ElsewhereRing
extends Node3D
## Blockout ring (docs/designing-a-puzzle.md): a round wall of box segments around this node's
## origin, with openings. It rebuilds only its GeneratedGeometry child, made of GEOMETRY
## components (saved with the scene), so line of sight, the eye-clearance probe and turn sweeps
## see real boxes. Anything else you add under the ring is never touched. Metres, not x1 units.
const C = preload("res://authoring/component.gd")
const GENERATED := "GeneratedGeometry"

@export_range(.5, 200, .1, "or_greater") var radius := 6.0:
	set(value): radius = value; _changed()
@export_range(.1, 20, .05, "or_greater") var thickness := .6:
	set(value): thickness = value; _changed()
## The wall runs from y = 0 up to `height` in this node's frame.
@export_range(.1, 400, .1, "or_greater") var height := 8.0:
	set(value): height = value; _changed()
## Segment i is centred at angle i x 360 / segments, measured from +X towards +Z.
@export_range(3, 128) var segments := 16:
	set(value): segments = value; _changed()
@export var tint := Color(.17, .17, .2):
	set(value): tint = value; _changed()
## One opening per entry: x = segment index, y = gap width, z = gap bottom, w = gap top (metres).
## A gap from 0 is a doorway (no box below it).
@export var openings: Array[Vector4] = []:
	set(value): openings = value; _changed()

func _changed() -> void:
	# Only an edit in the editor rebuilds; loading a saved scene keeps its saved boxes.
	if Engine.is_editor_hint() and is_node_ready(): regenerate()

func regenerate() -> void:
	var old := get_node_or_null(GENERATED)
	if old:
		remove_child(old)
		old.free()
	var holder := Node3D.new()
	holder.name = GENERATED
	add_child(holder)
	var scene_owner: Node = owner if owner else self
	if Engine.is_editor_hint() and scene_owner != self: holder.owner = scene_owner
	var gaps := {}
	for opening in openings: gaps[int(opening.x)] = opening
	var middle := radius + thickness / 2
	# Segment length closes the outer face; the inner corners overlap.
	var length := 2 * (radius + thickness) * tan(PI / segments)
	for i in range(segments):
		var angle := i * TAU / segments
		var radial := Vector3(cos(angle), 0, sin(angle))
		var tangent := Vector3(-sin(angle), 0, cos(angle))
		if not gaps.has(i):
			_box(holder, "Segment%02d" % i, radial * middle, angle, 0, height, length)
			continue
		var gap: Vector4 = gaps[i]
		var side := (length - gap.y) / 2
		var centre := radial * middle
		_box(holder, "Segment%02dBelow" % i, centre, angle, 0, gap.z, length)
		_box(holder, "Segment%02dAbove" % i, centre, angle, gap.w, height, length)
		_box(holder, "Segment%02dLeft" % i, centre - tangent * (gap.y + side) / 2, angle, gap.z, gap.w, side)
		_box(holder, "Segment%02dRight" % i, centre + tangent * (gap.y + side) / 2, angle, gap.z, gap.w, side)

func _box(holder: Node3D, box_name: String, at: Vector3, angle: float, low: float, high: float, along: float) -> void:
	if high - low <= .001 or along <= .001: return
	var c = C.new()
	c.name = box_name
	c.kind = C.Kind.GEOMETRY
	c.tint = tint
	c.dimensions = Vector3(thickness, high - low, along)
	c.position = at + Vector3.UP * (low + high) / 2
	c.rotation = Vector3(0, -angle, 0)
	holder.add_child(c)
	if holder.owner: c.owner = holder.owner
