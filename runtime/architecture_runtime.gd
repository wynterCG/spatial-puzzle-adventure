extends Node3D
## Generic Elsewhere runtime: first-person traversal, the isometric architectural view (camera B),
## discrete structure turns with sweep clearance, snapshots, undo and progress hooks.
## Connectivity follows matching authored contacts; no progress flag or camera alignment enables a route.
## Subclasses build the world in build_level() and override the puzzle_*/progress hooks.
const Piece = preload("res://core/surface_piece.gd")
const Walker = preload("res://core/surface_walker.gd")
const HUD = preload("res://runtime/hud.gd")
const OUTLINE = preload("res://runtime/outline.gdshader")
const Atmosphere = preload("res://runtime/atmosphere.gd")
## Settings written before v2 saved the FOV on every change, so an old value is not a choice.
const PREFERENCES_VERSION := 2
# Zoom and pan around the authored framing (spec §11). Neither ever rotates the view.
const ZOOM_MIN := .4
const ZOOM_MAX := 1.6
const PAN_LIMIT := .5 # fraction of the authored framing size the view may slide away
## Farthest a turning solid may move between sweep samples. The thinnest solid at any scale
## (a 0.26 m curve deck) can never fall between two samples.
const SWEEP_STEP := .25
var sweep_tolerance := .04
## Framing size at which the traveller is drawn life-size in the isometric view.
const MARKER_REFERENCE := 36.0
var world: Node3D
var pieces: Array[SurfacePiece] = []
var rigs: Array[Dictionary] = []
var ports: Array[Dictionary] = []
var obstacles: Array[MeshInstance3D] = []
var walker: SurfaceWalker
var environment: Environment
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
# Authored composition offset in the player's ground frame (ElsewhereLevel.overview_local_offset).
var overview_local_offset := Vector3(30, 40, -30)
var overview_zoom := 1.0
# Screen-plane pan in metres (x right, y up), applied after the authored composition.
var overview_pan := Vector2.ZERO
# Movable structure under the cursor in the isometric view (-1: none). Selection is diegetic:
# the structures themselves glow; there is no list of movable pieces in the HUD.
var hovered := -1
var glow_materials: Dictionary = {}
var focus := Vector3.ZERO
var overview_size := 32.0
var message := ""
var hint_level := 0
var input_bindings := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "view": KEY_TAB, "rotate_left": KEY_Q, "rotate_right": KEY_E, "undo": KEY_Z, "reset": KEY_R, "hint": KEY_H, "reset_view": KEY_HOME}

func _ready() -> void:
	configure_input()
	var world_environment := WorldEnvironment.new()
	environment = Atmosphere.world_environment()
	world_environment.environment = environment
	add_child(world_environment)
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
## A short contextual prompt for something usable right now (first person only); empty otherwise.
func interaction_prompt() -> String: return ""

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

# --- Camera B: authored composition, ground-normal transport, limited zoom ------------------

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
	overview.position = focus + camera_frame * overview_local_offset
	overview.look_at(focus, ground.y)
	# Pan slides the camera parallel to the screen, so the authored angle never changes.
	overview.position += overview.global_basis.x * overview_pan.x + overview.global_basis.y * overview_pan.y

func update_marker_scale() -> void:
	walker.marker_scale = maxf(1.0, overview.size / MARKER_REFERENCE) if architectural else 1.0

func zoom_overview(steps: float) -> void:
	if not architectural or paused or busy or blocks_play():
		return
	overview_zoom = clampf(overview_zoom * exp(-steps * .12), ZOOM_MIN, ZOOM_MAX)
	update_camera()
	refresh_glow()

func pan_overview(amount: Vector2) -> void:
	if not architectural or paused or blocks_play():
		return
	overview_pan = (overview_pan + amount).limit_length(overview_size * PAN_LIMIT)
	update_camera()

## Home: restores the authored framing (zoom and pan). The angle is fixed per monument.
func reset_overview() -> void:
	overview_zoom = 1.0
	overview_pan = Vector2.ZERO
	update_camera()

# --- Input and frame loop -------------------------------------------------------------------

func _process(delta: float) -> void:
	if walker.support == null:
		return
	if architectural and not paused and not blocks_play():
		# WASD pans the isometric view; the character does not move in this view.
		var pan := Input.get_vector("left", "right", "back", "forward")
		if pan != Vector2.ZERO: pan_overview(pan * overview.size * .6 * minf(delta, .1))
	if not architectural and not paused and not busy and not blocks_play():
		var movement := Input.get_vector("left", "right", "forward", "back")
		walker.walk(movement, minf(delta, 0.1))
		if not won and reached_goal():
			won = true
			finish_open = true
			record_completion()
			message = "Connection reached. What needed to happen first?"
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			save_progress()
	update_marker_scale()
	walker.sync_pose(delta)
	walker.avatar.visible = architectural
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
		# No orbit: the angle is authored (spec §11). The wheel zooms, right/middle-drag pans,
		# and pointing at the architecture chooses what to turn.
		if event is InputEventMouseButton:
			if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_overview(1)
			elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_overview(-1)
			elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				var picked := pick_rig(event.position)
				if picked >= 0: select_rig(picked)
		elif event is InputEventMouseMotion:
			if event.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
				var metres_per_pixel: float = overview.size / maxf(1.0, get_viewport().get_visible_rect().size.y)
				pan_overview(Vector2(-event.relative.x, event.relative.y) * metres_per_pixel)
			else:
				set_hovered(pick_rig(event.position))
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
	if what == NOTIFICATION_WM_CLOSE_REQUEST and walker != null and walker.support != null:
		save_progress()

func toggle_view() -> void:
	architectural = not architectural
	walker.moving = false
	update_marker_scale()
	walker.sync_pose(1)
	update_camera()
	if architectural:
		overview.current = true
	else:
		walker.camera.current = true
		hovered = -1
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if architectural else Input.MOUSE_MODE_CAPTURED
	refresh_glow()

# --- Diegetic selection ---------------------------------------------------------------------

## The movable structure whose own geometry is under a screen point in the isometric view.
## Only movable assemblies are tested, so static architecture never steals a click and
## hidden interiors are never pickable. Boxes are exact; rings count as flat annuli.
func pick_rig(screen: Vector2) -> int:
	if not architectural or rigs.is_empty(): return -1
	var origin := overview.project_ray_origin(screen)
	var direction := overview.project_ray_normal(screen)
	var best := INF
	var found := -1
	for k in range(rigs.size()):
		for visual in rigs[k].node.find_children("*", "MeshInstance3D", true, false):
			if visual.mesh == null or not visual.is_visible_in_tree(): continue
			var distance := ray_hit(visual, origin, direction)
			if distance < best:
				best = distance
				found = k
	return found

func ray_hit(visual: MeshInstance3D, origin: Vector3, direction: Vector3) -> float:
	var inverse := visual.global_transform.affine_inverse()
	var local_origin: Vector3 = inverse * origin
	var local_direction: Vector3 = (inverse.basis * direction).normalized()
	var scale := (visual.global_transform.basis * local_direction).length()
	if visual.mesh is TorusMesh:
		if absf(local_direction.y) < .0001: return INF
		var t := -local_origin.y / local_direction.y
		var point := local_origin + local_direction * t
		var radius := Vector2(point.x, point.z).length()
		var torus := visual.mesh as TorusMesh
		return t * scale if t > 0 and radius >= torus.inner_radius and radius <= torus.outer_radius else INF
	var hit = visual.mesh.get_aabb().intersects_ray(local_origin, local_direction)
	return INF if hit == null else (hit - local_origin).length() * scale

func set_hovered(index: int) -> void:
	if index == hovered: return
	hovered = index
	refresh_glow()

## Each movable assembly glows in its own accent colour: faintly when hovered, more when
## selected. Only in the isometric view; first person stays clean.
func refresh_glow() -> void:
	for k in range(rigs.size()):
		var level := 0
		if architectural and k == selected: level = 2
		elif architectural and k == hovered: level = 1
		var overlay: Material = null if level == 0 else glow_material(rigs[k].get("tint", Color("e4dfd6")), level)
		for visual in rigs[k].node.find_children("*", "MeshInstance3D", true, false):
			visual.material_overlay = overlay

## An outline, not a fill: the structure's faces stay readable. Hover is thin and dim,
## selection slightly thicker and brighter. The width follows the framing, like the marker, so
## the outline keeps its on-screen size on monumental compositions.
func glow_material(tint: Color, level: int) -> ShaderMaterial:
	var key := str(tint) + str(level)
	if not glow_materials.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = OUTLINE
		mat.set_shader_parameter("color", tint.darkened(.2) if level == 1 else tint.lightened(.2))
		glow_materials[key] = mat
	glow_materials[key].set_shader_parameter("width", (.045 if level == 1 else .085) * maxf(1.0, overview.size / MARKER_REFERENCE))
	return glow_materials[key]

# --- Structure turns ------------------------------------------------------------------------

func select_rig(index: int) -> void:
	if rigs.is_empty(): return
	selected = clampi(index, 0, rigs.size() - 1)
	refresh_glow()

func boxes_overlap(a: MeshInstance3D, b: MeshInstance3D) -> bool:
	# Oriented-box SAT, with a small construction clearance at docking edges.
	var ha: Vector3 = ((a.mesh as BoxMesh).size * 0.5 - Vector3.ONE * sweep_tolerance).max(Vector3.ONE * 0.01)
	var hb: Vector3 = ((b.mesh as BoxMesh).size * 0.5 - Vector3.ONE * sweep_tolerance).max(Vector3.ONE * 0.01)
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

## Farthest any solid of a turning structure reaches from its pivot (box corners included).
func sweep_reach(entry: Dictionary) -> float:
	var pivot: Vector3 = entry.node.global_position
	var reach := 0.0
	for moving in entry.solids:
		reach = maxf(reach, moving.global_position.distance_to(pivot) + (moving.mesh as BoxMesh).size.length() * .5)
	return reach

## Sweep samples by arc length: the farthest solid moves at most SWEEP_STEP between samples.
func sweep_samples(entry: Dictionary, interval: Vector2) -> int:
	var angle := absf(interval.y - interval.x)
	return maxi(60, maxi(int(ceil(angle / deg_to_rad(1.5))), int(ceil(angle * sweep_reach(entry) / SWEEP_STEP))))

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
	var sweep_radius := sweep_reach(entry)
	var candidates: Array[MeshInstance3D] = []
	for stationary in fixed:
		var radius: float = (stationary.mesh as BoxMesh).size.length() * .5
		if stationary.global_position.distance_squared_to(pivot) <= pow(sweep_radius + radius, 2):
			candidates.append(stationary)
	var result := ""
	var interval := rotation_interval(entry, direction)
	var samples := sweep_samples(entry, interval)
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
	return {"states": states, "player": player, "camera_bias": camera_bias, "camera_frame": camera_frame, "overview_zoom": overview_zoom, "overview_pan": overview_pan, "selected": selected}

func restore(data: Dictionary) -> void:
	if tween and tween.is_valid():
		tween.kill()
	busy = false
	won = false
	for i in range(rigs.size()):
		rigs[i].state = data.states[i]
		var angles: PackedFloat32Array = rigs[i].get("angles", PackedFloat32Array([0, 90, 180, 270]))
		rigs[i].node.basis = rotation_basis(rigs[i], deg_to_rad(angles[data.states[i]]))
	walker.restore(data.player, world)
	camera_bias = data.camera_bias
	var ground := walker.support.global_basis * walker.support.surface_frame(walker.foot)
	camera_frame = data.get("camera_frame", ground * camera_bias)
	# Older snapshots may carry overview_yaw/overview_elevation from the orbit era; ignore them.
	overview_zoom = clampf(data.get("overview_zoom", 1.0), ZOOM_MIN, ZOOM_MAX)
	overview_pan = Vector2(data.get("overview_pan", Vector2.ZERO)).limit_length(overview_size * PAN_LIMIT)
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
	apply_preferences(settings)

func apply_preferences(settings: ConfigFile) -> void:
	walker.reduced_motion = settings.get_value("comfort", "reduced_motion", false)
	walker.sensitivity = settings.get_value("comfort", "sensitivity", 0.0022)
	# Before v2 the old 72 default was saved on every change; any other value was chosen.
	var saved_fov: float = settings.get_value("comfort", "fov", walker.profile.fov)
	var chosen_fov: bool = settings.get_value("comfort", "version", 1) >= PREFERENCES_VERSION or not is_equal_approx(saved_fov, 72.0)
	walker.fov = clampf(saved_fov, 60, 95) if chosen_fov else walker.profile.fov
	walker.turn_rate = settings.get_value("comfort", "turn_rate", walker.profile.max_gravity_turn_rate)
	walker.sync_pose(1)
	hud.sync_preferences()

func save_preferences() -> void:
	var settings := ConfigFile.new()
	settings.load("user://settings.cfg")
	for key in ["reduced_motion", "sensitivity", "fov", "turn_rate"]:
		settings.set_value("comfort", key, walker.get(key))
	settings.set_value("comfort", "version", PREFERENCES_VERSION)
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
