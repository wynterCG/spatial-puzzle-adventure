extends RefCounted
## One rounded frame: its lintel, inner ledge and jamb move as one assembly.
const HINTS := [
	"Compare the two ends of the moving frame with the lantern landing.",
	"The upper passage ends early. The rounded end leads underneath the same frame.",
	"Follow the rounded end onto the lower ledge before turning. Ride that longer ledge through two turns, then cross to the lantern."
]

static func solid(g: Node3D, parent: Node3D, at: Vector3, size: Vector3, tint: String, moving := false) -> MeshInstance3D:
	var part := SurfacePiece.box(parent, at, size, SurfacePiece.material(Color(tint)))
	g.obstacles.append(part)
	if moving: g.rigs[0].solids.append(part)
	return part

static func build(g: Node3D) -> void:
	g.focus = Vector3(-.5, 0, 0)
	g.overview_size = 25.0
	g.message = "Reach the lantern. Tab: inspect the frame. Q / E: turn it. H: optional hint."
	# The left end is a continuous architectural return, not an attached track.
	g.start = g.slab("Upper_threshold", g.world, Vector3(-5, 2.6, -2), Vector3(2, .8, 2), Color("687c91"))
	g.x_ports(g.start)
	var lower: SurfacePiece = g.slab("Lower_threshold", g.world, Vector3(-5, -2.6, -2), Vector3(2, .8, 2), Color("687c91"), Basis(Vector3.RIGHT, PI))
	g.x_ports(lower)
	var corner = g.CurvedPath.new()
	corner.name = "Rounded_end"
	g.world.add_child(corner)
	corner.transform = Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-6, 3, -2))
	corner.tail_length = 0.0
	corner.build()
	var stone := SurfacePiece.material(Color("687c91"))
	var faded: StandardMaterial3D = stone.duplicate()
	faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	faded.albedo_color.a = .12
	corner.cutaway_materials[stone] = faded
	for section in corner.solid_meshes:
		section.mesh.size.y = .8
		section.position.y = -.4
		section.material_override = stone
		section.set_meta("opaque_material", stone)
	corner.deployed = true
	corner.set_deployment(1)
	g.pieces.append(corner)
	g.port(corner, corner.point_at(0), Vector3.UP)
	g.port(corner, corner.point_at(corner.length()), Vector3.DOWN)
	var frame: Node3D = g.rig("Turning frame", Vector3.ZERO, Vector3.RIGHT, 0)
	g.rigs[0]["tint"] = Color("a787b1")
	var upper: SurfacePiece = g.slab("Outer_passage", frame, Vector3(0, 2.6, -2), Vector3(8, .8, 2), Color("a787b1"))
	var inner: SurfacePiece = g.slab("Inner_ledge", frame, Vector3(1, -2.6, -2), Vector3(10, .8, 2), Color("a787b1"), Basis(Vector3.RIGHT, PI))
	g.x_ports(upper)
	g.x_ports(inner)
	solid(g, frame, Vector3(3.6, 0, -2), Vector3(.8, 4.4, 2), "a787b1", true)
	# Sparse seams reinforce one substantial frame, including its fixed return.
	for part in [upper, inner]:
		for side in [-1.0, 1.0]:
			solid(g, part, Vector3(0, .43, side * .97), Vector3(part.half.x * 2, .06, .06), "a787b1", true)
	# The small lantern landing is offset in depth: turning the frame too soon
	# disconnects both thresholds instead of providing a remote shortcut.
	g.goal = g.slab("Lantern_landing", g.world, Vector3(8, 2.6, 2), Vector3(4, .8, 2.4), Color("687c91"))
	g.x_ports(g.goal)
	for z in [.5, 3.5]:
		solid(g, g.world, Vector3(9.25, 3.85, z), Vector3(.25, 3.3, .25), "687c91")
	solid(g, g.world, Vector3(9.25, 5.6, 2), Vector3(.6, .25, 3.5), "c6ac7e")
	g.finish_layout()
