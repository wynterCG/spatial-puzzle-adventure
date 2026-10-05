@tool
class_name ElsewhereComponent
extends Node3D
## Authoring data. Geometry and gameplay remain independent children.
# ROTATOR is the legacy serialized ID; editor name: Transformable Structure (it rotates or slides).
enum Kind { PATH, CURVE, SOCKET, ROTATOR, START, GOAL, INTERACTION, CHECKPOINT, GEOMETRY, THRESHOLD }
enum Motion { ROTATE, SLIDE }
@export var kind: Kind = Kind.PATH:
	set(value): kind = value; notify_property_list_changed()
@export var label := ""
@export var active := true
@export_group("Path / blockout")
@export var dimensions := Vector3(4, .4, 2)
@export var blockout := true
@export var tint := Color("879bad")
@export var end_sockets := true
@export var regions: Array[Rect2] = []
@export var collision_boxes: Array[AABB] = []
@export_group("Authored curve")
@export_range(.5, 12) var radius := 3.0
@export_enum("90", "180") var arc_degrees := "180"
@export_range(0, 12) var tail := 0.0
@export_group("Socket")
@export var path: NodePath
@export var travel_direction := Vector3.RIGHT
@export var ground_normal := Vector3.UP
@export var width := 2.0
@export var socket_type := "walk"
@export_range(.001, .1) var position_tolerance := .03
@export_range(.1, 10) var angular_tolerance := 2.0
@export_group("Transformable structure")
## Rotate: each state is an angle about `axis`. Slide: each state is an offset from the base pose,
## in the structure's own frame (a lift, a sliding bridge).
@export var motion: Motion = Motion.ROTATE:
	set(value):
		# A fresh choice in the editor picks the usual cycling; loading a scene never does.
		if is_node_ready() and value != motion: wrap_states = value == Motion.ROTATE
		motion = value; notify_property_list_changed()
@export var axis := Vector3.RIGHT
@export var angles := PackedFloat32Array([0, 90, 180, 270])
@export var offsets := PackedVector3Array([Vector3.ZERO, Vector3(0, 4, 0)])
## Optional descriptive names, one per state ("Docked West", "Raised", "Goal Alignment").
@export var state_names := PackedStringArray()
@export var initial_state := 0
## Serialized as wrap_states; shown as "Cyclic states". Off: Q/E stop at the first and last state.
@export var wrap_states := true
@export var cyclic_states: bool:
	get: return wrap_states
	set(value): wrap_states = value
@export_range(.1, 5) var duration := .8
@export var carries_player := true
@export var locked := false
@export_group("Start / goal / checkpoint")
@export var forward := Vector3.RIGHT
@export_range(.1, 12) var trigger_radius := .8
@export_group("Interaction")
@export_enum("Toggle path", "Toggle rotation lock") var effect := 0
@export var target: NodePath
@export var condition_structure: NodePath
@export var condition_state := -1
@export var initial_value := false
@export var feedback := "The mechanism changes."
## Spatial Link threshold (experimental, docs/designs/2026-10-01-spatial-links.md): an authored
## doorway at a path edge. Uses path, travel_direction (out through the doorway), ground_normal,
## width, trigger_radius (reach to prime it) and tint.
@export_group("Threshold")
@export var aperture_height := 3.0
## Only thresholds in the same group can be linked.
@export var link_group := "link"
@export var initially_discovered := false
## Prototype art: an automatic frame (jambs and lintel). Custom architecture can replace it.
@export var blockout_frame := true
@export_enum("Press", "Enter") var activation := 0
var _signature := ""
var _clock := 0.0

func _validate_property(property: Dictionary) -> void:
	if property.name == "active" and kind in [Kind.ROTATOR, Kind.START, Kind.GEOMETRY]:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	var fields := {
		Kind.PATH: ["dimensions", "blockout", "tint", "end_sockets", "socket_type", "regions", "collision_boxes"],
		Kind.CURVE: ["dimensions", "blockout", "tint", "end_sockets", "radius", "arc_degrees", "tail", "socket_type"],
		Kind.SOCKET: ["path", "travel_direction", "ground_normal", "width", "socket_type", "position_tolerance", "angular_tolerance"],
		Kind.ROTATOR: ["motion", "axis", "angles", "offsets", "state_names", "initial_state", "cyclic_states", "duration", "carries_player", "locked", "tint"],
		Kind.START: ["path", "forward", "ground_normal"],
		Kind.GOAL: ["path", "trigger_radius", "tint"],
		Kind.CHECKPOINT: ["path", "trigger_radius", "tint"],
		Kind.INTERACTION: ["target", "effect", "condition_structure", "condition_state", "initial_value", "feedback", "activation", "trigger_radius", "tint"],
		Kind.GEOMETRY: ["dimensions", "tint"],
		Kind.THRESHOLD: ["path", "travel_direction", "ground_normal", "width", "aperture_height", "link_group", "initially_discovered", "blockout_frame", "trigger_radius", "tint"]
	}
	var all: Array = []
	for names in fields.values(): all.append_array(names)
	if property.name in all and not property.name in fields[kind]:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	if kind == Kind.ROTATOR and property.name == ("offsets" if motion == Motion.ROTATE else "angles"):
		property.usage &= ~PROPERTY_USAGE_EDITOR
	# wrap_states is stored; cyclic_states is its editor face and never stored.
	if property.name == "wrap_states": property.usage &= ~PROPERTY_USAGE_EDITOR
	if property.name == "cyclic_states": property.usage &= ~PROPERTY_USAGE_STORAGE

## Number of states of a Transformable Structure.
func state_count() -> int:
	return offsets.size() if motion == Motion.SLIDE else angles.size()

## Local transform of a Transformable Structure in `state`, from its base (authored) transform.
## The runtime and the editor preview both use it.
func state_local_transform(base: Transform3D, state: int) -> Transform3D:
	if motion == Motion.SLIDE: return Transform3D(base.basis, base.origin + base.basis * offsets[state])
	return Transform3D(base.basis * Basis(axis.normalized(), deg_to_rad(angles[state])), base.origin)

## The state's descriptive name, or its index.
func state_label(state: int) -> String:
	return state_names[state] if state < state_names.size() and not state_names[state].is_empty() else "State %d" % state

func _ready() -> void:
	if Engine.is_editor_hint(): rebuild_preview()

func _process(delta: float) -> void:
	if not Engine.is_editor_hint(): return
	_clock += delta
	if _clock < .25: return
	_clock = 0
	var signature := str([kind, dimensions, tint, blockout, radius, arc_degrees, tail, active, forward, ground_normal, travel_direction, width, regions, collision_boxes, aperture_height])
	if signature != _signature:
		_signature = signature
		rebuild_preview()

func rebuild_preview() -> void:
	var old := get_node_or_null("_AuthorPreview")
	if old:
		remove_child(old)
		old.queue_free()
	var holder := Node3D.new()
	holder.name = "_AuthorPreview"
	add_child(holder)
	var art = preload("res://core/surface_piece.gd")
	if kind in [Kind.PATH, Kind.GEOMETRY]:
		if kind == Kind.PATH and not regions.is_empty():
			for region in regions:
				var centre := Vector3(region.get_center().x, -.5 * dimensions.y, region.get_center().y)
				if blockout: art.box(holder, centre, Vector3(region.size.x, dimensions.y, region.size.y), art.material(tint))
				art.box(holder, centre + Vector3.UP * (dimensions.y / 2 + .014), Vector3(region.size.x, .025, region.size.y), art.material(Color("dfceb0")))
			line(holder, Vector3.ZERO, Vector3.UP * 1.1, Color("6dbbe8"))
			return
		if blockout or kind == Kind.GEOMETRY:
			art.box(holder, Vector3(0, -dimensions.y / 2, 0) if kind == Kind.PATH else Vector3.ZERO, dimensions, art.material(tint))
		if kind == Kind.PATH:
			art.box(holder, Vector3(0, .014, 0), Vector3(dimensions.x, .025, dimensions.z), art.material(Color("dfceb0")))
	elif kind == Kind.CURVE:
		var curve = preload("res://core/gravity_path.gd").new()
		curve.radius = radius
		curve.arc = deg_to_rad(float(arc_degrees))
		curve.path_width = dimensions.z
		curve.thickness = dimensions.y
		curve.tail_length = tail
		curve.colour = tint
		holder.add_child(curve)
		curve.build()
		if not blockout:
			for mesh in curve.solid_meshes: mesh.hide()
	elif kind in [Kind.START, Kind.GOAL, Kind.CHECKPOINT, Kind.INTERACTION, Kind.SOCKET]:
		var colour := Color("7fdcc6") if kind == Kind.START else Color("f4d69c")
		art.box(holder, Vector3(0, .15, 0), Vector3(.25, .3, .25), art.material(colour, .3))
	if kind == Kind.THRESHOLD:
		# Doorframe outline in the threshold's own frame (up = ground normal, across = width).
		var up := ground_normal.normalized()
		var across := travel_direction.cross(ground_normal).normalized() * width / 2
		var top := up * aperture_height
		var outline := Color("c9a0ff")
		line(holder, -across, -across + top, outline)
		line(holder, across, across + top, outline)
		line(holder, -across + top, across + top, outline)
		line(holder, -across, across, outline)
	if kind in [Kind.PATH, Kind.CURVE, Kind.START, Kind.SOCKET, Kind.THRESHOLD]:
		var normal := ground_normal.normalized() if kind in [Kind.START, Kind.SOCKET, Kind.THRESHOLD] else Vector3.UP
		line(holder, Vector3.ZERO, normal * 1.1, Color("6dbbe8"))
		var heading := travel_direction if kind in [Kind.SOCKET, Kind.THRESHOLD] else forward
		line(holder, Vector3.ZERO, heading.normalized(), Color("efbe6e"))

static func line(parent: Node3D, from: Vector3, to: Vector3, colour: Color) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = colour
	visual.material_override = mat
	parent.add_child(visual)
