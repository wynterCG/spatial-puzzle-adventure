extends SceneTree
## First-person eye clearance (docs/designs/2026-10-01-locomotion-pass.md). Samples every
## reachable walking pose of a monument in every rotor configuration and reports eyes closer
## than CLEAR to solid art: CSG through physics (collision is switched on here only) and box
## meshes exactly. The camera's near plane (0.04) keeps its corners within CLEAR even at FOV 95.
##   "$G" --path . -s res://tests/eye_clearance_probe.gd -- res://monuments/the_ring.tscn
## Exits 1 when any pose clips. Not part of the self-test: it needs a physics world and takes
## a while. Any saved progress for the monument is set aside and restored.
const CLEAR := .1
const STEP := .1
var g

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0] if not args.is_empty() else "res://monuments/the_ring.tscn"
	g = load(scene_path).instantiate()
	var save := ProjectSettings.globalize_path("user://authored-%s.save" % g.get_node("Level").level_id)
	var backup := FileAccess.get_file_as_bytes(save)
	DirAccess.remove_absolute(save)
	root.add_child(g)
	await process_frame
	for csg in g.find_children("*", "CSGShape3D", true, false):
		if not csg.get_parent() is CSGShape3D: csg.use_collision = true
	for i in range(4): await physics_frame
	var boxes: Array = g.find_children("*", "MeshInstance3D", true, false).filter(func(mesh): return mesh.mesh is BoxMesh and mesh.is_visible_in_tree())
	var hits := {}
	# Every rotor configuration: the same arm docks against different walls.
	var configs: Array = [[]]
	for entry in g.rigs:
		var grown: Array = []
		for config in configs:
			for state in range(entry.angles.size()): grown.append(config + [state])
		configs = grown
	for config in configs:
		for i in range(g.rigs.size()):
			g.rigs[i].node.basis = g.rotation_basis(g.rigs[i], deg_to_rad(g.rigs[i].angles[config[i]]))
		probe(boxes, hits)
	print("EYE CLEARANCE: %s, %d configurations, %d clipping places" % [scene_path, configs.size(), hits.size()])
	for key in hits: print("  %s (%d poses)" % [key, hits[key]])
	DirAccess.remove_absolute(save)
	if not backup.is_empty():
		var file := FileAccess.open(save, FileAccess.WRITE)
		file.store_buffer(backup)
		file.close()
	quit(1 if not hits.is_empty() else 0)

func probe(boxes: Array, hits: Dictionary) -> void:
	var space: PhysicsDirectSpaceState3D = g.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = CLEAR
	query.shape = sphere
	var eye_height: float = g.walker.profile.eye_height
	for part in g.pieces:
		var points: Array = []
		if part.has_method("point_at"):
			for d in range(int(part.length() / STEP) + 1):
				for across in [-part.path_width / 2, 0.0, part.path_width / 2]:
					points.append(part.point_at(d * STEP, across))
		else:
			for region in part.walk_regions:
				for x in range(int(region.size.x / STEP) + 1):
					for z in range(int(region.size.y / STEP) + 1):
						points.append(Vector3(region.position.x + x * STEP, part.half.y, region.position.y + z * STEP))
		for point in points:
			var up: Vector3 = part.surface_frame(point).y
			# Only poses the walker can reach; its body test already keeps the head off other decks.
			if not part.allows_point(part.constrain_to_path(point), up) or not g.walker.pose_is_clear(part, point, up): continue
			var eye: Vector3 = part.to_global(point) + (part.global_basis * up).normalized() * eye_height
			var hit := ""
			query.transform = Transform3D(Basis.IDENTITY, eye)
			for found in space.intersect_shape(query, 4):
				if found.collider is CSGShape3D: hit = str(found.collider.name)
			for mesh in boxes:
				if part.is_ancestor_of(mesh): continue
				if AABB(-mesh.mesh.size * .5, mesh.mesh.size).grow(CLEAR).has_point(mesh.to_local(eye)):
					hit = "%s/%s" % [mesh.get_parent().name, mesh.name]
			if hit != "":
				var key := "%s near %s" % [part.get_parent().name, hit]
				hits[key] = hits.get(key, 0) + 1
