extends "res://runtime/architecture_runtime.gd"
## Runtime for every scene-authored monument (an ElsewhereLevel under a "Level" node).
## Monuments are scene data; there is no per-level gameplay script.
signal level_completed(level_id: String)
const C = preload("res://authoring/component.gd")
const Links = preload("res://authoring/connections.gd")
const Validate = preload("res://authoring/validation.gd")
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
	definition.show()
	pieces.clear(); rigs.clear(); ports.clear(); obstacles.clear(); paths.clear()
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
	walker.camera_initialized = false; walker.world_orbit_initialized = false
	place_at_marker(start_marker)
	focus = definition.overview_focus; overview_size = definition.overview_size
	camera_bias = Basis.IDENTITY
	camera_frame = walker.support.global_basis * walker.support.surface_frame(walker.foot)
	overview_yaw = 0; overview_elevation = DEFAULT_ELEVATION; overview_zoom = 1
	architectural = true
	update_links(); update_camera(); select_rig(0)
	toggle_view()
	message = "Reach the light. Tab: overview. Q / E: turn."
	if not interaction_values.is_empty(): message += " F: interact."
	if definition.components().any(func(c): return c.kind == C.Kind.CHECKPOINT): message += " Backspace: checkpoint."
	initial = snapshot()
	hud.refresh()

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
			for c in definition.components():
				if c.kind == C.Kind.INTERACTION and c.activation == 0 and c.active and walker.support.to_global(walker.foot).distance_to(c.global_position) < c.trigger_radius:
					activate(c); return
	super._unhandled_input(event)

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
	data.merge({"path_active": active_paths, "locks": locks, "interactions": interaction_values.duplicate(true)})
	return data

func restore(data: Dictionary) -> void:
	for c in paths: set_path_active(c, data.path_active[str(definition.get_path_to(c))])
	for i in range(rigs.size()): rigs[i].locked = data.locks[i]
	interaction_values = data.interactions.duplicate(true)
	super.restore(data)

func progress_path() -> String: return "user://authored-" + data_source.level_id + ".save"
func progress_data() -> Dictionary:
	return {"version": 1, "level": data_source.level_id, "revision": data_source.revision, "scene": snapshot(), "history": history, "checkpoint": checkpoint, "checkpoint_id": checkpoint_id, "won": won, "architectural": architectural, "finish_open": finish_open}
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
