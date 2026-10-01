extends RefCounted
## Spatial Links (experimental, docs/designs/2026-10-01-spatial-links.md): thresholds, crossing,
## linking, discovery and their state. Runs on small synthetic levels; The Fold has its own cases.
const C = preload("res://authoring/component.gd")
const Links = preload("res://authoring/connections.gd")
const Validate = preload("res://authoring/validation.gd")
const SpatialLinks = preload("res://core/spatial_links.gd")

static func run(g: Node3D, failures: Array[String]) -> void:
	validation_cases(g, failures)
	art_cases(g, failures)
	mapping_cases(failures)
	crossing_cases(g, failures)

## Two 8 x 4 m decks. A stands at Near's +x edge; B at Far's -x edge (out of Far, towards -x);
## C, in another link group, at Far's +x edge. Far's placement varies per test.
static func build(g: Node3D, far_origin := Vector3(14, 0, 0), far_basis := Basis.IDENTITY) -> void:
	var level := ElsewhereLevel.new()
	level.name = "Level"; level.level_id = "link_test"
	var near := deck("Near", Vector3.ZERO, Basis.IDENTITY)
	level.add_child(near)
	near.add_child(marker(C.Kind.START, "Start", Vector3(-3, 0, 0)))
	near.add_child(threshold("A", Vector3(4, 0, 0), Vector3.RIGHT, "g", true))
	var far := deck("Far", far_origin, far_basis)
	level.add_child(far)
	far.add_child(marker(C.Kind.GOAL, "Goal", Vector3(1, 0, 0)))
	far.add_child(threshold("B", Vector3(-4, 0, 0), Vector3.LEFT, "g", false))
	far.add_child(threshold("C", Vector3(4, 0, 0), Vector3.RIGHT, "other", false))
	g.remove_child(g.data_source); g.data_source.queue_free()
	g.add_child(level); g.data_source = level; level.hide(); g.build_level()

static func deck(name: String, origin: Vector3, basis: Basis) -> Node3D:
	var c = C.new()
	c.name = name; c.kind = C.Kind.PATH; c.dimensions = Vector3(8, .4, 4); c.end_sockets = false
	c.transform = Transform3D(basis, origin)
	return c

static func marker(kind: int, name: String, at: Vector3) -> Node3D:
	var c = C.new()
	c.kind = kind; c.name = name; c.path = NodePath(".."); c.position = at
	return c

static func threshold(name: String, at: Vector3, out: Vector3, group: String, known: bool) -> Node3D:
	var c = C.new()
	c.kind = C.Kind.THRESHOLD; c.name = name; c.path = NodePath(".."); c.position = at
	c.travel_direction = out; c.ground_normal = Vector3.UP; c.width = 2.0; c.aperture_height = 3.0
	c.trigger_radius = 2.0; c.link_group = group; c.initially_discovered = known
	return c

static func validation_cases(g: Node3D, failures: Array[String]) -> void:
	build(g)
	var report := Validate.validate(g.data_source)
	if not report.errors.is_empty(): failures.append("A valid link level must validate: " + str(report.errors))
	if Links.thresholds(g.data_source).size() != 3: failures.append("Every threshold must produce a descriptor")
	if Links.descriptors(g.data_source).any(func(d): return d.node.kind == C.Kind.THRESHOLD): failures.append("Thresholds must never form ordinary socket joins")
	var a: Node3D = g.data_source.get_node("Near/A")
	a.position.x = 2
	if not Validate.validate(g.data_source).errors.any(func(e: String): return "edge of its path" in e): failures.append("A threshold away from its path edge must be rejected")
	a.position.x = 4
	a.link_group = ""
	if not Validate.validate(g.data_source).errors.any(func(e: String): return "link group" in e): failures.append("A threshold without a link group must be rejected")
	a.link_group = "g"
	g.data_source.get_node("Near").end_sockets = true
	if not Validate.validate(g.data_source).errors.any(func(e: String): return "ordinary socket" in e): failures.append("A threshold on a socket edge must be rejected")

## Prototype art: an automatic frame and a seam whose visibility follows discovery.
static func art_cases(g: Node3D, failures: Array[String]) -> void:
	build(g)
	var a: Node3D = g.definition.get_node("Near/A")
	var b: Node3D = g.definition.get_node("Far/B")
	if a.get_node_or_null("Frame") == null: failures.append("A threshold must get a blockout frame by default")
	if a.get_node_or_null("Seam") == null or not a.get_node("Seam").visible: failures.append("A discovered threshold must show its seam")
	if b.get_node_or_null("Seam") == null or b.get_node("Seam").visible: failures.append("An undiscovered threshold must not show a seam")
	g.data_source.get_node("Far/C").blockout_frame = false
	g.build_level()
	if g.definition.get_node("Far/C").get_node_or_null("Frame") != null: failures.append("blockout_frame = false must leave the doorway to custom art")

static func doorway(at: Vector3, out: Vector3, up: Vector3) -> Dictionary:
	return {"position": at, "direction": out.normalized(), "normal": up.normalized(), "width": 2.0, "height": 3.0}

## The crossing mapping over a matrix of orientations: never a reflection, through A lands just
## inside B, heading becomes "into B's path", ground becomes B's normal, player-left stays left.
static func mapping_cases(failures: Array[String]) -> void:
	var a := doorway(Vector3.ZERO, Vector3.RIGHT, Vector3.UP)
	var cases := {
		"facing each other": doorway(Vector3(20, 0, 0), Vector3.LEFT, Vector3.UP),
		"same heading": doorway(Vector3(20, 0, 0), Vector3.RIGHT, Vector3.UP),
		"ground +90": doorway(Vector3(0, 10, 20), Vector3.BACK, Vector3.RIGHT),
		"ground -90": doorway(Vector3(5, 5, 5), Vector3.FORWARD, Vector3.LEFT),
		"ground 180": doorway(Vector3(-7, 30, 2), Vector3.LEFT, Vector3.DOWN),
		"opposite heading, sideways ground": doorway(Vector3(3, -4, 9), Vector3.UP, Vector3.BACK),
	}
	for name in cases:
		var b: Dictionary = cases[name]
		var m: Transform3D = SpatialLinks.mapping(a, b)
		var a_right: Vector3 = a.direction.cross(a.normal)
		var into_b: Vector3 = -b.direction
		var b_right: Vector3 = into_b.cross(b.normal)
		var problems: Array[String] = []
		if not is_equal_approx(m.basis.determinant(), 1.0): problems.append("reflection")
		if not (m * (a.position + a.direction * .05)).is_equal_approx(b.position + into_b * .05): problems.append("landing")
		if not (m.basis * a.direction).is_equal_approx(into_b): problems.append("heading")
		if not (m.basis * a.normal).is_equal_approx(b.normal): problems.append("ground")
		if not (m * (a.position + a_right * .7)).is_equal_approx(b.position + b_right * .7): problems.append("left/right")
		if not problems.is_empty(): failures.append("Link mapping (%s): %s" % [name, ", ".join(problems)])

static func id(g: Node3D, path: String) -> String:
	return str(g.definition.get_path_to(g.definition.get_node(path)))

static func piece(g: Node3D, path: String) -> SurfacePiece:
	return g.paths[g.definition.get_node(path)]

## Holds W from Near through linked A. Returns the number of link crossings.
static func hold_through(g: Node3D, local_heading: Vector3, metres: float, start_across := 0.0) -> int:
	var crossings := [0]
	var count := func(_rotation: Basis): crossings[0] += 1
	g.walker.linked_crossing.connect(count)
	var near := piece(g, "Near")
	g.architectural = false
	g.walker.place(near, Vector3(2, near.half.y, start_across), Vector3.UP, local_heading.normalized())
	var covered := 0.0
	for i in range(int(metres / 2.0 * 60) + 60):
		covered += g.walker.walk(Vector2(0, -1), 1.0 / 60)
		g.walker.sync_pose(1.0 / 60)
		g.update_camera(1.0 / 60)
		if covered >= metres: break
	g.walker.linked_crossing.disconnect(count)
	return crossings[0]

## Walking through a linked threshold: exactly one crossing while W is held, landing on B's
## path with B's ground, lateral offset kept, heading mapped, isometric frame carried.
static func crossing_cases(g: Node3D, failures: Array[String]) -> void:
	for placement in [["level", Vector3(14, 0, 0), Basis.IDENTITY], ["wall", Vector3(30, 10, -6), Basis(Vector3.BACK, PI / 2)], ["upside down", Vector3(-20, 15, 8), Basis(Vector3.RIGHT, PI)]]:
		build(g, placement[1], placement[2])
		g.link = [id(g, "Near/A"), id(g, "Far/B")]
		g.update_links()
		var far := piece(g, "Far")
		var crossings := hold_through(g, Vector3.RIGHT, 6.0, .6)
		var far_up: Vector3 = (far.global_basis * Vector3.UP).normalized()
		if crossings != 1: failures.append("Holding W through A must cross exactly once (%s): %d" % [placement[0], crossings])
		if g.walker.support != far: failures.append("Crossing A must land on B's path (%s)" % placement[0])
		elif not (g.walker.support.global_basis * g.walker.normal).normalized().is_equal_approx(far_up): failures.append("Crossing must adopt B's ground (%s)" % placement[0])
		elif absf(g.walker.foot.z - .6) > .05: failures.append("Crossing must keep the lateral offset (%s): %.3f" % [placement[0], g.walker.foot.z])
		elif not g.camera_frame.y.is_equal_approx(far_up): failures.append("The isometric frame must follow the link (%s)" % placement[0])
	# Diagonal, off-centre entry: lands on B's path, heading mapped through the same rotation.
	build(g)
	g.link = [id(g, "Near/A"), id(g, "Far/B")]
	g.update_links()
	if hold_through(g, Vector3(1, 0, .25), 4.0, -.4) != 1 or g.walker.support != piece(g, "Far"): failures.append("A diagonal off-centre entry must cross once onto B's path")
	elif g.walker.forward.dot(Vector3(1, 0, .25).normalized()) < .99: failures.append("A diagonal entry must keep its heading relative to the doorway")
	# Bidirectional: back through B returns through A.
	g.walker.forward = Vector3.LEFT
	g.architectural = false
	for i in range(240):
		g.walker.walk(Vector2(0, -1), 1.0 / 60)
		if g.walker.support == piece(g, "Near"): break
	if g.walker.support != piece(g, "Near"): failures.append("Links are bidirectional: walking back through B must return through A")
	# An unlinked threshold is an ordinary edge.
	build(g)
	if hold_through(g, Vector3.RIGHT, 6.0) != 0 or g.walker.support != piece(g, "Near"): failures.append("An unlinked threshold must be an ordinary path edge")
	# Moving threshold: the link reads current transforms.
	build(g)
	g.link = [id(g, "Near/A"), id(g, "Far/B")]
	g.update_links()
	g.definition.get_node("Far").position += Vector3(0, 0, 40)
	hold_through(g, Vector3.RIGHT, 6.0)
	if g.walker.support != piece(g, "Far") or g.walker.support.to_global(g.walker.foot).z < 38: failures.append("Crossing must use the threshold's current transform after its structure moved")
