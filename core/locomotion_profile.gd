class_name LocomotionProfile
extends Resource
## First-person movement feel, tuned on The Ring v3 (docs/designs/2026-10-01-locomotion-pass.md).
## Edit core/locomotion.tres in the inspector between runs; comfort settings override some fields.

## Walking speed on straight ground, metres per second.
@export_range(1.0, 6.0, .1) var walk_speed := 3.2
## Seconds from standing to full speed.
@export_range(0.0, .6, .01) var accel_time := .18
## Seconds from full speed to standing after release.
@export_range(0.0, .6, .01) var decel_time := .1
## Fastest the ground may turn the view on a gravity curve (Normal comfort setting), degrees
## per second. Walking speed on a curve is capped at this rate times the curve's radius.
@export_range(30.0, 360.0, 1.0) var max_gravity_turn_rate := 110.0
## How quickly the view settles onto a new ground orientation, per second. Mouse look is never eased.
@export_range(1.0, 60.0, .5) var view_ease_rate := 14.0
## Eye height above the walking surface, metres.
@export_range(1.0, 2.0, .01) var eye_height := 1.55
## Vertical field of view, degrees (the comfort setting overrides it).
@export_range(50.0, 100.0, 1.0) var fov := 72.0
## Vertical head bob amplitude at full speed, metres. Zero on curves and with reduced motion; never roll.
@export_range(0.0, .05, .001) var head_bob := .01
## Distance of one footstep, metres: one bob cycle.
@export_range(.3, 1.5, .01) var step_length := .75
