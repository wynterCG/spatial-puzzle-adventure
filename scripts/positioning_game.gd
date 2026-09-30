extends Node3D
## Three physical positioning studies and one complete puzzle. Connectivity follows matching authored
## contacts; no milestone flag, portal or camera alignment enables a route.
const Piece = preload("res://scripts/surface_piece.gd")
const Walker = preload("res://scripts/surface_walker.gd")
const CurvedPath = preload("res://scripts/curved_track.gd")
const TrialHUD = preload("res://scripts/positioning_hud.gd")
const TITLES := ["Choose your deck", "The quiet landing", "Prepare the receiver", "The Lantern Fold"]
const QUESTIONS := ["Which path needs to carry you?", "Where can you stand while the carrier changes?", "What needs to move before the dock closes?", "Which path must carry you, and what must be ready when it arrives?"]
const REASONS := ["The short deck never reaches the exit. The curved path gets you onto the long deck before the roll.", "The carrier's two paths have different ground. The fixed landing and its curve let you change paths while the empty carrier turns.", "The docking arms obstruct the receiver's turn. Arrange the receiver before docking the carrier.", "The upper path cannot reach the receiver. Use the curve to reach the longer underside path. Prepare the receiver while the turnover is withdrawn, then ride the long path through two turns. Its brass arms hold the connection until you walk to the lantern."]
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
var trial := 0
var selected := 0
var architectural := true
var busy := false
var paused := false
var won := false
var tween: Tween
var history: Array[Dictionary] = []
var initial: Dictionary
var camera_bias := Basis.IDENTITY
var camera_frame := Basis.IDENTITY
const DEFAULT_ELEVATION := 0.7559694104 # atan2(40, sqrt(30*30 + 30*30))
var overview_yaw := 0.0
var overview_elevation := DEFAULT_ELEVATION
var overview_zoom := 1.0
var overview_dragging := false
var focus := Vector3.ZERO
var overview_size := 32.0
var message := ""
var hint_level := 0
var completed: Array = [false, false, false, false]
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
	hud = TrialHUD.new()
	hud.game = self
	add_child(hud)
	load_trial(3)
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

func load_trial(index: int) -> void:
	if tween and tween.is_valid():
		tween.kill()
	if world:
		walker.support = null
		remove_child(world)
		world.queue_free()
	world = Node3D.new()
	world.name = "Study"
	add_child(world)
	pieces.clear()
	rigs.clear()
	ports.clear()
	obstacles.clear()
	history.clear()
	trial = clampi(index, 0, TITLES.size() - 1)
	selected = 0
	busy = false
	paused = false
	won = false
	hint_level = 0
	message = "Reach the light. Study the gaps and decide where to stand."
	match trial:
		0: build_decks()
		1: build_landing()
		2: build_receiver()
		3: preload("res://scripts/complete_puzzle.gd").build(self)
	walker.pieces = pieces
	walker.camera_obstacles = obstacles
	walker.camera_initialized = false
	walker.world_orbit_initialized = false
	walker.place(start, Vector3(0, start.half.y, 0), Vector3.UP, Vector3.RIGHT)
	camera_bias = Basis.IDENTITY
	camera_frame = walker.support.global_basis * walker.support.surface_frame(walker.foot)
	overview_yaw = 0.0
	overview_elevation = DEFAULT_ELEVATION
	overview_zoom = 1.0
	overview_dragging = false
	architectural = true
	update_links()
	update_camera()
	select_rig(0)
	overview.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	initial = snapshot()
	hud.refresh()

func slab(id: String, parent: Node3D, at: Vector3, size: Vector3, tint: Color, frame := Basis.IDENTITY) -> SurfacePiece:
	var part := Piece.new()
	part.name = id
	parent.add_child(part)
	part.transform = Transform3D(frame, at)
	part.setup(id.replace("_", " "), size, tint)
	part.walk_regions = [Rect2(-size.x * 0.5, -size.z * 0.5, size.x, size.z)]
	part.draw_paths()
	pieces.append(part)
	return part

func rig(label: String, at: Vector3, axis: Vector3, state: int) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = label.replace(" ", "_")
	world.add_child(pivot)
	pivot.position = at
	pivot.basis = Basis(axis, state * PI / 2)
	rigs.append({"node": pivot, "axis": axis, "state": state, "label": label, "solids": []})
	return pivot

func port(part: SurfacePiece, point: Vector3, normal := Vector3.UP) -> void:
	var mark := Piece.box(part, point + normal * 0.035, Vector3(0.28, 0.03, 0.28), Piece.material(Color("c5ac83"), 0.15))
	mark.basis = part.surface_frame(point)
	ports.append({"piece": part, "point": point, "normal": normal, "mark": mark, "joined": false})

func x_ports(part: SurfacePiece) -> void:
	for side in [-1.0, 1.0]:
		port(part, Vector3(side * part.half.x, part.half.y, 0))

func z_ports(part: SurfacePiece) -> void:
	for side in [-1.0, 1.0]:
		port(part, Vector3(0, part.half.y, side * part.half.z))

func finish_layout() -> void:
	for entry in rigs:
		for part in pieces:
			if entry.node.is_ancestor_of(part):
				entry.solids.append_array(part.solid_meshes)
	var beacon := Piece.box(goal, Vector3(0, goal.half.y + 0.55, 0), Vector3(0.35, 1.1, 0.35), Piece.material(Color("eac991"), 0.4))
	# The goal is a small light, with free space around it rather than a wall.
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.32
	sphere.height = 0.64
	orb.mesh = sphere
	orb.material_override = Piece.material(Color("ffdfa2"), 1.0)
	beacon.add_child(orb)
	orb.position.y = 0.75

func build_decks() -> void:
	focus = Vector3(-2, -2, -1)
	overview_size = 35
	start = slab("Arrival", world, Vector3(-9, 0.8, -2), Vector3(6, 0.4, 6), Color("647790"))
	start.walk_regions = [Rect2(-3, -0.8, 6, 1.6), Rect2(-0.8, -3, 1.6, 3)]
	start.draw_paths()
	x_ports(start)
	port(start, Vector3(0, 0.2, -3))
	var lower := slab("Lower_landing", world, Vector3(-9, -4.8, -2), Vector3(6, 0.4, 1.6), Color("647790"), Basis(Vector3.RIGHT, PI))
	x_ports(lower)
	port(lower, Vector3(0, 0.2, 0.8))
	var curve := CurvedPath.new()
	curve.name = "Rounded_path"
	world.add_child(curve)
	curve.position = Vector3(-9, 1, -5)
	curve.tail_length = 2.2
	curve.build()
	curve.deployed = true
	curve.set_deployment(1)
	pieces.append(curve)
	port(curve, curve.point_at(0), Vector3.UP)
	port(curve, curve.point_at(curve.length()), Vector3.DOWN)
	var pivot := rig("Twin deck", Vector3(0, -2, 0), Vector3.RIGHT, 0)
	var upper := slab("Short_deck", pivot, Vector3(-2, 2.8, -2), Vector3(8, 0.4, 1.6), Color("b98270"))
	var underside := slab("Long_deck", pivot, Vector3(0, -2.8, -2), Vector3(12, 0.4, 1.6), Color("9d899f"), Basis(Vector3.RIGHT, PI))
	x_ports(upper)
	x_ports(underside)
	# A non-walkable spine makes the two separate paths read as one machine.
	for x in [-5.5, 1.5]:
		var strut := Piece.box(pivot, Vector3(x, 0, -2), Vector3(0.18, 5.4, 0.24), Piece.material(Color("605869")))
		obstacles.append(strut)
		rigs[0].solids.append(strut)
	goal = slab("Exit", world, Vector3(9, 0.8, 2), Vector3(6, 0.4, 1.6), Color("719899"))
	x_ports(goal)
	finish_layout()

func build_landing() -> void:
	focus = Vector3(1, 0, -2)
	overview_size = 29
	start = slab("Arrival", world, Vector3(9, 2.8, 0), Vector3(6, 0.4, 1.6), Color("647790"))
	x_ports(start)
	var pivot := rig("Split carrier", Vector3.ZERO, Vector3.UP, 0)
	var first := slab("First_path", pivot, Vector3(4.5, 2.8, 0), Vector3(3, 0.4, 1.6), Color("b98270"))
	var second := slab("Second_path", pivot, Vector3(0, -2.8, 3.5), Vector3(1.6, 0.4, 5), Color("9d899f"), Basis(Vector3.RIGHT, PI))
	x_ports(first)
	z_ports(second)
	var axle := Piece.box(pivot, Vector3(0, -0.5, 0), Vector3(0.6, 0.6, 0.6), Piece.material(Color("ba9767")))
	obstacles.append(axle)
	rigs[0].solids.append(axle)
	for strut in [[Vector3(2.25, -0.5, 0), Vector3(4.5, 0.18, 0.22)], [Vector3(4.5, 1.15, 0), Vector3(0.18, 3.3, 0.22)], [Vector3(0, -0.5, 1.75), Vector3(0.22, 0.18, 3.5)], [Vector3(0, -1.65, 3.5), Vector3(0.22, 2.3, 0.18)]]:
		var brace := Piece.box(pivot, strut[0], strut[1], Piece.material(Color("605869")))
		obstacles.append(brace)
		rigs[0].solids.append(brace)
	var landing := slab("Fixed_landing", world, Vector3(0, 2.8, -7.5), Vector3(1.6, 0.4, 3), Color("647790"))
	z_ports(landing)
	var curve := CurvedPath.new()
	curve.name = "Landing_curve"
	world.add_child(curve)
	curve.position = Vector3(0, 3, -9)
	curve.build()
	curve.deployed = true
	curve.set_deployment(1)
	pieces.append(curve)
	port(curve, curve.point_at(0), Vector3.UP)
	port(curve, curve.point_at(curve.length()), Vector3.DOWN)
	goal = slab("Exit", world, Vector3(0, -2.8, 0), Vector3(2, 0.4, 2), Color("719899"), Basis(Vector3.RIGHT, PI))
	goal.walk_regions = [Rect2(-1, -0.25, 2, 0.5), Rect2(-0.25, -1, 0.5, 2)]
	var boxes: Array[AABB] = []
	for region in goal.walk_regions:
		boxes.append(AABB(Vector3(region.position.x, -0.2, region.position.y), Vector3(region.size.x, 0.4, region.size.y)))
	goal.set_solid_boxes(boxes)
	goal.draw_paths()
	x_ports(goal)
	z_ports(goal)
	finish_layout()

func build_receiver() -> void:
	focus = Vector3(4, 0, 3)
	overview_size = 30
	start = slab("Arrival", world, Vector3(0, -3, 0.8), Vector3(6, 0.4, 1.6), Color("647790"), Basis(Vector3.BACK, PI / 2))
	x_ports(start)
	var carrier := rig("Docking carrier", Vector3(0, 0, 0.8), Vector3.BACK, 1)
	var deck := slab("Carrier_path", carrier, Vector3(3.6, 0, 0), Vector3(7.2, 0.4, 1.6), Color("b98270"))
	# Recess the load-bearing slab at the pivot; the shallow paving lip covers
	# the hinge, without two deep rectangular beams colliding at their corner.
	deck.set_solid_boxes([AABB(Vector3(-3.3, -0.2, -0.8), Vector3(6.9, 0.4, 1.6))])
	x_ports(deck)
	for side in [-1.0, 1.0]:
		var finger := Piece.box(carrier, Vector3(7.25, 0, side * 1.05), Vector3(2.5, 0.4, 0.2), Piece.material(Color("ba9767")))
		obstacles.append(finger)
		rigs[0].solids.append(finger)
	var receiver := rig("Receiver", Vector3(9, 0, 4), Vector3.UP, 1)
	var path := slab("Receiver_path", receiver, Vector3.ZERO, Vector3(1, 0.4, 1), Color("9d899f"))
	path.walk_regions = [Rect2(-1.8, -4, 2.2, 1.6), Rect2(-0.4, -3.2, 0.8, 7.2)]
	var boxes: Array[AABB] = []
	for region in path.walk_regions:
		boxes.append(AABB(Vector3(region.position.x, -0.2, region.position.y), Vector3(region.size.x, 0.4, region.size.y)))
	path.set_solid_boxes(boxes)
	path.draw_paths()
	port(path, Vector3(-1.8, 0.2, -3.2))
	port(path, Vector3(0, 0.2, 4))
	goal = slab("Exit", world, Vector3(9, 0, 10), Vector3(1.6, 0.4, 4), Color("719899"))
	z_ports(goal)
	finish_layout()

func update_links() -> void:
	for part in pieces:
		part.neighbours.clear()
	for contact in ports:
		contact.joined = false
	if not busy:
		for i in range(ports.size()):
			var a := ports[i]
			for j in range(i + 1, ports.size()):
				var b := ports[j]
				if a.piece == b.piece:
					continue
				if a.piece.to_global(a.point).distance_to(b.piece.to_global(b.point)) < 0.03 and (a.piece.global_basis * a.normal).dot(b.piece.global_basis * b.normal) > 0.999:
					a.joined = true
					b.joined = true
					if not a.piece.neighbours.has(b.piece):
						a.piece.neighbours.append(b.piece)
						b.piece.neighbours.append(a.piece)
	for contact in ports:
		contact.mark.material_override = Piece.material(Color("8fc4b5") if contact.joined else Color("c5ac83"), 0.25)

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

func update_camera() -> void:
	var ground := walker.support.global_basis * walker.support.surface_frame(walker.foot)
	camera_frame = transport_ground(camera_frame, ground.y)
	camera_bias = ground.inverse() * camera_frame
	overview.size = overview_size * overview_zoom
	var azimuth := 3.0 * PI / 4.0 + overview_yaw
	var offset := Vector3(sin(azimuth) * cos(overview_elevation), sin(overview_elevation), cos(azimuth) * cos(overview_elevation)) * sqrt(3400.0)
	overview.position = focus + camera_frame * offset
	overview.look_at(focus, ground.y)

func orbit_overview(relative: Vector2) -> void:
	if not architectural or paused or busy or won:
		return
	overview_yaw = wrapf(overview_yaw - relative.x * .006, -PI, PI)
	overview_elevation = clampf(overview_elevation + relative.y * .006, deg_to_rad(25), deg_to_rad(70))
	update_camera()

func zoom_overview(steps: float) -> void:
	if not architectural or paused or busy or won:
		return
	overview_zoom = clampf(overview_zoom * exp(-steps * .12), .65, 1.4)
	update_camera()

func reset_overview() -> void:
	overview_yaw = 0.0
	overview_elevation = DEFAULT_ELEVATION
	overview_zoom = 1.0
	update_camera()

func _input(event: InputEvent) -> void:
	# Release even over UI; _unhandled_input alone can miss that event.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		overview_dragging = false

func _process(delta: float) -> void:
	if walker.support == null:
		return
	if not architectural and not paused and not busy and not won:
		var movement := Input.get_vector("left", "right", "forward", "back")
		walker.align_movement_to_camera(movement)
		walker.walk(movement, minf(delta, 0.1))
		if walker.support == goal and Vector2(walker.foot.x, walker.foot.z).length() < 1.2:
			won = true
			completed[trial] = true
			message = "Connection reached. What needed to happen first?"
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			save_progress()
	walker.sync_pose(delta)
	walker.avatar.visible = architectural or walker.third_person
	update_camera()
	walker.update_overview_visibility(overview, architectural)
	hud.refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		set_pause(not paused)
		return
	if paused or won or (event is InputEventKey and event.echo):
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
		elif event is InputEventKey and event.pressed and event.keycode in [KEY_1, KEY_2]:
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

func select_rig(index: int) -> void:
	selected = clampi(index, 0, rigs.size() - 1)
	for part in pieces:
		part.highlight(rigs[selected].node.is_ancestor_of(part))

func boxes_overlap(a: MeshInstance3D, b: MeshInstance3D) -> bool:
	# Oriented-box SAT, with a small construction clearance at docking edges.
	var ha: Vector3 = ((a.mesh as BoxMesh).size * 0.5 - Vector3.ONE * 0.04).max(Vector3.ONE * 0.01)
	var hb: Vector3 = ((b.mesh as BoxMesh).size * 0.5 - Vector3.ONE * 0.04).max(Vector3.ONE * 0.01)
	var axes: Array[Vector3] = [a.global_basis.x, a.global_basis.y, a.global_basis.z, b.global_basis.x, b.global_basis.y, b.global_basis.z]
	for i in range(3):
		for j in range(3):
			axes.append(a.global_basis[i].cross(b.global_basis[j]))
	var separation := b.global_position - a.global_position
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
	var original: Basis = entry.node.basis
	var fixed: Array[MeshInstance3D] = []
	for part in pieces:
		if not entry.node.is_ancestor_of(part):
			fixed.append_array(part.solid_meshes)
	for obstacle in obstacles:
		if not entry.node.is_ancestor_of(obstacle):
			fixed.append(obstacle)
	var result := ""
	for step in range(1, 61):
		entry.node.basis = Basis(entry.axis, (float(entry.state) + direction * float(step) / 60.0) * PI / 2)
		for moving in entry.solids:
			for stationary in fixed:
				if boxes_overlap(moving, stationary):
					result = "The turn is blocked by " + str(stationary.get_parent().name).replace("_", " ") + "."
					break
			if not result.is_empty():
				break
		if result.is_empty() and not walker.pose_is_clear(walker.support, walker.foot, walker.normal):
			result = "Your position is inside the turning structure's sweep."
		if not result.is_empty():
			break
	entry.node.basis = original
	return result

func rotate_selected(direction: int) -> void:
	if busy or paused or won or not architectural:
		return
	var obstruction := turn_obstruction(selected, direction)
	if not obstruction.is_empty():
		message = obstruction
		return
	history.append(snapshot())
	var entry := rigs[selected]
	var from: float = entry.state * PI / 2.0
	var to := from + direction * PI / 2.0
	entry.state = posmod(entry.state + direction, 4)
	busy = true
	update_links()
	tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(angle: float): entry.node.basis = Basis(entry.axis, angle); update_camera(), from, to, 0.0 if walker.reduced_motion else 0.8)
	tween.tween_callback(func():
		busy = false
		update_links()
		update_camera()
		message = "The structure settles. Which path meets your ground now?"
		save_progress()
	)

func snapshot() -> Dictionary:
	var player := walker.snapshot()
	player.piece = str(world.get_path_to(walker.support))
	var states: Array[int] = []
	for entry in rigs:
		states.append(entry.state)
	return {"trial": trial, "states": states, "player": player, "camera_bias": camera_bias, "camera_frame": camera_frame, "overview_yaw": overview_yaw, "overview_elevation": overview_elevation, "overview_zoom": overview_zoom, "selected": selected}

func restore(data: Dictionary) -> void:
	if tween and tween.is_valid():
		tween.kill()
	busy = false
	won = false
	overview_dragging = false
	for i in range(rigs.size()):
		rigs[i].state = data.states[i]
		rigs[i].node.basis = Basis(rigs[i].axis, data.states[i] * PI / 2)
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
	message = QUESTIONS[trial]
	save_progress()

func set_pause(value: bool) -> void:
	paused = value
	overview_dragging = false
	if paused and not busy:
		save_progress()
	if tween and tween.is_valid():
		if paused: tween.pause()
		else: tween.play()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused or architectural or won else Input.MOUSE_MODE_CAPTURED
	hud.refresh()

func show_hint() -> void:
	var hints := [
		["Compare where the two decks end.", "The short deck stops before the exit, even after a roll.", "Use the curved path to board the long underside deck, then roll twice and walk to the light."],
		["The two moving paths have no crossing between them.", "The fixed landing remains available while the carrier turns.", "Ride the first path one turn to the landing. Step off, turn once more, follow the fixed curve to the second path, and walk inward to the light."],
		["Watch the brass arms around the receiver's docking edge.", "Docking the carrier occupies the receiver's turning clearance.", "Arrange the receiver first, while the carrier is withdrawn. Board the carrier, roll it into the prepared receiver, then walk to the light."],
		["Compare the two turnover paths and the far end of the receiver. Which can form a continuous route?", "The curved stair leads to the longer path. The brass docking arms occupy the receiver sweep when the turnover arrives.", "Select 2 and turn the receiver left once while the turnover is withdrawn. Follow the curve underneath, board the long path, select 1 and turn twice. Cross the dock and follow the receiver to the lantern."]
	]
	message = hints[trial][mini(hint_level, 2)]
	hint_level += 1

func connection_text() -> String:
	var names: Array[String] = []
	for part in walker.support.neighbours:
		names.append(part.title)
	return "Ground: " + walker.support.title + "\n" + ("No joined path here" if names.is_empty() else "Joined: " + ", ".join(names))

func load_preferences() -> void:
	var settings := ConfigFile.new()
	settings.load("user://settings.cfg")
	walker.third_person = settings.get_value("comfort", "third_person", false)
	walker.reduced_motion = settings.get_value("comfort", "reduced_motion", false)
	walker.keep_world_horizon = settings.get_value("comfort", "world_aligned_camera", true)
	walker.camera_distance = clampf(settings.get_value("comfort", "camera_distance", 5.5), 3, 8)
	walker.sensitivity = settings.get_value("comfort", "sensitivity", 0.0022)
	walker.camera_initialized = false
	walker.sync_pose(1)
	hud.sync_preferences()

func save_preferences() -> void:
	var settings := ConfigFile.new()
	settings.load("user://settings.cfg")
	for key in ["third_person", "reduced_motion", "keep_world_horizon", "camera_distance", "sensitivity"]:
		settings.set_value("comfort", key, walker.get(key))
	settings.set_value("comfort", "world_aligned_camera", walker.keep_world_horizon)
	# Retire the experiment preference; old A settings must not restore A.
	if settings.has_section_key("overview", "follow_ground_normal"):
		settings.erase_section_key("overview", "follow_ground_normal")
	settings.save("user://settings.cfg")

func save_progress() -> void:
	if busy or "--self-test" in OS.get_cmdline_user_args():
		return
	var file := FileAccess.open("user://positioning.save", FileAccess.WRITE)
	if file:
		file.store_var({"version": 1, "scene": snapshot(), "completed": completed})

func load_progress() -> void:
	if not FileAccess.file_exists("user://positioning.save"):
		return
	var data = FileAccess.open("user://positioning.save", FileAccess.READ).get_var()
	if data is Dictionary and data.get("version") == 1 and data.has_all(["scene", "completed"]):
		load_trial(int(data.scene.trial))
		restore(data.scene)
		restore_completed(data.completed)

func restore_completed(flags: Array) -> void:
	completed.resize(TITLES.size())
	completed.fill(false)
	for i in range(mini(completed.size(), flags.size())):
		completed[i] = bool(flags[i])

func open_gallery() -> void:
	save_progress()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func run_tests() -> void:
	await get_tree().process_frame
	var failures: Array[String] = preload("res://scripts/positioning_tests.gd").run(self)
	failures.append_array(preload("res://scripts/complete_puzzle_tests.gd").run(self))
	failures.append_array(preload("res://scripts/overview_tests.gd").run(self))
	if failures.is_empty():
		print("POSITIONING SELF TEST PASS: physical links, positioning dependencies, sweep clearance, solutions, undo, cameras, no portals")
	else:
		for failure in failures:
			push_error("POSITIONING SELF TEST FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)
