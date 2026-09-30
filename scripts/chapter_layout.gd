extends RefCounted
## Connected blockout. Zone metadata controls framing and hints, never links.
const HINTS := [
	["The marked curve is a path onto different ground.", "The small bridge carries its walking surface with you.", "Follow the curve, board the bridge underneath, then turn it twice. Cross the fixed bent passage."],
	["Compare the two paths with the next landing.", "The upper path ends early even when the carrier is aligned.", "Use the fixed curve to reach the long underside path. Ride it through two turns, then cross to the next carrier."],
	["Can the path you are riding reach the final passage?", "The fixed landing stays in place while the carrier changes.", "Ride the first path one turn. Step onto the fixed landing, turn the empty carrier once more, then follow the curve onto its other path. Walk inward and follow the quiet passage to the light."]
]

static func group(root: Node3D, label: String) -> Node3D:
	var node := Node3D.new()
	node.name = label
	root.add_child(node)
	return node

static func mark_zone(g: Node3D, first: int, zone: int) -> void:
	for i in range(first, g.pieces.size()): g.pieces[i].set_meta("chapter_zone", zone)

static func build(g: Node3D) -> void:
	var root: Node3D = g.world
	g.world = group(root, "Entrance")
	entrance(g)
	var arrival: SurfacePiece = g.start
	mark_zone(g, 0, 0)
	# A fixed walking connection, not a scene switch or teleport.
	var threshold: SurfacePiece = g.slab("Bent_passage", g.world, Vector3(-14, .8, 0), Vector3(4, .4, 5.6), Color("647790"))
	threshold.walk_regions = [Rect2(-2, 1.2, 2.8, 1.6), Rect2(-.8, -2.8, 1.6, 5.6), Rect2(-.8, -2.8, 2.8, 1.6)]
	var bounds: Array[AABB] = []
	for region in threshold.walk_regions:
		bounds.append(AABB(Vector3(region.position.x, -.2, region.position.y), Vector3(region.size.x, .4, region.size.y)))
	threshold.set_solid_boxes(bounds)
	threshold.draw_paths()
	g.port(threshold, Vector3(-2, .2, 2))
	g.port(threshold, Vector3(2, .2, -2))
	threshold.set_meta("chapter_zone", 1)
	var first: int = g.pieces.size()
	g.world = group(root, "Choice")
	g.build_decks(false)
	g.rigs[1].label = "Twin paths"
	g.goal.title = "Onward landing"
	mark_zone(g, first, 1)
	first = g.pieces.size()
	g.world = group(root, "Transfer")
	g.world.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(24, -2, 2))
	g.build_landing(false)
	g.rigs[2].label = "Relay"
	g.goal.title = "Quiet passage entrance"
	mark_zone(g, first, 2)
	# Exit through the side of the central landing onto a fixed underside path.
	g.world = root
	var passage: SurfacePiece = g.slab("Quiet_passage", root, Vector3(28.5, -4.8, 2), Vector3(7, .4, 1.6), Color("647790"), Basis(Vector3.RIGHT, PI))
	g.x_ports(passage)
	passage.set_meta("chapter_zone", 2)
	g.goal = g.slab("Far_light", root, Vector3(35, -4.8, 2), Vector3(6, .4, 3), Color("719899"), Basis(Vector3.RIGHT, PI))
	g.x_ports(g.goal)
	g.goal.set_meta("chapter_zone", 2)
	g.start = arrival
	g.finish_layout()
	# The same landmark can be seen above the route at arrival and from below
	# at the finish. Its mass stays outside all authored travel and turn sweeps.
	for z in [0.3, 3.7]:
		var column := SurfacePiece.box(root, Vector3(35, -2.5, z), Vector3(.7, 16.6, .5), SurfacePiece.material(Color("719899")))
		g.obstacles.append(column)
	var crown := SurfacePiece.box(root, Vector3(35, 6, 2), Vector3(1.2, .45, 4.4), SurfacePiece.material(Color("eac991"), .5))
	g.obstacles.append(crown)
	var lantern := SurfacePiece.box(root, Vector3(35, 5.1, 2), Vector3(.65, 1.2, .65), SurfacePiece.material(Color("ffdfa2"), 1.0))
	g.obstacles.append(lantern)
	var lower_crown := SurfacePiece.box(root, Vector3(35, -11, 2), Vector3(1.2, .45, 4.4), SurfacePiece.material(Color("eac991"), .5))
	g.obstacles.append(lower_crown)
	g.chapter_zones.assign([
		{"focus": Vector3(-20, -1, -1), "size": 28.0, "question": "Find the far light. Which ground leads onward?", "prompt": "WASD / Mouse: explore. Tab: observe and reshape the space. H: optional hint."},
		{"focus": Vector3(-2, -2, -1), "size": 35.0, "question": "Which path needs to carry you?", "prompt": "The next landing is visible. Compare the paths that can reach it."},
		{"focus": Vector3(26, -1, 5), "size": 38.0, "question": "Can the path you are riding reach the light?", "prompt": "The light is closer. Find your way across the last assembly."}
	])
	g.focus = g.chapter_zones[0].focus
	g.overview_size = g.chapter_zones[0].size
	g.message = g.chapter_zones[0].prompt

static func entrance(g: Node3D) -> void:
	g.start = g.slab("Overlook", g.world, Vector3(-25, .8, -2), Vector3(6, .4, 6), Color("647790"))
	g.start.walk_regions.assign([Rect2(-.8, -3, 1.6, 3.8)])
	g.start.draw_paths()
	g.port(g.start, Vector3(0, .2, -3))
	var lower: SurfacePiece = g.slab("Lower_approach", g.world, Vector3(-25, -4.8, -2), Vector3(6, .4, 1.6), Color("647790"), Basis(Vector3.RIGHT, PI))
	g.x_ports(lower)
	g.port(lower, Vector3(0, .2, .8))
	var curve = g.CurvedPath.new()
	curve.name = "First_curve"
	g.world.add_child(curve)
	curve.position = Vector3(-25, 1, -5)
	curve.tail_length = 2.2
	curve.build()
	curve.deployed = true
	curve.set_deployment(1)
	g.pieces.append(curve)
	g.port(curve, curve.point_at(0), Vector3.UP)
	g.port(curve, curve.point_at(curve.length()), Vector3.DOWN)
	var bridge: Node3D = g.rig("Bridge", Vector3(-19, -2, 0), Vector3.RIGHT, 0)
	var path: SurfacePiece = g.slab("Bridge_path", bridge, Vector3(0, -2.8, -2), Vector3(6, .4, 1.6), Color("b98270"), Basis(Vector3.RIGHT, PI))
	g.x_ports(path)
