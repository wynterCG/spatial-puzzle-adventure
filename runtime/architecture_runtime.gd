extends Node3D
## Generic Elsewhere runtime: first-person traversal, the isometric architectural view (camera B),
## discrete structure turns with sweep clearance, snapshots, undo and progress hooks.
## Connectivity follows matching authored contacts; no progress flag or camera alignment enables a route.
## Subclasses build the world in build_level() and override the puzzle_*/progress hooks.
const Piece = preload("res://core/surface_piece.gd")
const Walker = preload("res://core/surface_walker.gd")
const HUD = preload("res://runtime/hud.gd")
const DEFAULT_ELEVATION := 0.7559694104 # atan2(40, sqrt(30*30 + 30*30))
var world: Node3D
var pieces: Array[SurfacePiece] = []
var rigs: Array[Dictionary] = []
var ports: Array[Dictionary] = []
var obstacles: Array[MeshInstance3D] = []
var walker: SurfaceWalker
var overview: Camera3D
var hud: CanvasLayer
var start: SurfacePiece
var goal: SurfacePiece
var selected := 0
var architectural := true
var busy := false
var paused := false
var won := false
var finish_open := true
var tween: Tween
var history: Array[Dictionary] = []
var initial: Dictionary
var camera_bias := Basis.IDENTITY
var camera_frame := Basis.IDENTITY
var overview_yaw := 0.0
var overview_elevation := DEFAULT_ELEVATION
var overview_zoom := 1.0
var overview_dragging := false
var focus := Vector3.ZERO
var overview_size := 32.0
var message := ""
var hint_level := 0
var input_bindings := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "view": KEY_TAB, "rotate_left": KEY_Q, "rotate_right": KEY_E, "undo": KEY_Z, "reset": KEY_R, "hint": KEY_H, "reset_view": KEY_HOME}

func _ready() -> void:
	configure_input()
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("10182f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a5b8ef")
	env.ambient_light_energy = 0.55
	environment.environment = env
	add_child(environment)
	for data in [[Vector3(-48, -32, 0), Color("ffe5bf"), 0.75], [Vector3(35, 125, 0), Color("899adb"), 0.25]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = data[0]
		light.light_color = data[1]
		light.light_energy = data[2]
		light.shadow_enabled = true
		add_child(light)
	walker = Walker.new()
	add_child(walker)
	walker.changed_surface.connect(crossed_seam)
	overview = Camera3D.new()
	add_child(overview)
	overview.projection = Camera3D.PROJECTION_ORTHOGONAL
	overview.cull_mask = 15
	hud = HUD.new()
	hud.game = self
	add_child(hud)
	build_level()
	load_preferences()
	if "--self-test" in OS.get_cmdline_user_args():
		call_deferred("run_tests")
	else:
		load_progress()

func configure_input() -> void:
	var settings := ConfigFile.new()
	settings.load("user://settings.cfg")
	for action in input_bindings:
		input_bindings[action] = settings.get_value("keys", action, input_bindings[action])
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.physical_keycode = input_bindings[action]
		InputMap.action_add_event(action, event)

func key_name(action: String) -> String:
	return OS.get_keycode_string(input_bindings[action])

# --- Hooks for subclasses -------------------------------------------------------------------

func build_level() -> void: pass
func puzzle_title() -> String: return ""
func puzzle_question() -> String: return ""
func puzzle_reason() -> String: return ""
func reached_goal() -> bool: return false
func record_completion() -> void: pass
func show_hint() -> void: pass
func progress_path() -> String: return ""
func progress_data() -> Dictionary: return {}
func apply_progress(_data: Dictionary) -> void: pass
func run_tests() -> void: get_tree().quit(0)

# --- Construction helpers -------------------------------------------------------------------

func port(part: SurfacePiece, point: Vector3, normal := Vector3.UP) -> void:
	var mark := Piece.box(part, point + normal * 0.035, Vector3(0.28, 0.03, 0.28), Piece.material(Color("c5ac83"), 0.15))
	mark.basis = part.surface_frame(point)
	ports.append({"piece": part, "point": point, "normal": normal, "mark": mark, "joined": false})

func finish_layout() -> void:
	for entry in rigs:
		for part in pieces:
			if entry.node.is_ancestor_of(part):
				entry.solids.append_array(part.solid_meshes)

func update_links() -> void: pass

# --- Camera B: ground-normal transport, independent manual orbit layer ----------------------

func crossed_seam() -> void:
	# Preserve world azimuth across a matching seam even if the two pieces use
	# different local axes. Walking direction never chooses a camera side.
	var ground := walker.support.global_basis * walker.support.surface_frame(walker.foot)
	camera_frame = transport_ground(camera_frame, ground.y)
	camera_bias = ground.inverse() * camera_frame

func transport_ground(frame: Basis, next_up: Vector3) -> Basis:
	var up := next_up.normalized()
	var old_up := frame.y.normalized()
	var axis := old_up.cross(up)
	var cosine := clampf(old_up.dot(up), -1.0, 1.0)
	if axis.length_squared() < 0.0000000001:
		# A stationary normal carries no heading rotation. An instantaneous
		# antipodal change has no unique shortest axis; use the previous right.
		return frame if cosine > 0 else (Basis(frame.x.normalized(), PI) * frame).orthonormalized()
	return (Basis(axis.normalized(), atan2(axis.length(), cosine)) * frame).orthonormalized()

func update_camera(_delta := 0.0) -> void:
	var ground := walker.support.global_basis * walker.support.surface_frame(walker.foot)
	camera_frame = transport_ground(camera_frame, ground.y)
	camera_bias = ground.inverse() * camera_frame
	overview.size = overview_size * overview_zoom
	var azimuth := 3.0 * PI / 4.0 + overview_yaw
	var offset := Vector3(sin(azimuth) * cos(overview_elevation), sin(overview_elevation), cos(azimuth) * cos(overview_elevation)) * sqrt(3400.0)
	overview.position = focus + camera_frame * offset
	overview.look_at(focus, ground.y)

func orbit_overview(relative: Vector2) -> void:
	if not architectural or paused or busy or blocks_play():
		return
	overview_yaw = wrapf(overview_yaw - relative.x * .006, -PI, PI)
	overview_elevation = clampf(overview_elevation + relative.y * .006, deg_to_rad(25), deg_to_rad(70))
	update_camera()

func zoom_overview(steps: float) -> void:
	if not architectural or paused or busy or blocks_play():
		return
	overview_zoom = clampf(overview_zoom * exp(-steps * .12), .65, 1.4)
	update_camera()

func reset_overview() -> void:
	overview_yaw = 0.0
	overview_elevation = DEFAULT_ELEVATION
	overview_zoom = 1.0
	update_camera()

# --- Input and frame loop -------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# Release even over UI; _unhandled_input alone can miss that event.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		overview_dragging = false

func _process(delta: float) -> void:
	if walker.support == null:
		return
	if not architectural and not paused and not busy and not blocks_play():
		var movement := Input.get_vector("left", "right", "forward", "back")
		walker.align_movement_to_camera(movement)
		walker.walk(movement, minf(delta, 0.1))
		if not won and reached_goal():
			won = true
			finish_open = true
			record_completion()
			message = "Connection reached. What needed to happen first?"
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			save_progress()
	walker.sync_pose(delta)
	walker.avatar.visible = architectural or walker.third_person
	update_camera(delta)
	walker.update_overview_visibility(overview, architectural)
	hud.refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		set_pause(not paused)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		hud.debug = not hud.debug
		return
	if paused or blocks_play() or (event is InputEventKey and event.echo):
		return
	if event.is_action_pressed("view") and not busy:
		toggle_view()
	elif event.is_action_pressed("undo"):
		undo()
	elif event.is_action_pressed("reset"):
		restart()
	elif event.is_action_pressed("hint"):
		show_hint()
	elif architectural and not busy:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				overview_dragging = event.pressed
			elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_overview(1)
			elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_overview(-1)
		elif event is InputEventMouseMotion and overview_dragging and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			orbit_overview(event.relative)
		elif event.is_action_pressed("reset_view"):
			reset_overview()
		elif event.is_action_pressed("rotate_left"):
			rotate_selected(-1)
		elif event.is_action_pressed("rotate_right"):
			rotate_selected(1)
		elif event is InputEventKey and event.pressed and event.keycode >= KEY_1 and event.keycode <= KEY_9:
			select_rig(event.keycode - KEY_1)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		walker.look(event.relative)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		overview_dragging = false
	if what == NOTIFICATION_WM_CLOSE_REQUEST and walker != null and walker.support != null:
		save_progress()

func toggle_view() -> void:
	overview_dragging = false
	architectural = not architectural
	walker.moving = false
	walker.sync_pose(1)
	update_camera()
	if architectural:
		overview.current = true
	else:
		walker.camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if architectural else Input.MOUSE_MODE_CAPTURED

# --- Structure turns ------------------------------------------------------------------------

func select_rig(index: int) -> void:
	if rigs.is_empty(): return
	selected = clampi(index, 0, rigs.size() - 1)
	for part in pieces:
		part.highlight(rigs[selected].node.is_ancestor_of(part))

func boxes_overlap(a: MeshInstance3D, b: MeshInstance3D) -> bool:
	# Oriented-box SAT, with a small construction clearance at docking edges.
	var ha: Vector3 = ((a.mesh as BoxMesh).size * 0.5 - Vector3.ONE * 0.04).max(Vector3.ONE * 0.01)
	var hb: Vector3 = ((b.mesh as BoxMesh).size * 0.5 - Vector3.ONE * 0.04).max(Vector3.ONE * 0.01)
	var separation := b.global_position - a.global_position
	if separation.length_squared() > pow(ha.length() + hb.length(), 2):
		return false
	var axes: Array[Vector3] = [a.global_basis.x, a.global_basis.y, a.global_basis.z, b.global_basis.x, b.global_basis.y, b.global_basis.z]
	for i in range(3):
		for j in range(3):
			axes.append(a.global_basis[i].cross(b.global_basis[j]))
	for axis in axes:
		if axis.length_squared() < 0.00001:
			continue
		var radius_a := 0.0
		var radius_b := 0.0
		for k in range(3):
			radius_a += ha[k] * absf(axis.dot(a.global_basis[k]))
			radius_b += hb[k] * absf(axis.dot(b.global_basis[k]))
		if absf(separation.dot(axis)) >= radius_a + radius_b:
			return false
	return true

func turn_obstruction(index: int, direction: int) -> String:
	var entry := rigs[index]
	if entry.get("locked", false): return "This structure is locked."
	if next_rotation_state(entry, direction) == entry.state: return "There is no further authored state in that direction."
	if not entry.get("carries_player", true) and entry.node.is_ancestor_of(walker.support): return "Step onto fixed ground before moving this structure."
	var original: Basis = entry.node.basis
	var fixed: Array[MeshInstance3D] = []
	for part in pieces:
		if not entry.node.is_ancestor_of(part):
			fixed.append_array(part.solid_meshes)
	for obstacle in obstacles:
		if not entry.node.is_ancestor_of(obstacle):
			fixed.append(obstacle)
	# A sphere about the pivot encloses every rigid turn. Discard architecture
	# outside that envelope before the expensive sampled SAT. This is conservative:
	# nearby boxes still receive every sample, and passenger clearance continues to
	# consider the whole environment.
	var pivot: Vector3 = entry.node.global_position
	var sweep_radius := 0.0
	for moving in entry.solids:
		var radius: float = (moving.mesh as BoxMesh).size.length() * .5
		sweep_radius = maxf(sweep_radius, moving.global_position.distance_to(pivot) + radius)
	var candidates: Array[MeshInstance3D] = []
	for stationary in fixed:
		var radius: float = (stationary.mesh as BoxMesh).size.length() * .5
		if stationary.global_position.distance_squared_to(pivot) <= pow(sweep_radius + radius, 2):
			candidates.append(stationary)
	var result := ""
	var interval := rotation_interval(entry, direction)
	var samples := maxi(60, int(ceil(absf(interval.y - interval.x) / deg_to_rad(1.5))))
	for step in range(1, samples + 1):
		entry.node.basis = rotation_basis(entry, lerpf(interval.x, interval.y, float(step) / samples))
		for moving in entry.solids:
			for stationary in candidates:
				if boxes_overlap(moving, stationary):
					var blocker_label := str(stationary.get_parent().name).replace("_", " ")
					var ancestor: Node = stationary.get_parent()
					while ancestor != null and ancestor != world:
						if ancestor is SurfacePiece:
							blocker_label = ancestor.title
							break
						ancestor = ancestor.get_parent()
					result = "The turn is blocked by " + blocker_label + "."
					break
			if not result.is_empty():
				break
		if result.is_empty() and not walker.pose_is_clear(walker.support, walker.foot, walker.normal):
			result = "Your position is inside the turning structure's sweep."
		if not result.is_empty():
			break
	entry.node.basis = original
	return result

func rotation_basis(entry: Dictionary, angle: float) -> Basis:
	return entry.get("base_basis", Basis.IDENTITY) * Basis(entry.axis.normalized(), angle)

func rotation_interval(entry: Dictionary, direction: int) -> Vector2:
	var angles: PackedFloat32Array = entry.get("angles", PackedFloat32Array([0, 90, 180, 270]))
	var from := deg_to_rad(angles[entry.state])
	var to := deg_to_rad(angles[next_rotation_state(entry, direction)])
	if not entry.get("wrap_states", true): return Vector2(from, to)
	if direction > 0 and to <= from: to += TAU
	if direction < 0 and to >= from: to -= TAU
	return Vector2(from, to)

func next_rotation_state(entry: Dictionary, direction: int) -> int:
	var count: int = entry.get("angles", [0, 90, 180, 270]).size()
	return posmod(entry.state + direction, count) if entry.get("wrap_states", true) else clampi(entry.state + direction, 0, count - 1)

func rotate_selected(direction: int) -> void:
	if busy or paused or blocks_play() or not architectural or rigs.is_empty():
		return
	var obstruction := turn_obstruction(selected, direction)
	if not obstruction.is_empty():
		message = obstruction
		return
	history.append(snapshot())
	var entry := rigs[selected]
	var interval := rotation_interval(entry, direction)
	entry.state = next_rotation_state(entry, direction)
	busy = true
	update_links()
	tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(angle: float): entry.node.basis = rotation_basis(entry, angle); update_camera(), interval.x, interval.y, 0.0 if walker.reduced_motion else entry.get("duration", .8))
	tween.tween_callback(func():
		busy = false
		update_links()
		update_camera()
		message = "The structure settles. Which path meets your ground now?"
		save_progress()
	)

# --- Snapshots, undo, pause -----------------------------------------------------------------

func snapshot() -> Dictionary:
	var player := walker.snapshot()
	player.piece = str(world.get_path_to(walker.support))
	var states: Array[int] = []
	for entry in rigs:
		states.append(entry.state)
	return {"states": states, "player": player, "camera_bias": camera_bias, "camera_frame": camera_frame, "overview_yaw": overview_yaw, "overview_elevation": overview_elevation, "overview_zoom": overview_zoom, "selected": selected}

func restore(data: Dictionary) -> void:
	if tween and tween.is_valid():
		tween.kill()
	busy = false
	won = false
	overview_dragging = false
	for i in range(rigs.size()):
		rigs[i].state = data.states[i]
		var angles: PackedFloat32Array = rigs[i].get("angles", PackedFloat32Array([0, 90, 180, 270]))
		rigs[i].node.basis = rotation_basis(rigs[i], deg_to_rad(angles[data.states[i]]))
	walker.restore(data.player, world)
	camera_bias = data.camera_bias
	var ground := walker.support.global_basis * walker.support.surface_frame(walker.foot)
	camera_frame = data.get("camera_frame", ground * camera_bias)
	overview_yaw = data.get("overview_yaw", 0.0)
	overview_elevation = clampf(data.get("overview_elevation", DEFAULT_ELEVATION), deg_to_rad(25), deg_to_rad(70))
	overview_zoom = clampf(data.get("overview_zoom", 1.0), .65, 1.4)
	select_rig(data.selected)
	update_links()
	update_camera()
	if architectural:
		overview.current = true
	else:
		walker.camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if architectural or paused else Input.MOUSE_MODE_CAPTURED

func undo() -> void:
	if busy or history.is_empty():
		return
	restore(history.pop_back())
	message = "Restored the arrangement and your position before the turn."
	save_progress()

func restart() -> void:
	if busy:
		return
	restore(initial)
	history.clear()
	hint_level = 0
	message = puzzle_question()
	save_progress()

func set_pause(value: bool) -> void:
	paused = value
	overview_dragging = false
	if paused and not busy:
		save_progress()
	if busy and tween and tween.is_valid():
		if paused: tween.pause()
		else: tween.play()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused or architectural or blocks_play() else Input.MOUSE_MODE_CAPTURED
	hud.refresh()

func blocks_play() -> bool:
	return won and finish_open

func continue_exploring() -> void:
	finish_open = false
	hud.refresh()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if architectural else Input.MOUSE_MODE_CAPTURED
	save_progress()

func show_reflection() -> void:
	finish_open = true
	set_pause(false)
	hud.refresh()

func connection_text() -> String:
	var names: Array[String] = []
	for part in walker.support.neighbours:
		names.append(part.title)
	return "Ground: " + walker.support.title + "\n" + ("No joined path here" if names.is_empty() else "Joined: " + ", ".join(names))

# --- Preferences and progress ---------------------------------------------------------------

func load_preferences() -> void:
	var settings := ConfigFile.new()
	settings.load("user://settings.cfg")
	# First person is the game's traversal perspective (spec §6).
	walker.third_person = false
	walker.reduced_motion = settings.get_value("comfort", "reduced_motion", false)
	walker.sensitivity = settings.get_value("comfort", "sensitivity", 0.0022)
	walker.camera_initialized = false
	walker.sync_pose(1)
	hud.sync_preferences()

func save_preferences() -> void:
	var settings := ConfigFile.new()
	settings.load("user://settings.cfg")
	for key in ["reduced_motion", "sensitivity"]:
		settings.set_value("comfort", key, walker.get(key))
	settings.save("user://settings.cfg")

func save_progress() -> void:
	if busy or progress_path().is_empty() or "--self-test" in OS.get_cmdline_user_args():
		return
	var file := FileAccess.open(progress_path(), FileAccess.WRITE)
	if file: file.store_var(progress_data())

func load_progress() -> void:
	if progress_path().is_empty() or not FileAccess.file_exists(progress_path()):
		return
	var data = FileAccess.open(progress_path(), FileAccess.READ).get_var()
	if data is Dictionary: apply_progress(data)

func open_level(scene_path: String) -> void:
	save_progress()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(scene_path)
