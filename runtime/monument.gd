extends "res://runtime/architecture_runtime.gd"
## Runtime for every scene-authored monument (an ElsewhereLevel under a "Level" node).
## Monuments are scene data; there is no per-level gameplay script.
signal level_completed(level_id: String)
const C = preload("res://authoring/component.gd")
const Links = preload("res://authoring/connections.gd")
const Validate = preload("res://authoring/validation.gd")
const SpatialLinks = preload("res://core/spatial_links.gd")
## A doorway must stay in view this long to be noticed (a one-frame glimpse is not enough).
const DISCOVERY_SECONDS := .25
## Aiming is generous: a doorway within AIM_DEGREES of the centre of view is aimed at, and an
## aimed doorway stays aimed until the view drifts past AIM_KEEP_DEGREES (no flicker).
const AIM_DEGREES := 14.0
const AIM_KEEP_DEGREES := 22.0
## How long the tether flares after a link is made, seconds.
const TETHER_FLASH := .8
var data_source: ElsewhereLevel
var definition: ElsewhereLevel
var paths: Dictionary = {}
var interaction_values: Dictionary = {}
var checkpoint: Dictionary = {}
var checkpoint_id := ""
var debug_launch := false
var launch_data: Dictionary = {}
var authored_completed := false
var goal_marker: Node3D
var start_marker: Node3D
## Spatial Links (experimental): threshold id -> component; the one active pair; the doorway
## being aimed at; what the overview may show. Standing at a doorway makes it the source.
## Discovery is knowledge (never part of undo) and only decides what the overview shows.
var thresholds: Dictionary = {}
var link: Array = []
var aimed := ""
var discovered: Dictionary = {}
const SEAM_COLOURS := {"discovered": Color(.62, .68, .82), "candidate": Color(.45, .7, .9), "source": Color(1, .93, .78), "aimed": Color(.8, 1, 1), "linked": Color(.55, .9, 1)}
const VEIL_ALPHA := {"source": .1, "aimed": .18, "linked": .07}
var seam_materials: Dictionary = {}
var veil_materials: Dictionary = {}
## The preview connection while aiming; flares when the link is made.
var tether: MeshInstance3D
var tether_flash := 0.0
var discovery_time: Dictionary = {}

func _ready() -> void:
	data_source = get_node("Level")
	data_source.hide()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--authoring-launch="):
			var parsed = JSON.parse_string(Marshalls.base64_to_utf8(argument.trim_prefix("--authoring-launch=")))
			if parsed is Dictionary: launch_data = parsed; debug_launch = true
	super._ready()

func puzzle_title() -> String: return data_source.title
func puzzle_question() -> String: return data_source.question
func puzzle_reason() -> String: return data_source.explanation
func record_completion() -> void:
	authored_completed = true
	level_completed.emit(data_source.level_id)
func reached_goal() -> bool:
	return goal_marker.active and walker.support == goal and goal.to_global(walker.foot).distance_to(goal_marker.global_position) <= goal_marker.trigger_radius

func build_level() -> void:
	if tween and tween.is_valid(): tween.kill()
	if world:
		walker.support = null
		remove_child(world)
		world.queue_free()
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	definition = data_source.duplicate()
	definition.name = "Level"
	world.add_child(definition)
	if definition.backdrop:
		var backdrop: Node3D = definition.backdrop.instantiate()
		backdrop.name = "Backdrop"
		world.add_child(backdrop)
	definition.show()
	pieces.clear(); rigs.clear(); ports.clear(); obstacles.clear(); paths.clear()
	thresholds.clear(); discovered.clear(); link.clear(); aimed = ""; discovery_time.clear()
	tether = MeshInstance3D.new()
	tether.name = "Tether"
	tether.mesh = BoxMesh.new()
	tether.material_override = StandardMaterial3D.new()
	tether.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tether.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tether.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tether.visible = false
	tether_flash = 0.0
	world.add_child(tether)
	history.clear(); interaction_values.clear(); checkpoint.clear()
	checkpoint_id = ""
	selected = 0
	busy = false; paused = false; won = false; finish_open = true
	hint_level = 0
	var report := Validate.validate(definition)
	if not report.errors.is_empty():
		push_error("Invalid authored level: " + str(report.errors))
		set_process(false)
		var error := Label.new()
		error.text = "This level needs authoring fixes:\n" + "\n".join(report.errors)
		add_child(error)
		return
	for c in definition.components():
		if c.kind == C.Kind.ROTATOR:
			rigs.append({"node": c, "axis": c.axis.normalized(), "state": c.initial_state, "base_basis": c.basis, "angles": c.angles, "wrap_states": c.wrap_states, "duration": c.duration, "carries_player": c.carries_player, "locked": c.locked, "label": c.label if not c.label.is_empty() else str(c.name), "tint": c.tint, "solids": []})
		elif c.kind in [C.Kind.PATH, C.Kind.CURVE]:
			var part: SurfacePiece
			if c.kind == C.Kind.PATH:
				part = Piece.new()
				c.add_child(part)
				part.position.y = -c.dimensions.y / 2
				part.setup(str(c.name), c.dimensions, c.tint)
				part.walk_regions.assign(c.regions if not c.regions.is_empty() else [Rect2(-c.dimensions.x / 2, -c.dimensions.z / 2, c.dimensions.x, c.dimensions.z)])
				if not c.collision_boxes.is_empty(): part.set_solid_boxes(c.collision_boxes)
				elif not c.regions.is_empty():
					var boxes: Array[AABB] = []
					for region in c.regions: boxes.append(AABB(Vector3(region.position.x, -c.dimensions.y / 2, region.position.y), Vector3(region.size.x, c.dimensions.y, region.size.y)))
					part.set_solid_boxes(boxes)
				if not c.active: part.walk_regions.clear()
				if not c.blockout:
					for mesh in part.solid_meshes: mesh.hide()
					for edge in part.trim: edge.hide()
				part.draw_paths()
			else:
				part = preload("res://core/gravity_path.gd").new()
				part.radius = c.radius; part.arc = deg_to_rad(float(c.arc_degrees))
				part.path_width = c.dimensions.z; part.thickness = c.dimensions.y
				part.tail_length = c.tail; part.colour = c.tint; part.enabled = c.active
				c.add_child(part)
				part.build()
				if not c.blockout:
					for mesh in part.solid_meshes: mesh.hide()
			part.name = "Contact"
			part.title = c.label if not c.label.is_empty() else str(c.name).replace("_", " ")
			paths[c] = part
			pieces.append(part)
		elif c.kind == C.Kind.GEOMETRY:
			var mesh := Piece.box(c, Vector3.ZERO, c.dimensions, Piece.material(c.tint))
			obstacles.append(mesh)
		elif c.kind == C.Kind.START: start_marker = c
		elif c.kind == C.Kind.GOAL:
			goal_marker = c
			# A placeholder light, unless the monument authored its own landmark under the goal.
			if not c.get_children().any(func(child): return child is MeshInstance3D):
				Piece.box(c, Vector3(0, 1.8, 0), Vector3(.45, .8, .45), Piece.material(Color("ffdfa2"), 1))
		elif c.kind == C.Kind.THRESHOLD:
			var id := str(definition.get_path_to(c))
			thresholds[id] = c
			if c.initially_discovered: discovered[id] = true
			build_threshold_art(c)
		elif c.kind in [C.Kind.CHECKPOINT, C.Kind.INTERACTION]:
			Piece.box(c, Vector3(0, .45, 0), Vector3(.3, .9, .3), Piece.material(c.tint, .2))
			if c.kind == C.Kind.INTERACTION: interaction_values[str(definition.get_path_to(c))] = c.initial_value
	for entry in rigs:
		entry.node.basis = rotation_basis(entry, deg_to_rad(entry.angles[entry.state]))
		for mesh in obstacles:
			if entry.node.is_ancestor_of(mesh): entry.solids.append(mesh)
	start = paths[start_marker.get_node(start_marker.path)]
	goal = paths[goal_marker.get_node(goal_marker.path)]
	for socket in Links.descriptors(definition):
		var part: SurfacePiece = paths[socket.path]
		port(part, part.to_local(socket.position), part.global_basis.inverse() * socket.normal)
	finish_layout()
	walker.pieces = pieces; walker.camera_obstacles = obstacles
	place_at_marker(start_marker)
	focus = definition.overview_focus; overview_size = definition.overview_size
	camera_bias = Basis.IDENTITY
	camera_frame = walker.support.global_basis * walker.support.surface_frame(walker.foot)
	overview_local_offset = definition.overview_local_offset(); overview_zoom = 1
	sweep_tolerance = definition.sweep_tolerance
	overview.far = definition.overview_distance() + 3000
	overview.environment = Atmosphere.overview_environment(environment, definition.overview_distance())
	architectural = true
	update_links(); update_camera(); select_rig(0)
	toggle_view()
	message = "Reach the light. Tab: overview. Q / E: turn."
	if not interaction_values.is_empty(): message += " F: interact."
	if definition.components().any(func(c): return c.kind == C.Kind.CHECKPOINT): message += " Backspace: checkpoint."
	initial = snapshot()
	hud.refresh()

## A threshold's art in its own doorway frame (x across, y up the ground normal, z back): an
## optional blockout frame (prototype art; jambs and lintel are solid) and a seam that shows
## the link state. Both are children of the threshold, so they move with its structure.
func build_threshold_art(c: Node3D) -> void:
	var up: Vector3 = c.ground_normal.normalized()
	var out: Vector3 = c.travel_direction.normalized()
	var doorway := Node3D.new()
	doorway.basis = Basis(out.cross(up).normalized(), up, -out)
	var w: float = c.width
	var h: float = c.aperture_height
	if c.blockout_frame:
		var frame := doorway.duplicate()
		frame.name = "Frame"
		c.add_child(frame)
		var j := maxf(.12, w * .08)
		var stone := Piece.material(Color(.2, .2, .24))
		for side in [-1.0, 1.0]:
			obstacles.append(Piece.box(frame, Vector3(side * (w + j) / 2, h / 2, 0), Vector3(j, h, j), stone))
		obstacles.append(Piece.box(frame, Vector3(0, h + j / 2, 0), Vector3(w + 2 * j, j, j), stone))
	var seam := doorway
	seam.name = "Seam"
	c.add_child(seam)
	var s := maxf(.04, w * .015)
	for side in [-1.0, 1.0]:
		Piece.box(seam, Vector3(side * w / 2, h / 2, 0), Vector3(s, h, s), null)
	Piece.box(seam, Vector3(0, h, 0), Vector3(w, s, s), null)
	# A soft light filling the opening: the source, the aimed doorway and the linked pair.
	var veil := Piece.box(seam, Vector3(0, h / 2, 0), Vector3(w, h, .02), null)
	veil.name = "Veil"
	veil.reparent(c, false)
	veil.transform = seam.transform * veil.transform
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	refresh_threshold(c)

func seam_material(state: String) -> StandardMaterial3D:
	if not seam_materials.has(state):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = SEAM_COLOURS[state]
		seam_materials[state] = mat
	return seam_materials[state]

func veil_material(state: String) -> StandardMaterial3D:
	if not veil_materials.has(state):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(SEAM_COLOURS[state], VEIL_ALPHA[state])
		veil_materials[state] = mat
	return veil_materials[state]

## What a doorway shows right now: the linked pair, the source you stand at, the doorway you
## aim at, compatible doorways you could join (candidates), seen doorways, or nothing.
func doorway_state(id: String) -> String:
	if id in link: return "linked"
	var source := link_source()
	if id == source: return "source"
	if source != "" and id == aimed: return "aimed"
	if source != "" and compatible(source, id) and threshold_seen(id, false): return "candidate"
	return "discovered" if discovered.has(id) else "hidden"

func refresh_threshold(c: Node3D) -> void:
	var id := str(definition.get_path_to(c))
	var seam: Node3D = c.get_node_or_null("Seam")
	if seam == null: return
	var state := doorway_state(id)
	seam.visible = state != "hidden"
	for mesh in seam.get_children():
		mesh.material_override = seam_material(state if state != "hidden" else "discovered")
	var veil: MeshInstance3D = c.get_node_or_null("Veil")
	if veil:
		veil.visible = VEIL_ALPHA.has(state)
		if veil.visible: veil.material_override = veil_material(state)

func refresh_thresholds() -> void:
	for c in thresholds.values(): refresh_threshold(c)

func place_at_marker(marker: Node3D) -> void:
	var part: SurfacePiece = paths[marker.get_node(marker.path)]
	var normal: Vector3 = part.global_basis.inverse() * marker.global_basis * marker.ground_normal
	var heading: Vector3 = part.global_basis.inverse() * marker.global_basis * marker.forward
	walker.place(part, part.to_local(marker.global_position), normal.normalized(), heading.normalized())

func update_links() -> void:
	if definition == null: return
	for part in pieces:
		part.neighbours.clear()
		part.strict_connections = true
		part.connection_apertures.clear()
		part.remote_links.clear()
	# The one active Spatial Link pair (settled structures only, like sockets).
	if link.size() == 2 and not busy:
		var ends: Array = link.map(func(id): return thresholds.get(id))
		if not ends.has(null):
			for k in range(2):
				var here: Node3D = ends[k]
				var there: Node3D = ends[1 - k]
				paths[here.get_node(here.path)].remote_links.append({"node": here, "other": there, "other_piece": paths[there.get_node(there.path)]})
	for port_data in ports: port_data.joined = false
	var sockets := Links.descriptors(definition)
	if not busy:
		for i in range(sockets.size()):
			for j in range(i + 1, sockets.size()):
				if Links.compatible(sockets[i], sockets[j]):
					var a: SurfacePiece = paths[sockets[i].path]
					var b: SurfacePiece = paths[sockets[j].path]
					if not a.neighbours.has(b): a.neighbours.append(b)
					if not b.neighbours.has(a): b.neighbours.append(a)
					a.connection_apertures.append({"other": b, "point": sockets[i].position, "direction": sockets[i].direction, "normal": sockets[i].normal, "width": sockets[i].width})
					b.connection_apertures.append({"other": a, "point": sockets[j].position, "direction": sockets[j].direction, "normal": sockets[j].normal, "width": sockets[j].width})
					ports[i].joined = true; ports[j].joined = true
	for port_data in ports: port_data.mark.material_override = Piece.material(Color("8fc4b5") if port_data.joined else Color("c5ac83"), .25)

func _process(delta: float) -> void:
	if walker == null or walker.support == null: return
	super._process(delta)
	if busy or paused or architectural or blocks_play(): return
	update_discovery(delta)
	update_link_view()
	if tether_flash > 0:
		tether_flash = maxf(0, tether_flash - delta)
		tether.material_override.albedo_color.a = tether_flash / TETHER_FLASH
		if tether_flash == 0: tether.visible = false
	for c in definition.components():
		if c.kind == C.Kind.CHECKPOINT and c.active and paths.get(c.get_node(c.path)) == walker.support and walker.support.to_global(walker.foot).distance_to(c.global_position) < c.trigger_radius:
			var id := str(definition.get_path_to(c))
			if id != checkpoint_id:
				checkpoint = snapshot(); checkpoint_id = id
				message = "Checkpoint recorded. Backspace restores this arrangement and position."
				save_progress()
		if c.kind == C.Kind.INTERACTION and c.activation == 1 and c.active and not interaction_values.get(str(definition.get_path_to(c)), false):
			if walker.support.to_global(walker.foot).distance_to(c.global_position) < c.trigger_radius: activate(c)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not paused and not busy:
		if event.physical_keycode == KEY_BACKSPACE:
			if not checkpoint.is_empty(): history.append(snapshot()); restore(checkpoint); save_progress()
			return
		if event.physical_keycode == KEY_F and not architectural and not blocks_play():
			if use_threshold(): return
			var nearby := interaction_in_range()
			if nearby: activate(nearby); return
	super._unhandled_input(event)

## The F-activated interaction the player is standing within reach of, if any.
func interaction_in_range() -> Node3D:
	for c in definition.components():
		if c.kind == C.Kind.INTERACTION and c.activation == 0 and c.active and walker.support.to_global(walker.foot).distance_to(c.global_position) < c.trigger_radius:
			return c
	return null

func interaction_prompt() -> String:
	if architectural or paused or busy or blocks_play(): return ""
	var source := link_source()
	if source != "":
		if aimed == "": return "Look at another doorway"
		if not compatible(source, aimed): return "%s does not fit %s" % [threshold_label(aimed), threshold_label(source)]
		if linked_pair(source, aimed): return "%s ↔ %s" % [threshold_label(source), threshold_label(aimed)]
		return "F  Link %s ↔ %s" % [threshold_label(source), threshold_label(aimed)]
	var nearby := interaction_in_range()
	if nearby == null: return ""
	return "F  " + (nearby.label if not nearby.label.is_empty() else "Use")

# --- Spatial Links (experimental) -----------------------------------------------------------

func threshold_label(id: String) -> String:
	var c: Node3D = thresholds[id]
	return c.label if not c.label.is_empty() else str(c.name)

## The doorway on the player's ground within its reach, nearest first.
func threshold_in_reach() -> String:
	var feet := walker.support.to_global(walker.foot)
	var best := ""
	var best_distance := INF
	for id in thresholds:
		var c: Node3D = thresholds[id]
		if paths.get(c.get_node(c.path)) != walker.support: continue
		var distance := feet.distance_to(c.global_position)
		if distance <= c.trigger_radius and distance < best_distance:
			best = id
			best_distance = distance
	return best

## What never hides a doorway from line of sight: its own frame and seam, and its own deck.
func threshold_exclusions(id: String) -> Array:
	var c: Node3D = thresholds[id]
	var exclude: Array = []
	for art in ["Frame", "Seam"]:
		var holder: Node3D = c.get_node_or_null(art)
		if holder: exclude.append_array(holder.get_children())
	if c.get_node_or_null("Veil"): exclude.append(c.get_node("Veil"))
	exclude.append_array(paths[c.get_node(c.path)].solid_meshes)
	return exclude

## At least 2 of a doorway's 4 aperture points within range and in clear line of sight from the
## eye (and inside the view, unless only checking a target already aimed at).
func threshold_seen(id: String, require_view := true) -> bool:
	var eye := walker.camera.global_position
	var doorway := SpatialLinks.live(thresholds[id])
	if eye.distance_to(doorway.position) > definition.discovery_range: return false
	var exclude: Array = threshold_exclusions(id) + walker.support.solid_meshes
	var source := link_source()
	if source != "" and source != id: exclude += threshold_exclusions(source)
	var solids: Array = obstacles.duplicate()
	for part in pieces: solids.append_array(part.solid_meshes)
	var seen := 0
	for point in SpatialLinks.aperture_points(doorway):
		if require_view and not walker.camera.is_position_in_frustum(point): continue
		if SpatialLinks.visible(eye, point, solids, exclude): seen += 1
	return seen >= 2

## First person discovers: a doorway in clear view for DISCOVERY_SECONDS is known for good.
func update_discovery(delta: float) -> void:
	if architectural: return
	for id in thresholds:
		if discovered.has(id): continue
		if threshold_seen(id):
			discovery_time[id] = discovery_time.get(id, 0.0) + delta
			if discovery_time[id] >= DISCOVERY_SECONDS - .0001:
				discovered[id] = true
				refresh_threshold(thresholds[id])
		else:
			discovery_time.erase(id)

## The doorway the player stands at, in first person: the source of any link they make.
func link_source() -> String:
	if architectural or walker == null or walker.support == null: return ""
	return threshold_in_reach()

func compatible(a: String, b: String) -> bool:
	return thresholds[a].link_group == thresholds[b].link_group

func linked_pair(a: String, b: String) -> bool:
	return link.size() == 2 and a in link and b in link

func doorway_centre(id: String) -> Vector3:
	return SpatialLinks.aperture_points(SpatialLinks.live(thresholds[id]))[0]

## Recomputes the aim (generous, held against drift), what is seen, the doorway highlights and
## the preview tether. Visibility is the only rule for linking: no prior discovery is needed.
func update_link_view() -> void:
	var source := link_source()
	if source == "":
		aimed = ""
	else:
		var eye := walker.camera.global_position
		var look := -walker.camera.global_basis.z
		var precise := ray_target(source, eye, look)
		var held := aimed != "" and aimed != source and thresholds.has(aimed) and look.angle_to(doorway_centre(aimed) - eye) <= deg_to_rad(AIM_KEEP_DEGREES) and threshold_seen(aimed, false)
		if precise != "":
			aimed = precise
		elif not held:
			aimed = ""
			var best := deg_to_rad(AIM_DEGREES)
			for id in thresholds:
				if id == source: continue
				var angle := look.angle_to(doorway_centre(id) - eye)
				if angle <= best and threshold_seen(id, false):
					aimed = id
					best = angle
		discovered[source] = true
		if aimed != "": discovered[aimed] = true
	refresh_thresholds()
	if tether_flash > 0: return
	tether.visible = source != "" and aimed != "" and compatible(source, aimed) and not linked_pair(source, aimed)
	if tether.visible: place_tether(doorway_centre(source), doorway_centre(aimed), .35)

## The doorway the centre of view actually points at. Hits are taken nearest first along the
## view ray: a doorway's frame (a band around its opening) selects it; its opening is looked
## through, so a linkable doorway beyond it is meant instead (the one behind is not hidden by
## the one in front); with nothing beyond, the opening's own doorway. "" when the ray hits none.
func ray_target(source: String, eye: Vector3, look: Vector3) -> String:
	var hits: Array = []
	for id in thresholds:
		if id == source: continue
		var doorway := SpatialLinks.live(thresholds[id])
		var facing: float = look.dot(doorway.direction)
		if absf(facing) < .0001: continue
		var t: float = (doorway.position - eye).dot(doorway.direction) / facing
		if t <= 0: continue
		var local: Vector3 = SpatialLinks.frame(doorway).affine_inverse() * (eye + look * t)
		var w: float = doorway.width / 2
		var band: float = maxf(.25, doorway.width * .12)
		var opening: bool = absf(local.x) <= w and local.y >= 0 and local.y <= doorway.height
		var frame: bool = not opening and absf(local.x) <= w + band and local.y >= -band and local.y <= doorway.height + band
		if (opening or frame) and threshold_seen(id, false): hits.append([t, id, opening])
	hits.sort_custom(func(x, y): return x[0] < y[0])
	for k in range(hits.size()):
		var id: String = hits[k][1]
		if not hits[k][2]: return id
		var beyond := ""
		for later in hits.slice(k + 1):
			if compatible(source, later[1]):
				beyond = later[1]
				break
		return beyond if beyond != "" else id
	return ""

func place_tether(from: Vector3, to: Vector3, alpha: float) -> void:
	var span := to - from
	var side := Vector3.UP if absf(span.normalized().y) < .99 else Vector3.RIGHT
	var look := Basis.looking_at(span, side)
	var thick := .12
	tether.global_transform = Transform3D(Basis(look.x * thick, look.y * thick, look.z * span.length()), (from + to) / 2)
	tether.material_override.albedo_color = Color(SEAM_COLOURS.linked, alpha)

## Joins two doorways, replacing the one active pair. Returns why not, or "".
func link_doorways(source: String, target: String) -> String:
	if not thresholds.has(source) or not thresholds.has(target) or source == target: return "A doorway cannot lead to itself."
	if not compatible(source, target): return "%s does not fit %s" % [threshold_label(target), threshold_label(source)]
	if linked_pair(source, target): return "These doorways are already joined."
	history.append(snapshot())
	link = [source, target]
	aimed = ""
	discovered[source] = true
	discovered[target] = true
	update_links()
	refresh_thresholds()
	place_tether(doorway_centre(source), doorway_centre(target), 1.0)
	tether.visible = true
	tether_flash = TETHER_FLASH
	message = "%s and %s now open onto each other." % [threshold_label(source), threshold_label(target)]
	save_progress()
	return ""

## F in first person, standing at a doorway: join it to the doorway you are looking at.
func use_threshold() -> bool:
	var source := link_source()
	if source == "": return false
	update_link_view()
	if aimed == "":
		message = "Look at another doorway to join it to %s." % threshold_label(source)
		return true
	var reason := link_doorways(source, aimed)
	if reason != "": message = reason
	return true

func reticle_state() -> String:
	var source := link_source()
	if source == "": return ""
	return "aimed" if aimed != "" and compatible(source, aimed) else "idle"

func connection_text() -> String:
	var text := super.connection_text()
	if thresholds.is_empty(): return text
	text += "\nLink: " + (" <-> ".join(link.map(threshold_label)) if not link.is_empty() else "none")
	var source := link_source()
	if source != "": text += "  (source " + threshold_label(source) + (", aiming " + threshold_label(aimed) if aimed != "" else "") + ")"
	for id in link:
		var c: Node3D = thresholds[id]
		var doorway := SpatialLinks.live(c)
		var owner_name := "fixed"
		for entry in rigs:
			if entry.node.is_ancestor_of(c): owner_name = str(entry.node.name)
		text += "\n%s owner: %s  ground: %s" % [threshold_label(id), owner_name, doorway.normal.snapped(Vector3.ONE * .01)]
	text += "\nDiscovered: " + ", ".join(discovered.keys().map(threshold_label))
	return text

func activate(c: Node3D) -> bool:
	if busy or not c.active: return false
	if c.condition_state >= 0:
		var target_rig = c.get_node(c.condition_structure)
		for entry in rigs:
			if entry.node == target_rig and entry.state != c.condition_state:
				message = "The mechanism needs a different structure configuration."
				return false
	var target = c.get_node(c.target)
	if c.effect == 0 and target.active and paths[target] == walker.support:
		message = "Leave that passage before closing it."
		return false
	history.append(snapshot())
	if c.effect == 0: set_path_active(target, not target.active)
	else:
		for entry in rigs:
			if entry.node == target: entry.locked = not entry.locked
	var id := str(definition.get_path_to(c))
	interaction_values[id] = not interaction_values[id]
	message = c.feedback
	update_links(); save_progress()
	return true

func set_path_active(c: Node3D, enabled: bool) -> void:
	c.active = enabled
	var part: SurfacePiece = paths[c]
	if c.kind == C.Kind.CURVE: part.enabled = enabled
	else:
		part.walk_regions.assign(c.regions if not c.regions.is_empty() else [Rect2(-c.dimensions.x / 2, -c.dimensions.z / 2, c.dimensions.x, c.dimensions.z)])
		if not enabled: part.walk_regions.clear()
		part.draw_paths()

func snapshot() -> Dictionary:
	var data := super.snapshot()
	var active_paths := {}
	for c in paths: active_paths[str(definition.get_path_to(c))] = c.active
	var locks: Array = []
	for entry in rigs: locks.append(entry.locked)
	data.merge({"path_active": active_paths, "locks": locks, "interactions": interaction_values.duplicate(true), "link": link.duplicate()})
	return data

func restore(data: Dictionary) -> void:
	for c in paths: set_path_active(c, data.path_active[str(definition.get_path_to(c))])
	for i in range(rigs.size()): rigs[i].locked = data.locks[i]
	interaction_values = data.interactions.duplicate(true)
	# The link is puzzle configuration; what was discovered is knowledge and stays.
	link = data.get("link", []).duplicate()
	aimed = ""
	super.restore(data)
	refresh_thresholds()

func progress_path() -> String: return "user://authored-" + data_source.level_id + ".save"
func progress_data() -> Dictionary:
	return {"version": 1, "level": data_source.level_id, "revision": data_source.revision, "scene": snapshot(), "history": history, "checkpoint": checkpoint, "checkpoint_id": checkpoint_id, "won": won, "architectural": architectural, "finish_open": finish_open, "discovered": discovered.keys()}
func save_progress() -> void:
	if debug_launch or walker == null or walker.support == null: return
	super.save_progress()
func apply_progress(data: Dictionary) -> void:
	if data.get("version") != 1 or data.get("level") != data_source.level_id or data.get("revision") != data_source.revision: return
	if not valid_snapshot(data.get("scene", {})): return
	for state in data.get("history", []):
		if not valid_snapshot(state): return
	var saved_checkpoint: Dictionary = data.get("checkpoint", {})
	if not saved_checkpoint.is_empty() and not valid_snapshot(saved_checkpoint): return
	restore(data.scene)
	history.assign(data.get("history", []))
	checkpoint = saved_checkpoint; checkpoint_id = data.get("checkpoint_id", "")
	won = data.get("won", false); finish_open = data.get("finish_open", true)
	for id in data.get("discovered", []):
		if thresholds.has(id): discovered[id] = true
	refresh_thresholds()
	architectural = data.get("architectural", false)
	if architectural: overview.current = true
	else: walker.camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if architectural or blocks_play() else Input.MOUSE_MODE_CAPTURED
	hud.refresh()
func valid_snapshot(data: Dictionary) -> bool:
	if not data.has_all(["states", "player", "camera_bias", "path_active", "locks", "interactions", "selected"]): return false
	if data.states.size() != rigs.size() or data.locks.size() != rigs.size() or data.selected < 0 or (not rigs.is_empty() and data.selected >= rigs.size()): return false
	for i in range(rigs.size()):
		if data.states[i] < 0 or data.states[i] >= rigs[i].angles.size(): return false
	for c in paths:
		if not data.path_active.has(str(definition.get_path_to(c))): return false
	if not data.player.has_all(["piece", "foot", "normal", "forward", "pitch"]): return false
	var part = world.get_node_or_null(data.player.piece)
	if not part is SurfacePiece or not data.player.foot.is_finite() or not data.player.normal.is_finite() or not data.player.forward.is_finite(): return false
	if absf(data.player.normal.length() - 1) > .01 or absf(data.player.forward.length() - 1) > .01 or absf(data.player.forward.dot(data.player.normal)) > .01: return false
	var component: Node3D = part.get_parent()
	if not data.path_active.get(str(definition.get_path_to(component)), false): return false
	var point: Vector3 = part.transform * data.player.foot
	if not Validate.valid_contact(component, point, part.basis * data.player.normal): return false
	if not data.camera_bias.is_finite() or not data.get("camera_frame", Basis.IDENTITY).is_finite(): return false
	var pair: Array = data.get("link", [])
	if not pair.is_empty() and (pair.size() != 2 or not pair.all(func(id): return thresholds.has(id))): return false
	return true
func load_progress() -> void:
	if debug_launch:
		apply_launch(launch_data)
		return
	super.load_progress()
func apply_launch(data: Dictionary) -> bool:
	var before := snapshot()
	if _apply_launch(data): return true
	restore(before)
	message = "Play From Here was invalid; restored the authored starting position."
	return false

func _apply_launch(data: Dictionary) -> bool:
	if data.get("level") != data_source.level_id: return false
	for entry in rigs:
		var id := str(definition.get_path_to(entry.node))
		var state: int = data.get("states", {}).get(id, entry.state)
		if state < 0 or state >= entry.angles.size(): return false
		entry.state = state; entry.node.basis = rotation_basis(entry, deg_to_rad(entry.angles[state]))
	var marker = definition.get_node_or_null(data.get("marker", ""))
	if not marker is C or not marker.active: return false
	if marker.kind in [C.Kind.START, C.Kind.CHECKPOINT]: place_at_marker(marker)
	elif paths.has(marker): walker.place(paths[marker], Vector3(0, paths[marker].half.y, 0) if marker.kind == C.Kind.PATH else Vector3.ZERO, Vector3.UP, Vector3.RIGHT if marker.kind == C.Kind.PATH else Vector3.FORWARD)
	else: return false
	if not walker.support.allows_point(walker.foot, walker.normal) or not walker.pose_is_clear(walker.support, walker.foot, walker.normal): return false
	camera_frame = walker.support.global_basis * walker.support.surface_frame(walker.foot)
	update_links(); update_camera(); walker.sync_pose(1)
	initial = snapshot(); history.clear()
	message = "Authoring playtest — normal progress is not saved."
	return true
func show_hint() -> void:
	if data_source.hints.is_empty(): return
	message = data_source.hints[mini(hint_level, data_source.hints.size() - 1)]
	hint_level += 1
func restart() -> void:
	if busy: return
	super.restart()
	checkpoint.clear(); checkpoint_id = ""
	save_progress()
func run_tests() -> void:
	await get_tree().process_frame
	var failures: Array[String] = preload("res://tests/authoring_tests.gd").run(self)
	if not preload("res://tests/authoring_tests.gd").finished: failures.append("Authoring test suite did not reach its final assertion")
	for failure in failures: push_error("AUTHORING SELF TEST FAIL: " + failure)
	if failures.is_empty(): print("AUTHORING SELF TEST PASS")
	get_tree().quit(0 if failures.is_empty() else 1)
