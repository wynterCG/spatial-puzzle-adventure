@tool
class_name ElsewhereLevel
extends Node3D
@export var level_id := "new_monument"
@export var revision := 1
@export var title := "New monument"
@export_multiline var question := "Where do you need to stand?"
@export_multiline var explanation := ""
@export var hints := PackedStringArray()
@export var overview_focus := Vector3.ZERO
@export var overview_size := 30.0

func components() -> Array:
	var result: Array = []
	for node in find_children("*", "Node3D", true, false):
		if node is ElsewhereComponent: result.append(node)
	return result
