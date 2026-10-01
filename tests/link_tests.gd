extends RefCounted
## Spatial Links (experimental, docs/designs/2026-10-01-spatial-links.md): thresholds, crossing,
## linking, discovery and their state. Runs on small synthetic levels; The Fold has its own cases.
const C = preload("res://authoring/component.gd")
const Links = preload("res://authoring/connections.gd")
const Validate = preload("res://authoring/validation.gd")
const SpatialLinks = preload("res://runtime/spatial_links.gd")

static func run(g: Node3D, failures: Array[String]) -> void:
	validation_cases(g, failures)
	art_cases(g, failures)

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
