@tool
class_name ElsewhereStateArt
extends Node3D
## Presentation bound to a structure's state (docs/designs/2026-10-02-the-spillway.md): water that
## pours while a gate stands open, an overflow while a weir is aligned. Shown only while
## `structure` rests in one of `states`; hidden mid-turn. Particles under it stop emitting while
## hidden, so they thin out rather than vanish. No gameplay: it never changes what joins.
@export var structure: NodePath
@export var states := PackedInt32Array([0])
