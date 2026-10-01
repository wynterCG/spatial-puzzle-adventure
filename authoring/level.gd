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
## Authored isometric composition (spec §11). Azimuth and elevation are relative to the
## player's ground frame, not world space: the runtime applies them through camera_frame.
@export_range(-180, 180) var overview_azimuth_degrees := 135.0
@export_range(25, 70) var overview_elevation_degrees := 43.31

## Camera offset from overview_focus in the player's ground frame (upright ground = world).
func overview_local_offset() -> Vector3:
	var azimuth := deg_to_rad(overview_azimuth_degrees)
	var elevation := deg_to_rad(overview_elevation_degrees)
	return Vector3(sin(azimuth) * cos(elevation), sin(elevation), cos(azimuth) * cos(elevation)) * sqrt(3400.0)

func components() -> Array:
	var result: Array = []
	for node in find_children("*", "Node3D", true, false):
		if node is ElsewhereComponent: result.append(node)
	return result
