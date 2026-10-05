@tool
class_name ElsewhereStateArt
extends Node3D
## Dressing bound to a structure's state (indicator lights, open or closed shells, rails, emissive
## strips, water). Presentation bound to a structure's state (docs/designs/2026-10-02-the-spillway.md): water that
## pours while a gate stands open, an overflow while a weir is aligned. Shown only while
## `structure` rests in one of `states`; hidden mid-turn. Particles under it stop emitting while
## hidden, so they thin out rather than vanish. No gameplay: it never changes what joins.
@export var structure: NodePath
## Stored as `states`; shown as "Visible states".
@export var states := PackedInt32Array([0])
@export var visible_states: PackedInt32Array:
	get: return states
	set(value): states = value

func _validate_property(property: Dictionary) -> void:
	if property.name == "states": property.usage &= ~PROPERTY_USAGE_EDITOR
	if property.name == "visible_states": property.usage &= ~PROPERTY_USAGE_STORAGE
