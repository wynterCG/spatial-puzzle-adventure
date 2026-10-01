extends RefCounted
## A turning cloister: access, clearance and departure share one courtyard.
const HINTS := [
	["The outer gallery continues beneath the arrival terrace.", "The folded access gallery can meet the underside landing.", "Follow the curve underneath. Lower the access gallery, then walk all the way onto the ring."],
	["What changed about the gallery after you crossed it?", "The brass cheeks at its end occupy the ring's turning space.", "Stand on the ring, fold the access gallery away, then turn the ring twice. The far gallery can then complete your departure."],
	["The far gallery has the same kind of joint as the first.", "An open connection also occupies the ring's turning clearance.", "Unfold the far gallery while standing on the ring, and cross to the light. To return, get back on the ring before withdrawing that gallery."]
]

static func solid(g: Node3D, parent: Node3D, at: Vector3, size: Vector3, tint: String, moving := -1) -> MeshInstance3D:
	var part := SurfacePiece.box(parent, at, size, SurfacePiece.material(Color(tint)))
	g.obstacles.append(part)
	if moving >= 0: g.rigs[moving].solids.append(part)
	return part

static func gallery(g: Node3D, label: String, x: float, y: float, upside: bool, state: int, tint: String) -> void:
	var index: int = g.rigs.size()
	var pivot: Node3D = g.rig(label, Vector3(x, y, 0), Vector3.BACK, state)
	g.rigs[index]["tint"] = Color(tint)
	var frame := Basis(Vector3.RIGHT, PI) if upside else Basis.IDENTITY
	var walkway: SurfacePiece = g.slab(label.replace(" ", "_") + "_path", pivot, Vector3.ZERO, Vector3(4, .4, 1.6), Color(tint), frame)
	g.x_ports(walkway)
	# Real sweep obstructions outside the walking channel. Folding about Z
	# clears the deck; rolling the ring about X meets the docking cheeks.
	var inward := 1.0 if x < 0 else -1.0
	for side in [-1.0, 1.0]:
		var cheek := solid(g, pivot, Vector3(inward * 1.95, 0, side * 1.35), Vector3(1.4, .3, .24), "ba9767", index)
		cheek.set_meta("clearance_label", label)
		var shoulder := solid(g, pivot, Vector3(inward * 1.3, 0, side * .97), Vector3(.2, .3, .65), "ba9767", index)
		shoulder.set_meta("clearance_label", label)
		solid(g, walkway, Vector3(0, .25, side * .76), Vector3(4, .08, .08), tint, index)
	solid(g, pivot, Vector3(0, 0, 0), Vector3(.45, .55, 2.3), "ba9767", index)

static func build(g: Node3D) -> void:
	var root: Node3D = g.world
	g.start = g.slab("Arrival_terrace", root, Vector3(-10, 2.8, 0), Vector3(4, .4, 4), Color("647790"))
	g.port(g.start, Vector3(0, .2, -2))
	g.start.set_meta("chapter_zone", 0)
	var lower: SurfacePiece = g.slab("Underside_gallery", root, Vector3(-10, -2.8, 0), Vector3(4, .4, 1.6), Color("647790"), Basis(Vector3.RIGHT, PI))
	g.x_ports(lower)
	g.port(lower, Vector3(0, .2, .8))
	lower.set_meta("chapter_zone", 1)
	var curve = g.CurvedPath.new()
	curve.name = "Outer_gallery"
	root.add_child(curve)
	curve.position = Vector3(-10, 3, -2)
	curve.tail_length = 1.2
	curve.build()
	var stone := SurfacePiece.material(Color("647790"))
	var faded: StandardMaterial3D = stone.duplicate()
	faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	faded.albedo_color.a = .12
	curve.cutaway_materials[stone] = faded
	for section in curve.solid_meshes:
		section.material_override = stone
		section.set_meta("opaque_material", stone)
	curve.deployed = true
	curve.set_deployment(1)
	g.pieces.append(curve)
	g.port(curve, curve.point_at(0), Vector3.UP)
	g.port(curve, curve.point_at(curve.length()), Vector3.DOWN)
	curve.set_meta("chapter_zone", 0)
	gallery(g, "Access gallery", -6, -2.8, true, 1, "bc755e")
	var ring: Node3D = g.rig("Courtyard ring", Vector3.ZERO, Vector3.RIGHT, 0)
	g.rigs[1]["tint"] = Color("9580b8")
	var path: SurfacePiece = g.slab("Inner_gallery", ring, Vector3(0, -2.8, 0), Vector3(8, .4, 1.6), Color("9580b8"), Basis(Vector3.RIGHT, PI))
	g.x_ports(path)
	for side in [-1.0, 1.0]:
		solid(g, path, Vector3(0, .25, side * .76), Vector3(8, .08, .08), "9580b8", 1)
	# Arch openings coincide with the passenger passage and head clearance.
	for x in [-2.8, 2.8]:
		for arc in [0, 1]:
			for segment in range(12):
				var angle := deg_to_rad(35.0 + (segment + .5) * 110.0 / 12.0 + arc * 180.0)
				var rib := solid(g, ring, Vector3(x, 3.6 * cos(angle), 3.6 * sin(angle)), Vector3(.3, .3, .61), "9580b8", 1)
				rib.rotation.x = angle
	for z in [-3.6, 3.6]:
		solid(g, ring, Vector3(0, 0, z), Vector3(5.9, .3, .3), "9580b8", 1)
	for x in [-2.8, 2.8]:
		for side in [-1.0, 1.0]:
			solid(g, ring, Vector3(x, -2.85, side * 1.5), Vector3(.3, .22, 1.5), "ba9767", 1)
	gallery(g, "Far gallery", 6, 2.8, false, 1, "4b9e9c")
	g.goal = g.slab("Light_terrace", root, Vector3(10, 2.8, 0), Vector3(4, .4, 3), Color("647790"))
	g.x_ports(g.goal)
	g.goal.set_meta("chapter_zone", 2)
	# One open foundation frames the void. Its piers sit outside the sweeps.
	var architecture := Node3D.new()
	architecture.name = "Courtyard_foundation"
	root.add_child(architecture)
	for x in [-12.6, 12.6]:
		# Deep end piers frame a window instead of hiding the terraces when
		# B transports the overview beneath the building.
		for z in [-4.9, 4.9]:
			solid(g, architecture, Vector3(x, -1, z), Vector3(.7, 9, 2.2), "414d64")
		for y in [-5.5, 3.5]:
			solid(g, architecture, Vector3(x, y, 0), Vector3(.7, .55, 12), "414d64")
	for z in [-6.2, 6.2]:
		solid(g, architecture, Vector3(0, -5.8, z), Vector3(25.9, .65, .7), "414d64")
		for x in [-10.5, 10.5]:
			solid(g, architecture, Vector3(x, -1, z), Vector3(.5, 9.5, .5), "647790")
		if z > 0:
			solid(g, architecture, Vector3(0, 4, z), Vector3(21.5, .45, .55), "647790")
			for x in [-4.8, 4.8]:
				solid(g, architecture, Vector3(x, -1, z), Vector3(.45, 9.5, .45), "647790")
	for z in [-1.9, 1.9]:
		solid(g, root, Vector3(10.8, 1, z), Vector3(.35, 10, .35), "647790")
	for y in [-4, 6]:
		solid(g, root, Vector3(10.8, y, 0), Vector3(.5, .35, 4.1), "ba9767")
	var light := SurfacePiece.box(root, Vector3(10.8, 5.45, 0), Vector3(.4, .65, .4), SurfacePiece.material(Color("ffdfa2"), 1.0))
	g.obstacles.append(light)
	g.finish_layout()
	g.chapter_zones.assign([
		{"focus": Vector3(0, -.5, 0), "size": 35.0, "rig": 0, "question": "The light is across the courtyard. How do you enter?", "prompt": "WASD / Mouse: explore. Tab: observe and reshape the space. H: optional hint."},
		{"focus": Vector3(0, -.5, 0), "size": 35.0, "rig": 0, "question": "When does a connection become an obstruction?", "prompt": "Explore the gallery beneath the terrace. The ring and both galleries can be moved from here."},
		{"focus": Vector3(0, -.5, 0), "size": 35.0, "rig": 2, "question": "What would you need to change to make the return journey?", "prompt": "The same light, across the same courtyard. Look back at the gallery you crossed."}
	])
	g.focus = g.chapter_zones[0].focus
	g.overview_size = g.chapter_zones[0].size
	g.message = g.chapter_zones[0].prompt
