extends RefCounted
## One continuous puzzle: path choice and receiver preparation share a dock.
## All dependencies come from physical reach, normals and swept geometry.
static func build(g: Node3D) -> void:
	g.focus = Vector3(0, -1, 2)
	g.overview_size = 41
	g.message = "Reach the far lantern. Two machines, one continuous route."
	g.start = g.slab("Arrival", g.world, Vector3(-9, .8, -2), Vector3(6, .4, 6), Color("647790"))
	g.start.walk_regions.assign([Rect2(-3, -.8, 6, 1.6), Rect2(-.8, -3, 1.6, 3)])
	g.start.draw_paths()
	g.x_ports(g.start)
	g.port(g.start, Vector3(0, .2, -3))
	var lower: SurfacePiece = g.slab("Underside_landing", g.world, Vector3(-9, -4.8, -2), Vector3(6, .4, 1.6), Color("647790"), Basis(Vector3.RIGHT, PI))
	g.x_ports(lower)
	g.port(lower, Vector3(0, .2, .8))
	var curve = g.CurvedPath.new()
	curve.name = "Arrival_curve"
	g.world.add_child(curve)
	curve.position = Vector3(-9, 1, -5)
	curve.tail_length = 2.2
	curve.build()
	curve.deployed = true
	curve.set_deployment(1)
	g.pieces.append(curve)
	g.port(curve, curve.point_at(0), Vector3.UP)
	g.port(curve, curve.point_at(curve.length()), Vector3.DOWN)
	var turnover: Node3D = g.rig("Turnover", Vector3(0, -2, 0), Vector3.RIGHT, 0)
	var short_path: SurfacePiece = g.slab("Upper_path", turnover, Vector3(-2, 2.8, -2), Vector3(8, .4, 1.6), Color("b98270"))
	var long_path: SurfacePiece = g.slab("Long_path", turnover, Vector3(0, -2.8, -2), Vector3(12, .4, 1.6), Color("9d899f"), Basis(Vector3.RIGHT, PI))
	g.x_ports(short_path)
	g.x_ports(long_path)
	for x in [-5.5, 1.5]:
		var strut := SurfacePiece.box(turnover, Vector3(x, 0, -2), Vector3(.18, 5.4, .24), SurfacePiece.material(Color("605869")))
		g.obstacles.append(strut)
		g.rigs[0].solids.append(strut)
	# The same arms that frame the long path's dock physically prevent turning
	# the receiver after arrival. No separate progress flag locks the receiver.
	for side in [-1.0, 1.0]:
		var finger := SurfacePiece.box(turnover, Vector3(6.65, -2.8, -2 + side * 1.5), Vector3(3.7, .16, .2), SurfacePiece.material(Color("ba9767")))
		g.obstacles.append(finger)
		g.rigs[0].solids.append(finger)
	var crossbar := SurfacePiece.box(turnover, Vector3(4.95, -2.65, -2), Vector3(.25, .25, 3.2), SurfacePiece.material(Color("ba9767")))
	g.obstacles.append(crossbar)
	g.rigs[0].solids.append(crossbar)
	var receiver: Node3D = g.rig("Receiver", Vector3(9, .8, 5.2), Vector3.UP, 1)
	var path: SurfacePiece = g.slab("Receiver_path", receiver, Vector3.ZERO, Vector3(1, .4, 1), Color("9d899f"))
	path.walk_regions = [Rect2(-3, -4, 3.4, 1.6), Rect2(-.4, -3.2, .8, 7.2)]
	var boxes: Array[AABB] = []
	for region in path.walk_regions:
		boxes.append(AABB(Vector3(region.position.x, -.2, region.position.y), Vector3(region.size.x, .4, region.size.y)))
	path.set_solid_boxes(boxes)
	path.draw_paths()
	# Custom L-shaped solids also need visible selection edges.
	for region in path.walk_regions:
		for side in [-1.0, 1.0]:
			var centre: Vector2 = region.get_center()
			path.trim.append(SurfacePiece.box(path, Vector3(centre.x, .235, centre.y + side * region.size.y * .5), Vector3(region.size.x, .025, .025), SurfacePiece.material(Color("858cac"))))
			path.trim.append(SurfacePiece.box(path, Vector3(centre.x + side * region.size.x * .5, .235, centre.y), Vector3(.025, .025, region.size.y), SurfacePiece.material(Color("858cac"))))
	SurfacePiece.box(path, Vector3(0, .24, 0), Vector3(.28, .025, .28), SurfacePiece.material(Color("ba9767"), .2))
	g.port(path, Vector3(-3, .2, -3.2))
	g.port(path, Vector3(0, .2, 4))
	g.goal = g.slab("Lantern_terrace", g.world, Vector3(9, .8, 11.2), Vector3(1.6, .4, 4), Color("719899"))
	g.z_ports(g.goal)
	var bearing := SurfacePiece.box(receiver, Vector3(0, -.4, 0), Vector3(.6, .45, .6), SurfacePiece.material(Color("ba9767")))
	g.obstacles.append(bearing)
	g.rigs[1].solids.append(bearing)
	g.finish_layout()
	# Small inlaid bars mark the beginning and the destination without arrows
	# spelling out the intermediate solution.
	for x in [-.55, 0.0, .55]:
		SurfacePiece.box(g.start, Vector3(x, .24, 1.7), Vector3(.12, .025, .65), SurfacePiece.material(Color("ba9767"), .15))
		SurfacePiece.box(g.goal, Vector3(x, .24, 1.3), Vector3(.12, .025, .45), SurfacePiece.material(Color("ba9767"), .15))
