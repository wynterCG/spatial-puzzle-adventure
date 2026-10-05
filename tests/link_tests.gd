extends RefCounted
## Spatial Links (experimental, docs/designs/2026-10-01-spatial-links.md): thresholds, crossing,
## linking, discovery and their state. Runs on small synthetic levels; The Fold has its own cases.
const C = preload("res://authoring/component.gd")
const Links = preload("res://authoring/connections.gd")
const Validate = preload("res://authoring/validation.gd")
const SpatialLinks = preload("res://core/spatial_links.gd")
const H = preload("res://tests/test_helpers.gd")
const LinkSolver = preload("res://tests/link_solver.gd")
const FOLD := "res://monuments/the_fold.tscn"
const STUDY := "res://monuments/link_study.tscn"

static func run(g: Node3D, failures: Array[String]) -> void:
	validation_cases(g, failures)
	art_cases(g, failures)
	mapping_cases(failures)
	crossing_cases(g, failures)
	discovery_cases(g, failures)
	linking_cases(g, failures)
	state_cases(g, failures)
	study_cases(g, failures)
	fold_cases(g, failures)

## Two 8 x 4 m decks. A stands at Near's +x edge; B at Far's -x edge (out of Far, towards -x);
## C, in another link group, at Far's +x edge. Far's placement varies per test.
static func build(g: Node3D, far_origin := Vector3(14, 0, 0), far_basis := Basis.IDENTITY, with_d := false, blocker := false) -> void:
	var level := ElsewhereLevel.new()
	level.name = "Level"; level.level_id = "link_test"
	var near := deck("Near", Vector3.ZERO, Basis.IDENTITY)
	level.add_child(near)
	near.add_child(marker(C.Kind.START, "Start", Vector3(-3, 0, 0)))
	near.add_child(threshold("A", Vector3(4, 0, 0), Vector3.RIGHT, "g", true))
	if with_d: near.add_child(threshold("D", Vector3(-4, 0, 0), Vector3.LEFT, "g", true))
	if blocker:
		var wall = C.new()
		wall.name = "Blocker"; wall.kind = C.Kind.GEOMETRY; wall.dimensions = Vector3(.5, 12, 12)
		wall.position = Vector3(9, 0, 0)
		level.add_child(wall)
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

## Stands at A on Near, looking at a point (pitch and heading set directly).
static func stand_at_a(g: Node3D, look_at: Vector3) -> void:
	var near := piece(g, "Near")
	g.architectural = false
	g.walker.place(near, Vector3(2.5, near.half.y, 0), Vector3.UP, Vector3.RIGHT)
	g.walker.sync_pose(1)
	var eye: Vector3 = g.walker.camera.global_position
	var flat := (look_at - eye).slide(Vector3.UP)
	g.walker.forward = near.global_basis.inverse() * flat.normalized()
	g.walker.pitch = atan2((look_at - eye).y, flat.length())
	g.walker.sync_pose(1)

static func b_centre(g: Node3D) -> Vector3:
	var b: Node3D = g.definition.get_node("Far/B")
	return b.global_position + Vector3.UP * b.aperture_height * .5

## Discovery by sight: 2 of 4 aperture points in view, in range and unobstructed for 0.25 s.
static func discovery_cases(g: Node3D, failures: Array[String]) -> void:
	build(g)
	var b := id(g, "Far/B")
	stand_at_a(g, b_centre(g))
	g.update_discovery(.1)
	if g.discovered.has(b): failures.append("A one-frame glimpse must not discover a doorway")
	g.update_discovery(.1); g.update_discovery(.1)
	if not g.discovered.has(b): failures.append("A doorway in clear view for 0.25 s must be discovered")
	elif not g.definition.get_node("Far/B/Seam").visible: failures.append("A discovered doorway must show its seam")
	build(g)
	stand_at_a(g, b_centre(g) + Vector3(0, 40, 0))
	for i in range(5): g.update_discovery(.1)
	if g.discovered.has(b): failures.append("A doorway outside the view must not be discovered")
	build(g, Vector3(14, 0, 0), Basis.IDENTITY, false, true)
	stand_at_a(g, b_centre(g))
	for i in range(5): g.update_discovery(.1)
	if g.discovered.has(b): failures.append("A doorway behind a wall must not be discovered")
	build(g)
	stand_at_a(g, b_centre(g))
	g.architectural = true
	for i in range(5): g.update_discovery(.1)
	if g.discovered.has(b): failures.append("The isometric view must never discover a doorway")
	# A doorway's own frame and deck never hide it.
	var far: Node3D = g.definition.get_node("Far/B")
	var exclude: Array = g.threshold_exclusions(b)
	if not far.get_node("Frame").get_children().all(func(mesh): return mesh in exclude): failures.append("Line of sight must ignore the doorway's own frame")
	if not piece(g, "Far").solid_meshes.all(func(mesh): return mesh in exclude): failures.append("Line of sight must ignore the doorway's own deck")

## Looks at a point turned `degrees` sideways (about the ground normal) from B's centre.
static func look_off_b(g: Node3D, degrees: float) -> void:
	var eye: Vector3 = g.walker.camera.global_position
	var to := b_centre(g) - eye
	stand_at_a(g, eye + to.rotated(Vector3.UP, deg_to_rad(degrees)))

## One step, nothing hidden: standing at a doorway makes it the source (visibly); looking at a
## visible compatible doorway previews the link; F joins them.
static func linking_cases(g: Node3D, failures: Array[String]) -> void:
	build(g, Vector3(14, 0, 0), Basis.IDENTITY, true)
	var a := id(g, "Near/A")
	var b := id(g, "Far/B")
	var c := id(g, "Far/C")
	var d := id(g, "Near/D")
	g.architectural = false
	g.walker.place(piece(g, "Near"), Vector3(0, piece(g, "Near").half.y, 0), Vector3.UP, Vector3.RIGHT)
	g.update_link_view()
	if g.link_source() != "" or g.use_threshold() or g.reticle_state() != "": failures.append("Away from doorways there is no source, no reticle and F does nothing")
	stand_at_a(g, b_centre(g) + Vector3(0, 30, 0))
	g.update_link_view()
	if g.link_source() != a or g.doorway_state(a) != "source" or not g.definition.get_node("Near/A/Veil").visible: failures.append("Standing at A must visibly make it the source")
	if g.reticle_state() != "idle": failures.append("At a source the reticle appears")
	if g.doorway_state(b) != "candidate": failures.append("A visible compatible doorway is highlighted as a candidate, even never seen before: " + g.doorway_state(b))
	if g.doorway_state(c) == "candidate": failures.append("An incompatible doorway is not a candidate")
	if g.tether.visible: failures.append("No preview until a doorway is aimed at")
	stand_at_a(g, b_centre(g))
	g.update_link_view()
	if g.aimed != b or g.doorway_state(b) != "aimed" or g.reticle_state() != "aimed": failures.append("Looking at B aims at it")
	if not g.tether.visible or g.tether.global_position.distance_to((g.thresholds[a].global_position + g.thresholds[b].global_position) / 2) > 3.0: failures.append("Aiming previews the link as a tether from A to B")
	if g.interaction_prompt() != "F  Link A ↔ B": failures.append("The prompt names both doorways: '%s'" % g.interaction_prompt())
	# Generous aim with hysteresis: 10 deg off still aims; a held target survives 18 deg; a fresh one does not.
	look_off_b(g, 10); g.update_link_view()
	if g.aimed != b: failures.append("Aiming is generous (10 deg off still aims)")
	look_off_b(g, 18); g.update_link_view()
	if g.aimed != b: failures.append("A held target survives small drift (18 deg)")
	g.aimed = ""
	g.update_link_view()
	if g.aimed != "": failures.append("A fresh target needs to be near the centre of view")
	# Incompatible: aiming says why, F changes nothing (C, behind B, never takes the aim from it).
	g.thresholds[b].link_group = "g2"
	stand_at_a(g, b_centre(g)); g.update_link_view()
	if g.aimed != b or g.interaction_prompt() != "B does not fit A" or g.tether.visible or g.reticle_state() != "idle": failures.append("Aiming at an incompatible doorway says so: '%s'" % g.interaction_prompt())
	g.use_threshold()
	if not g.link.is_empty(): failures.append("Incompatible doorways must not link")
	g.thresholds[b].link_group = "g"
	stand_at_a(g, b_centre(g)); g.update_link_view()
	var before: int = g.history.size()
	if not g.use_threshold() or g.link != [a, b] or g.history.size() != before + 1: failures.append("One F press links A and B (undoable)")
	if g.doorway_state(a) != "linked" or g.doorway_state(b) != "linked": failures.append("Both doorways show the link")
	if piece(g, "Near").remote_links.size() != 1 or piece(g, "Far").remote_links.size() != 1: failures.append("The active pair must be crossable both ways")
	# Stacked doorways: with a compatible C right behind B, looking through B's opening means C;
	# looking at B's frame means B.
	g.thresholds[c].link_group = "g"
	g.walker.place(piece(g, "Near"), Vector3(2.5, piece(g, "Near").half.y, 0), Vector3.UP, Vector3.RIGHT)
	stand_at_a(g, b_centre(g)); g.update_link_view()
	if g.aimed != c: failures.append("Looking through B's opening at C behind it must aim at C: " + g.aimed)
	var lintel: Vector3 = g.thresholds[b].global_position + Vector3.UP * (g.thresholds[b].aperture_height + .1)
	stand_at_a(g, lintel); g.update_link_view()
	if g.aimed != b: failures.append("Looking at B's frame must aim at B: " + g.aimed)
	stand_at_a(g, b_centre(g)); g.update_link_view()
	if g.aimed != c: failures.append("Looking back through B must aim at C again, not hold B")
	g.thresholds[c].link_group = "other"
	# Replacement: one pair only, from another source.
	var near := piece(g, "Near")
	g.walker.place(near, Vector3(-2.5, near.half.y, 0), Vector3.UP, Vector3.RIGHT)
	g.walker.sync_pose(1)
	look_at_point(g, b_centre(g))
	g.aimed = ""
	g.update_link_view()
	if g.link_source() != d or g.aimed != b: failures.append("From D, B can be aimed at")
	g.use_threshold()
	if g.link != [d, b] or not near.remote_links.all(func(r): return r.node == g.thresholds[d]): failures.append("A new pair must replace the old one")
	if g.doorway_state(a) == "linked": failures.append("The old pair goes dark")

## Undo rewinds the pair, never knowledge; saves keep both.
static func state_cases(g: Node3D, failures: Array[String]) -> void:
	build(g)
	var a := id(g, "Near/A")
	var b := id(g, "Far/B")
	stand_at_a(g, b_centre(g))
	g.update_link_view()
	g.use_threshold()
	if g.link != [a, b]: failures.append("State cases need a link")
	for i in range(3): g.update_discovery(.1)
	g.undo()
	if not g.link.is_empty() or not g.discovered.has(b): failures.append("Undo must rewind the link but keep what was discovered")
	g.link_doorways(a, b)
	g.restart()
	if not g.link.is_empty() or not g.discovered.has(b): failures.append("Restart must clear the link but keep what was discovered")
	g.link_doorways(a, b)
	var saved: Dictionary = bytes_to_var(var_to_bytes(g.progress_data()))
	g.build_level()
	if g.discovered.has(b): failures.append("A fresh level starts from authored knowledge")
	g.apply_progress(saved)
	if g.link != [a, b] or not g.discovered.has(b) or piece(g, "Near").remote_links.is_empty(): failures.append("Saves must restore the pair and what was discovered")

# --- The Fold (monuments/the_fold.tscn, tools/gen_fold.py) ---------------------------------

static func load_fold(g: Node3D, path := FOLD) -> void:
	var scene = load(path).instantiate()
	var source = scene.get_node("Level")
	scene.remove_child(source)
	source.owner = null
	for child in source.find_children("*", "", true, false): child.owner = null
	g.remove_child(g.data_source); g.data_source.queue_free()
	g.add_child(source); g.data_source = source; source.hide()
	scene.free()
	g.build_level()

static func door(g: Node3D, label: String) -> String:
	for key in g.thresholds:
		if g.threshold_label(key) == label: return key
	return ""

## Looks from the current pose straight at a world point, on any ground.
static func look_at_point(g: Node3D, point: Vector3) -> void:
	var w: SurfaceWalker = g.walker
	w.sync_pose(1)
	var up: Vector3 = (w.support.global_basis * w.normal).normalized()
	var to: Vector3 = point - w.camera.global_position
	var flat: Vector3 = to.slide(up)
	w.forward = (w.support.global_basis.inverse() * flat.normalized()).slide(w.normal).normalized()
	w.pitch = atan2(to.dot(up), flat.length())
	w.sync_pose(1)

static func door_centre(g: Node3D, label: String) -> Vector3:
	return SpatialLinks.aperture_points(SpatialLinks.live(g.thresholds[door(g, label)]))[0]

static func set_frame(g: Node3D, state: int) -> void:
	var frame: Dictionary = g.rigs[0]
	frame.state = state
	frame.node.transform = g.state_transform(frame, state)
	g.update_links()

## Which doorways each piece can see in each frame state: from any sampled walkable point
## ("piece") and from inside each doorway's reach ("at"). Looking anywhere (the player can turn).
static func sight_table(g: Node3D) -> Dictionary:
	var table := {}
	for state in range(g.state_count(g.rigs[0])):
		set_frame(g, state)
		for name in ["Entry", "Frame/FrameDeck", "GoalWall"]:
			var part: SurfacePiece = g.paths[g.definition.get_node(name)]
			for region in part.walk_regions:
				for ix in range(int(region.size.x / 2.0) + 1):
					for iz in range(int(region.size.y / 2.0) + 1):
						g.walker.place(part, Vector3(region.position.x + ix * 2.0, part.half.y, region.position.y + iz * 2.0), Vector3.UP, Vector3.RIGHT)
						g.walker.sync_pose(1)
						var reach: String = g.threshold_in_reach()
						for id in g.thresholds:
							if not g.threshold_seen(id, false): continue
							table["%d %s %s" % [state, name.get_file(), g.threshold_label(id)]] = true
							if reach != "": table["%d at %s %s" % [state, g.threshold_label(reach), g.threshold_label(id)]] = true
	set_frame(g, 0)
	return table

static func fold_cases(g: Node3D, failures: Array[String]) -> void:
	load_fold(g)
	if not Validate.validate(g.definition).errors.is_empty(): failures.append("The Fold must validate: " + str(Validate.validate(g.definition).errors))
	var seen := sight_table(g)
	for state in range(4):
		if seen.has("%d Entry B" % state) != (state == 0): failures.append("The Fold: B is seen from the entry only in frame state 0 (state %d)" % state)
		if seen.has("%d FrameDeck C" % state) != (state == 1): failures.append("The Fold: C is seen from the frame deck only in state 1 (state %d)" % state)
		if seen.has("%d Entry C" % state): failures.append("The Fold: C is never seen from the entry (state %d)" % state)
	if not seen.has("0 at A B") or not seen.has("1 at B C"): failures.append("The Fold: B must be aimable from A (state 0) and C from B (state 1)")
	for part in g.pieces:
		if not part.neighbours.is_empty(): failures.append("The Fold: no ordinary path joins its pieces")
	fold_solution(g, failures)
	fold_dead_end(g, failures)
	fold_solver(g, failures)

## The intended solution, played through the runtime.
static func fold_solution(g: Node3D, failures: Array[String]) -> void:
	load_fold(g)
	var a := door(g, "A"); var b := door(g, "B"); var c := door(g, "C")
	var entry: SurfacePiece = g.paths[g.definition.get_node("Entry")]
	g.architectural = false
	g.walker.place(entry, Vector3(H.m(1.5), entry.half.y, 0), Vector3.UP, Vector3.RIGHT)
	look_at_point(g, door_centre(g, "B"))
	g.update_link_view()
	g.use_threshold()
	if g.link != [a, b]: failures.append("The Fold: from A, aiming at B must link A<->B")
	H.turn(g, 0, 1, failures)
	g.architectural = false
	g.walker.place(entry, Vector3(H.m(1.5), entry.half.y, 0), Vector3.UP, Vector3.RIGHT)
	var deck: SurfacePiece = g.paths[g.definition.get_node("Frame/FrameDeck")]
	for i in range(240):
		g.walker.walk(Vector2(0, -1), 1.0 / 60)
		if g.walker.support == deck: break
	if g.walker.support != deck: failures.append("The Fold: after turning the frame, A must still lead to B")
	elif (deck.global_basis * g.walker.normal).normalized().dot(Vector3.BACK) < .99: failures.append("The Fold: arriving through B in state 1 the deck must be a wall (ground +z)")
	look_at_point(g, door_centre(g, "C"))
	g.update_link_view()
	if g.aimed != c: failures.append("The Fold: looking back out through B, C must be aimable")
	g.use_threshold()
	if g.link != [b, c]: failures.append("The Fold: from B, aiming at C must link B<->C, replacing A<->B")
	g.walker.forward = Vector3.RIGHT
	g.walker.pitch = 0
	var goal_wall: SurfacePiece = g.paths[g.definition.get_node("GoalWall")]
	for i in range(1200):
		g.walker.walk(Vector2(0, -1), 1.0 / 60)
		if not g.won and g.reached_goal(): g._process(0)
		if g.won: break
	if g.walker.support != goal_wall or not g.won: failures.append("The Fold: B<->C must lead onto the goal wall and to the goal")

## Turning the frame before linking hides B: a recoverable dead end.
static func fold_dead_end(g: Node3D, failures: Array[String]) -> void:
	load_fold(g)
	H.turn(g, 0, 1, failures)
	var entry: SurfacePiece = g.paths[g.definition.get_node("Entry")]
	g.architectural = false
	g.walker.place(entry, Vector3(H.m(1.5), entry.half.y, 0), Vector3.UP, Vector3.RIGHT)
	look_at_point(g, door_centre(g, "B"))
	g.update_link_view()
	g.use_threshold()
	if g.aimed != "" or not g.link.is_empty(): failures.append("The Fold: with the frame turned, B must be out of sight from A")
	H.turn(g, 0, -1, failures)
	g.architectural = false
	look_at_point(g, door_centre(g, "B"))
	g.update_link_view()
	if g.aimed != door(g, "B"): failures.append("The Fold: turning back must bring B into sight again")

## The minimum over the real runtime (tests/link_solver.gd): links only from real link poses.
static func fold_solver(g: Node3D, failures: Array[String]) -> void:
	load_fold(g)
	var sight := LinkSolver.survey(g, failures)
	var entry: SurfacePiece = g.paths[g.definition.get_node("Entry")]
	var goal: SurfacePiece = g.paths[g.definition.get_node("GoalWall")]
	var full := LinkSolver.minimum(g, sight, entry, goal)
	if full.cost != 5 or full.turns != 1 or full.links != 2 or full.crosses != 2: failures.append("The Fold minimum must be 2 links, 1 turn, 2 crossings: " + str(full))
	if LinkSolver.minimum(g, sight, entry, goal, false, true).cost != -1: failures.append("The Fold must be unsolvable without links")
	if LinkSolver.minimum(g, sight, entry, goal, true, false).cost != -1: failures.append("The Fold must be unsolvable without turning the frame")

# --- Link study (monuments/link_study.tscn, tools/gen_link_study.py) ----------------------
## The linking UX on its own: three doorways in one space, nothing to turn, no puzzle.
static func study_cases(g: Node3D, failures: Array[String]) -> void:
	load_fold(g, STUDY)
	if not Validate.validate(g.definition).errors.is_empty(): failures.append("The link study must validate: " + str(Validate.validate(g.definition).errors))
	if not g.rigs.is_empty(): failures.append("The link study has nothing to turn")
	var plaza: SurfacePiece = g.paths[g.definition.get_node("Plaza")]
	g.architectural = false
	g.walker.place(plaza, Vector3(0, plaza.half.y, -H.m(3.2)), Vector3.UP, Vector3.FORWARD)
	look_at_point(g, g.walker.camera.global_position + Vector3(0, 50, 8))
	g.update_link_view()
	if g.link_source() != door(g, "A"): failures.append("Link study: standing at A makes it the source")
	for label in ["B", "C"]:
		if g.doorway_state(door(g, label)) != "candidate": failures.append("Link study: from A, %s is visibly a candidate" % label)
	for label in ["B", "C"]:
		look_at_point(g, door_centre(g, label))
		g.update_link_view()
		if g.aimed != door(g, label) or not g.tether.visible: failures.append("Link study: looking at %s previews the link" % label)
	look_at_point(g, door_centre(g, "B"))
	g.update_link_view()
	g.use_threshold()
	if g.link != [door(g, "A"), door(g, "B")]: failures.append("Link study: one press links A and B")
	g.walker.forward = Vector3.FORWARD
	g.walker.pitch = 0
	for i in range(1200):
		g.walker.walk(Vector2(0, -1), 1.0 / 60)
		if not g.won and g.reached_goal(): g._process(0)
		if g.won: break
	if not g.won: failures.append("Link study: walking through A after linking reaches B's platform and its light")
