extends Node3D
## One continuous courtyard, three rules, one distant destination.

const Piece = preload("res://scripts/surface_piece.gd")
const Walker = preload("res://scripts/surface_walker.gd")
const HUD = preload("res://scripts/hud.gd")
const CurvedTrack = preload("res://scripts/curved_track.gd")
const SAVE_VERSION := 4
const PASSAGE_OFFSET := Vector3(-18, -15, -24)
const CROSSING_Z := -11.0
const START_FOOT := Vector3(-1.8, 1, 0)
# Fixed in the walking surface's frame; preserves the existing landing view.
const OVERVIEW_LOCAL_OFFSET := Vector3(36, 48, -30)
var pieces: Array[SurfacePiece] = []
var arrival: SurfacePiece
var causeway: SurfacePiece
var carrier: SurfacePiece
var courtyard: SurfacePiece
var destination: SurfacePiece
var rounded_track: CurvedTrack
var track_open := false
var carrier_released := false
var local_controls: Array[Dictionary] = []
var carrier_brake: Node3D
var track_gate: MeshInstance3D
var arch: Node3D
var arch_state := 1
var passage_views: Array[Dictionary] = []
var gallery_solids: Array[MeshInstance3D] = []
var backdrop_visuals: Array[MeshInstance3D] = []
var overview_cutaways: Array[Dictionary] = []
var gallery_modules: Array[Node3D] = []
var hovered_gallery: Node3D
var pointer_in_viewport := true
var walker: SurfaceWalker
var overview: Camera3D
var hud: CanvasLayer
var architectural := true
var selected := 0
var busy := false
var paused := false
var won := false
var boarded := false
var reached_court := false
var crossed := false
var history: Array[Dictionary] = []
var checkpoint: Dictionary
var hint_level := 0
var hint_context := ""
var message := "Enter the world and inspect the brass control beside the folded walkway."
var message_time := 8.0
var rotation_tween: Tween
var camera_tween: Tween
var audio: AudioStreamPlayer
var passage_previous := 0.0
var time := 0.0
var transition_camera: Camera3D
var input_bindings := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "view": KEY_TAB, "interact": KEY_F, "rotate_left": KEY_Q, "rotate_right": KEY_E, "undo": KEY_Z, "reset": KEY_R, "hint": KEY_H}

func _ready() -> void:
	get_viewport().mouse_entered.connect(func(): pointer_in_viewport = true)
	get_viewport().mouse_exited.connect(func(): pointer_in_viewport = false)
	configure_input()
	build_world()
	walker = Walker.new()
	walker.name = "Walker"
	add_child(walker)
	walker.pieces = pieces
	walker.camera_obstacles = gallery_solids
	walker.place(arrival, START_FOOT, Vector3.UP, Vector3.RIGHT)
	walker.stepped.connect(func(): play_tone(130.0, 0.035, 0.05))
	walker.changed_surface.connect(surface_changed)
	overview = Camera3D.new()
	add_child(overview)
	overview.projection = Camera3D.PROJECTION_ORTHOGONAL
	overview.cull_mask = 15
	overview.size = 46.0
	update_overview_camera()
	overview.current = true
	transition_camera = Camera3D.new()
	transition_camera.fov = 76
	transition_camera.near = 0.07
	add_child(transition_camera)
	hud = HUD.new()
	hud.game = self
	add_child(hud)
	audio = AudioStreamPlayer.new()
	add_child(audio)
	select_piece(0)
	checkpoint = snapshot()
	load_progress()
	if "--self-test" in OS.get_cmdline_user_args():
		call_deferred("run_self_test")
	if "--capture" in OS.get_cmdline_user_args():
		call_deferred("capture_preview")

func configure_input() -> void:
	var settings := ConfigFile.new()
	if settings.load("user://settings.cfg") == OK:
		for action in input_bindings:
			var saved_key: int = settings.get_value("keys", action, input_bindings[action])
			if saved_key > 0:
				input_bindings[action] = saved_key
	for action in input_bindings:
		bind_key(action, input_bindings[action])

func bind_key(action: String, code: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var event := InputEventKey.new()
	event.physical_keycode = code as Key
	InputMap.action_add_event(action, event)
	input_bindings[action] = code

func key_name(action: String) -> String:
	return OS.get_keycode_string(input_bindings[action])

func build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("10182f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a5b8ef")
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("ffe5bf")
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(35, 125, 0)
	fill.light_color = Color("899adb")
	fill.light_energy = 0.25
	add_child(fill)
	arrival = make_piece("Arrival", Vector3(-13, 0, 0), Vector3(6, 2, 6), Color("647790"))
	causeway = make_piece("Causeway", Vector3(-8, 0, 0), Vector3(4, 2, 2), Color("8b8798"))
	carrier = make_piece("Carrier", Vector3.ZERO, Vector3(12, 2, 3), Color("a97166"), true)
	courtyard = make_piece("Courtyard", Vector3(10, 0, 0), Vector3(8, 2, 24), Color("777299"))
	courtyard.rotation.x = PI / 2
	destination = make_piece("Destination", courtyard.position + PASSAGE_OFFSET, Vector3(6, 2, 32), Color("719899"))
	destination.rotation.x = PI / 2
	# Build the load-bearing mass around the route, not two enormous flat cards.
	courtyard.set_solid_boxes([
		AABB(Vector3(-4, -1, -1.2), Vector3(8, 2, 2.5))
	])
	destination.set_solid_boxes([
		AABB(Vector3(-1.9, 0.7, -11), Vector3(3.8, 0.3, 10.2)),
		AABB(Vector3(-3, 0.7, -16), Vector3(6, 0.3, 5))
	])
	build_landing_detail(courtyard, false)
	build_landing_detail(destination, true)
	arrival.walk_regions = [Rect2(-2.8, -0.8, 5.8, 1.6), Rect2(-2.6, -3, 1.6, 3)]
	causeway.walk_regions = [Rect2(-2, -0.8, 4, 1.6)]
	carrier.walk_regions = [Rect2(-6, -0.8, 12, 1.6)]
	destination.walk_regions = [Rect2(-0.9, -15.5, 1.8, 14.5)]
	for piece in [arrival, causeway, carrier, destination]:
		piece.draw_paths()
	build_local_mechanisms()
	build_arch()
	update_connections()
	# The destination's shrine shares the landing's local gravity frame.
	var shrine := Node3D.new()
	destination.add_child(shrine)
	shrine.position = Vector3(0, 1, -14.6)
	build_beacon(shrine)
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.42
	sphere.height = 0.84
	orb.mesh = sphere
	orb.material_override = Piece.material(Color("ffdda0"), 1.2)
	shrine.add_child(orb)
	orb.position.y = 2.2
	var light := OmniLight3D.new()
	shrine.add_child(light)
	light.position.y = 2.2
	light.light_color = Color("ffca81")
	light.light_energy = 1.0
	light.omni_range = 8
	# Disconnected distant monuments establish scale without false traversal.
	var rng := RandomNumberGenerator.new()
	rng.seed = 431
	for i in range(32):
		var angle := float(i) / 32.0 * TAU
		var radius := rng.randf_range(45, 75)
		var height := rng.randf_range(6, 28)
		var pos := Vector3(cos(angle) * radius, -34 - height * 0.5, sin(angle) * radius - 8)
		backdrop_visuals.append(Piece.box(self, pos, Vector3(rng.randf_range(3, 7), height, rng.randf_range(3, 7)), Piece.material(Color("29374f"))))
		if i % 3 == 0:
			backdrop_visuals.append(Piece.box(self, pos + Vector3(0, height * 0.5, 0), Vector3(2.5, 0.06, 2.5), Piece.material(Color("a0b6c1"), 0.4)))
	for i in range(100):
		var at := Vector3(rng.randf_range(-90, 90), rng.randf_range(15, 65), rng.randf_range(-95, -40))
		Piece.box(self, at, Vector3.ONE * rng.randf_range(0.035, 0.12), Piece.material(Color("afbdd9"), 0.8))
	# Axle collars make the carrier's roll axis legible from either end.
	for side in [-1.0, 1.0]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.55
		torus.outer_radius = 0.67
		ring.mesh = torus
		ring.material_override = Piece.material(Color("c3aa86"), 0.2)
		carrier.add_child(ring)
		ring.position.x = side * 5.9
		ring.rotation.z = PI / 2

func update_connections() -> void:
	for piece in pieces:
		piece.neighbours.clear()
	if busy:
		return
	arrival.neighbours.append(causeway)
	causeway.neighbours.append(arrival)
	if track_open:
		arrival.neighbours.append(rounded_track)
		rounded_track.neighbours.append(arrival)
	if carrier.state == 0:
		causeway.neighbours.append(carrier)
		carrier.neighbours.append(causeway)
	elif carrier.state == 1:
		carrier.neighbours.append(courtyard)
		courtyard.neighbours.append(carrier)
	courtyard.walk_regions = [Rect2(-4, -0.8, 4.9, 1.6)]
	courtyard.walk_regions.append(Rect2(-0.9, CROSSING_Z if arch_state == 0 else -1.0, 1.8, 1.0 - CROSSING_Z if arch_state == 0 else 2.0))
	courtyard.draw_paths()

func update_overview_camera() -> void:
	var focus := Vector3(-1, -2, -7)
	var ground_up := (walker.support.global_basis * walker.normal).normalized()
	# Transport one authored camera frame with the ground. Do not select a new
	# side based on world-up or walking heading: either causes front/back swaps.
	var ground_frame := walker.support.global_basis * walker.support.surface_frame(walker.foot)
	overview.position = focus + ground_frame * OVERVIEW_LOCAL_OFFSET
	overview.look_at(focus, ground_up)
	update_architecture_cutaway()
	update_backdrop_visibility()

func build_local_mechanisms() -> void:
	rounded_track = CurvedTrack.new()
	rounded_track.name = "RoundedTrack"
	add_child(rounded_track)
	rounded_track.position = arrival.to_global(Vector3(-1.8, 1, -3))
	rounded_track.build()
	pieces.append(rounded_track)
	make_local_control("extend", arrival, Vector3(-2.82, 1, -1.6), Basis.IDENTITY)
	make_local_control("release", rounded_track, rounded_track.point_at(rounded_track.length() - 0.7, 0.87), Basis(Vector3.RIGHT, -PI))
	track_gate = Piece.box(arrival, Vector3(-1.8, 1.38, -2.86), Vector3(1.7, 0.12, 0.14), Piece.material(Color("bd9670")))
	gallery_solids.append(track_gate)
	# A visible brake ties the underside control to the architectural action.
	carrier_brake = Node3D.new()
	causeway.add_child(carrier_brake)
	carrier_brake.position = Vector3(1.75, 0, 0)
	for side in [-1.0, 1.0]:
		Piece.box(carrier_brake, Vector3(0, 0, side * 1.12), Vector3(0.6, 1.5, 0.22), Piece.material(Color("ba9767")))
		Piece.box(carrier_brake, Vector3(0.4, -0.65, side * 1.12), Vector3(1.1, 0.2, 0.22), Piece.material(Color("ba9767")))
	refresh_local_mechanisms()

func make_local_control(id: String, support: SurfacePiece, foot: Vector3, frame: Basis) -> void:
	var root := Node3D.new()
	support.add_child(root)
	root.transform = Transform3D(frame, foot)
	var base := Piece.box(root, Vector3(0, 0.42, 0), Vector3(0.28, 0.84, 0.32), Piece.material(Color("626f80")))
	gallery_solids.append(base)
	Piece.box(root, Vector3(0, 0.87, 0), Vector3(0.4, 0.09, 0.42), Piece.material(Color("bc9b71")))
	var lever := Node3D.new()
	root.add_child(lever)
	lever.position.y = 0.93
	lever.rotation.z = -0.45
	Piece.box(lever, Vector3(0, 0.16, 0), Vector3(0.07, 0.32, 0.07), Piece.material(Color("d3bea0")))
	var knob := Piece.box(lever, Vector3(0, 0.34, 0), Vector3(0.19, 0.12, 0.19), Piece.material(Color("ffda94"), 0.8))
	local_controls.append({"id": id, "support": support, "root": root, "lever": lever, "knob": knob})

func refresh_local_mechanisms() -> void:
	rounded_track.deployed = track_open
	rounded_track.set_deployment(1.0 if track_open else 0.0)
	track_gate.visible = not track_open
	carrier_brake.position.y = -1.15 if carrier_released else 0.0
	for control in local_controls:
		var used: bool = track_open if control.id == "extend" else carrier_released
		control.root.visible = control.id == "extend" or track_open
		control.lever.rotation.z = 0.55 if used else -0.45
		control.knob.material_override = Piece.material(Color("84bcb5") if used else Color("ffda94"), 0.5)

func available_interaction() -> String:
	if architectural or busy or paused or won:
		return ""
	for control in local_controls:
		if control.support != walker.support or not control.root.is_visible_in_tree():
			continue
		if (control.id == "extend" and track_open) or (control.id == "release" and carrier_released):
			continue
		var contact := walker.support.to_global(walker.foot)
		if contact.distance_to(control.root.global_position) <= 2.0 and (walker.support.global_basis * walker.normal).dot(control.root.global_basis.y) > 0.95:
			# Same ground, reachable distance and an unobstructed hand-height line.
			var hand := contact + walker.support.global_basis * walker.normal
			var target: Vector3 = control.root.to_global(Vector3(0, 1.0, 0))
			var clear := true
			for obstacle in gallery_solids:
				if not obstacle.is_visible_in_tree() or obstacle.get_parent() == control.root:
					continue
				var size: Vector3 = (obstacle.mesh as BoxMesh).size
				if AABB(-size * 0.5, size).intersects_segment(obstacle.to_local(hand), obstacle.to_local(target)):
					clear = false
			if clear:
				return control.id
	return ""

func interaction_text() -> String:
	match available_interaction():
		"extend": return key_name("interact") + "  Extend the rounded walkway"
		"release": return key_name("interact") + "  Release the carrier brake"
	return ""

func interact() -> void:
	var action := available_interaction()
	if action.is_empty():
		return
	history.append(snapshot())
	busy = true
	update_connections()
	play_tone(250, 0.3, 0.1)
	rotation_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var duration := 0.0 if walker.reduced_motion else 1.2
	if action == "extend":
		rotation_tween.tween_method(rounded_track.set_deployment, 0.0, 1.0, duration)
	else:
		rotation_tween.tween_property(carrier_brake, "position:y", -1.15, duration)
	rotation_tween.tween_callback(func():
		track_open = track_open or action == "extend"
		carrier_released = carrier_released or action == "release"
		busy = false
		refresh_local_mechanisms()
		update_connections()
		checkpoint = snapshot()
		save_progress()
		notify("Follow the curve. It carries your ground around the edge." if action == "extend" else "The carrier is released. Return along the curve, board it, then turn it from above.")
		play_tone(620, 0.2, 0.1)
	)

func update_backdrop_visibility() -> void:
	# Scenic monuments must remain behind the playable composition as its view
	# rotates, rather than becoming foreground walls or intersecting the camera.
	var view := overview.global_basis.z
	var rear_depth := INF
	for piece in pieces:
		var local_view := piece.global_basis.inverse() * view
		rear_depth = minf(rear_depth, view.dot(piece.global_position) - local_view.abs().dot(piece.half))
	for visual in backdrop_visuals:
		var half_size: Vector3 = (visual.mesh as BoxMesh).size * 0.5
		visual.visible = not architectural or view.dot(visual.global_position) + view.abs().dot(half_size) < rear_depth - 2.0

func update_architecture_cutaway() -> void:
	var revealed: Array[Node3D] = []
	if architectural:
		for gallery in gallery_modules:
			if gallery == hovered_gallery or gallery_contains_player(gallery):
				revealed.append(gallery)
		# In alignment the two galleries are one apparent module. Leaving the
		# duplicate roof visible would cover the very interior being revealed.
		if arch_state == 0 and not revealed.is_empty():
			revealed.assign(gallery_modules)
	for entry in overview_cutaways:
		var facing: Vector3 = entry.mesh.get_parent().global_basis * entry.normal
		var cut: bool = entry.mesh.get_parent() in revealed and (entry.normal == Vector3.ZERO or facing.dot(overview.global_basis.z) > 0)
		entry.mesh.layers = 16 if cut else 1
		entry.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if cut and architectural else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func gallery_contains_player(gallery: Node3D) -> bool:
	if walker.support != gallery.get_parent():
		return false
	var contact := gallery.to_local(walker.support.to_global(walker.foot))
	return AABB(Vector3(-1.2, -0.1, -5.15), Vector3(2.4, 0.4, 10.3)).has_point(contact)

func gallery_at_screen(screen: Vector2) -> Node3D:
	if not get_viewport().get_visible_rect().has_point(screen):
		return null
	var origin := overview.project_ray_origin(screen)
	var direction := overview.project_ray_normal(screen)
	var nearest := INF
	var found: Node3D
	# Stable bounds include the full roof even while it is cut away. Otherwise
	# hovering the roof would alternate between showing and hiding every frame.
	var bounds := AABB(Vector3(-1.95, -0.17, -5.5), Vector3(3.9, 4.97, 11))
	for gallery in gallery_modules:
		var hit: Variant = bounds.intersects_ray(gallery.to_local(origin), gallery.global_basis.inverse() * direction)
		if hit is Vector3:
			var distance := origin.distance_to(gallery.to_global(hit))
			if distance < nearest:
				nearest = distance
				found = gallery
	# A foreground support must not permit hovering through its visible mass.
	for piece in pieces:
		for solid in piece.solid_meshes:
			if not solid.is_visible_in_tree():
				continue
			var size: Vector3 = (solid.mesh as BoxMesh).size
			var hit: Variant = AABB(-size * 0.5, size).intersects_ray(solid.to_local(origin), solid.global_basis.inverse() * direction)
			if hit is Vector3 and origin.distance_to(solid.to_global(hit)) < nearest:
				return null
	return found

func update_gallery_hover() -> void:
	hovered_gallery = null
	if architectural and not paused and not won and not busy and pointer_in_viewport and get_viewport().gui_get_hovered_control() == null:
		hovered_gallery = gallery_at_screen(get_viewport().get_mouse_position())

func make_piece(label_text: String, at: Vector3, size: Vector3, color: Color, movable := false) -> SurfacePiece:
	var piece := Piece.new()
	piece.name = label_text
	add_child(piece)
	piece.position = at
	piece.setup(label_text, size, color, movable)
	pieces.append(piece)
	return piece

func arch_frame(parent: Node3D, color: Color, height := 4.0) -> void:
	var mat := Piece.material(color)
	for side in [-1.0, 1.0]:
		Piece.box(parent, Vector3(side * 1.65, height * 0.5, 0), Vector3(0.5, height, 0.65), mat)
		Piece.box(parent, Vector3(side * 1.36, height * 0.5, 0.34), Vector3(0.045, height - 0.2, 0.025), Piece.material(Color("ffe0a3"), 1.0))
	Piece.box(parent, Vector3(0, height, 0), Vector3(3.8, 0.5, 0.65), mat)

func build_arch() -> void:
	arch = build_gallery(courtyard)
	arch.name = "TurningGallery"
	arch.rotation.y = PI / 2
	var far_gallery := build_gallery(destination)
	far_gallery.name = "DistantGallery"
	build_passage_view(arch, PASSAGE_OFFSET)
	build_passage_view(far_gallery, -PASSAGE_OFFSET)

func build_landing_detail(piece: SurfacePiece, is_destination: bool) -> void:
	var stone := Piece.material(Color("aca4b0"))
	var shadow := Piece.material(Color("50526b"))
	# A single shallow edge keeps both halves at the same apparent floor level.
	var z_start := -16.0 if is_destination else -11.0
	var z_end := -11.0 if is_destination else -1.2
	var width := 6.0 if is_destination else 3.8
	if is_destination:
		Piece.box(piece, Vector3(0, 0.73, (z_start + z_end) * 0.5), Vector3(width, 0.06, z_end - z_start), shadow)
	if not is_destination:
		# The carrier enters a small inhabited landing instead of hitting a wall.
		for side in [-1.0, 1.0]:
			Piece.box(piece, Vector3(-2.4, 1.18, side * 1.12), Vector3(3.2, 0.32, 0.18), stone)
		Piece.box(piece, Vector3(-3.6, 1.04, 0), Vector3(0.12, 0.035, 1.65), Piece.material(Color("b9976b")))
	else:
		for side in [-1.0, 1.0]:
			Piece.box(piece, Vector3(side * 2.75, 1.2, -13.5), Vector3(0.18, 0.4, 5.0), stone)

func build_beacon(parent: Node3D) -> void:
	var stone := Piece.material(Color("bcb2a4"))
	# An open court exposes the destination and the approach to it from above.
	Piece.box(parent, Vector3(0, 0.04, 0), Vector3(1.9, 0.08, 1.9), stone)
	gallery_solids.append(Piece.box(parent, Vector3(0, 0.8, 0), Vector3(0.65, 1.5, 0.65), stone))
	Piece.box(parent, Vector3(0, 1.61, 0), Vector3(0.95, 0.12, 0.95), stone)

func build_gallery(parent: Node3D) -> Node3D:
	var gallery := Node3D.new()
	parent.add_child(gallery)
	gallery_modules.append(gallery)
	gallery.position = Vector3(0, 1, -6)
	var stone := Piece.material(Color("aaa3b0"))
	var moulding := Piece.material(Color("c4bbae"))
	var dark := Piece.material(Color("53566e"))
	var warm := Piece.material(Color("dcc39a"), 0.15)
	for side in [-1.0, 1.0]:
		gallery_solids.append(Piece.box(gallery, Vector3(side * 1.4, 1.9, 0), Vector3(0.35, 3.8, 10.2), stone))
		Piece.box(gallery, Vector3(side * 1.215, 0.48, 0), Vector3(0.025, 0.055, 10.15), warm)
		# Pilasters and recessed panels give the corridor a readable structural rhythm.
		for z in [-5.0, -2.5, 0.0, 2.5, 5.0]:
			Piece.box(gallery, Vector3(side * 1.62, 1.9, z), Vector3(0.25, 3.8, 0.24), moulding)
		for z in [-3.75, -1.25, 1.25, 3.75]:
			Piece.box(gallery, Vector3(side * 1.584, 2.15, z), Vector3(0.022, 1.45, 1.55), dark)
	# Deep reveals and a cap frame both ends as passages through masonry.
	for z in [-5.15, 5.15]:
		for side in [-1.0, 1.0]:
			gallery_solids.append(Piece.box(gallery, Vector3(side * 1.5, 1.85, z), Vector3(0.55, 3.7, 0.65), moulding))
		gallery_solids.append(Piece.box(gallery, Vector3(0, 3.72, z), Vector3(3.55, 0.25, 0.65), moulding))
	gallery_solids.append(Piece.box(gallery, Vector3(0, 3.92, 0), Vector3(3.6, 0.24, 10.65), stone))
	# Shallow pitched coping replaces the silhouette of an open square tube.
	for side in [-1.0, 1.0]:
		var roof := Piece.box(gallery, Vector3(side * 0.9, 4.36, 0), Vector3(1.92, 0.16, 10.65), moulding)
		roof.rotation.z = -side * atan2(0.64, 1.8)
		gallery_solids.append(roof)
	for z in [-5.3, 5.3]:
		var pediment := MeshInstance3D.new()
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var vertices := [Vector3(-1.8, 4.02, z), Vector3(1.8, 4.02, z), Vector3(0, 4.72, z)]
		if z > 0:
			vertices.reverse()
		for vertex in vertices:
			surface.add_vertex(vertex)
		surface.generate_normals()
		pediment.mesh = surface.commit()
		pediment.material_override = stone
		gallery.add_child(pediment)
	# The structural floor belongs to the same pivot as its enclosure. A second
	# fixed neck beneath it made a turned gallery look like a misplaced cover.
	var floor_slab := Piece.box(gallery, Vector3(0, -0.08, 0), Vector3(3.8, 0.18, 10.65), dark)
	gallery_solids.append(floor_slab)
	Piece.box(gallery, Vector3(0, 0.015, 0), Vector3(1.8, 0.02, 10.2), Piece.material(Color("d8c8ac")))
	for z in [-4.8, -2.4, 0.0, 2.4, 4.8]:
		Piece.box(gallery, Vector3(0, 3.72, z), Vector3(2.45, 0.10, 0.10), warm)
	for part in gallery.get_children():
		if not part is MeshInstance3D:
			continue
		if part.mesh is ArrayMesh or part.position.y > 3.5:
			overview_cutaways.append({"mesh": part, "normal": Vector3.ZERO})
		elif absf(part.position.x) > 1.2:
			overview_cutaways.append({"mesh": part, "normal": Vector3(signf(part.position.x), 0, 0)})
	return gallery

func build_passage_view(gallery: Node3D, offset: Vector3) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1280, 800)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	view.world_3d = get_world_3d()
	var camera := Camera3D.new()
	camera.cull_mask = 17
	view.add_child(camera)
	camera.current = true
	var seam := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.45, 3.8)
	seam.mesh = quad
	seam.layers = 2
	seam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if offset != PASSAGE_OFFSET:
		seam.rotation.y = PI
	gallery.add_child(seam)
	seam.position = Vector3(0, 1.9, -5.0)
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, cull_back; uniform sampler2D view_texture : source_color, filter_linear; void fragment(){ ALBEDO = texture(view_texture, SCREEN_UV).rgb; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("view_texture", view.get_texture())
	seam.material_override = material
	passage_views.append({"mesh": seam, "view": view, "camera": camera, "offset": offset})

func update_passage_views() -> void:
	for entry in passage_views:
		entry.mesh.visible = arch_state == 0 and not busy and not architectural
		entry.view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if entry.mesh.visible else SubViewport.UPDATE_DISABLED
		if not entry.mesh.visible:
			continue
		var active_camera := walker.camera
		entry.camera.global_transform = active_camera.global_transform
		entry.camera.global_position += entry.offset
		entry.camera.projection = active_camera.projection
		entry.camera.fov = active_camera.fov
		entry.camera.near = 0.07
		entry.view.size = Vector2i(get_viewport().get_visible_rect().size)

func _process(delta: float) -> void:
	time += delta
	message_time = maxf(0, message_time - delta)
	if walker == null:
		return
	if not architectural and not busy and not paused and not won:
		var movement := Input.get_vector("left", "right", "forward", "back")
		walker.align_movement_to_camera(movement)
		walker.walk(movement, minf(delta, 0.1))
		check_passage()
		if walker.support == destination and walker.foot.z < -14.0 and walker.normal.y > 0.9:
			complete()
	walker.sync_pose(delta)
	walker.avatar.visible = architectural or walker.third_person
	update_gallery_hover()
	update_overview_camera()
	walker.update_overview_visibility(overview, architectural)
	update_passage_views()
	hud.refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		set_pause(not paused)
		return
	if paused or won:
		return
	if event.is_action_pressed("view") and not busy:
		toggle_view()
	elif event.is_action_pressed("undo"):
		undo()
	elif event.is_action_pressed("reset"):
		restart_checkpoint()
	elif event.is_action_pressed("hint"):
		show_hint()
	elif event.is_action_pressed("interact"):
		interact()
	elif architectural and not busy:
		if event.is_action_pressed("rotate_left"):
			rotate_selected(-1)
		elif event.is_action_pressed("rotate_right"):
			rotate_selected(1)
		elif event is InputEventKey and event.pressed and event.keycode == KEY_1:
			select_piece(0)
		elif event is InputEventKey and event.pressed and event.keycode == KEY_2:
			select_piece(1)
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pick(event.position)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		walker.look(event.relative)

func toggle_view() -> void:
	var from := overview.global_transform if architectural else walker.camera.global_transform
	architectural = not architectural
	hovered_gallery = null
	walker.moving = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if architectural else Input.MOUSE_MODE_CAPTURED
	walker.avatar.visible = architectural or walker.third_person
	if architectural:
		update_overview_camera()
		overview.current = true
	else:
		walker.sync_pose(1.0)
		walker.camera.current = true
		passage_previous = walker.foot.z
	if not walker.reduced_motion and not walker.third_person:
		busy = true
		transition_camera.global_transform = from
		transition_camera.current = true
		var target := overview.global_transform if architectural else walker.camera.global_transform
		camera_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		camera_tween.tween_method(func(weight: float): transition_camera.global_transform = from.interpolate_with(target, weight), 0.0, 1.0, 0.45)
		camera_tween.tween_callback(func():
			busy = false
			if architectural:
				overview.current = true
			else:
				walker.camera.current = true
		)
	play_tone(420, 0.1, 0.08)

func pick(screen: Vector2) -> void:
	var arch_screen := overview.unproject_position(arch.to_global(Vector3(0, 2, 0)))
	if arch_screen.distance_to(screen) < 75:
		select_piece(1)
		return
	var from := overview.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(from, from + overview.project_ray_normal(screen) * 200)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_meta("piece") and hit.collider.get_meta("piece") == carrier:
		select_piece(0)

func select_piece(index: int) -> void:
	selected = index
	carrier.highlight(index == 0)

func rotate_selected(direction: int) -> void:
	if busy or paused or not architectural:
		return
	if selected == 0 and not carrier_released:
		notify("The carrier brake is engaged. Follow the rounded walkway to its release control.")
		return
	if selected == 1 and walker.support == courtyard and walker.foot.distance_to(Vector3(0, 1, -6)) < 6.6:
		notify("Step back onto the landing before turning the gallery.")
		return
	if selected == 0 and not safe_carrier_turn(direction):
		notify("Move farther onto the deck before turning it.")
		return
	history.append(snapshot())
	busy = true
	update_connections()
	var target: Node3D = carrier if selected == 0 else arch
	var axis := "rotation:x" if selected == 0 else "rotation:y"
	var start := target.rotation.x if selected == 0 else target.rotation.y
	if selected == 0:
		carrier.state = posmod(carrier.state + direction, 4)
	else:
		arch_state = posmod(arch_state + direction, 4)
	play_tone(175, 0.45, 0.12)
	rotation_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	rotation_tween.tween_property(target, axis, start + direction * PI * 0.5, 0.0 if walker.reduced_motion else 0.8)
	if not walker.reduced_motion:
		rotation_tween.parallel().tween_method(func(_weight: float): update_overview_camera(), 0.0, 1.0, 0.8)
	rotation_tween.tween_callback(func():
		busy = false
		update_overview_camera()
		update_connections()
		play_tone(620, 0.2, 0.1)
		notify("The galleries form one passage." if selected == 1 and arch_state == 0 else "The structure settles. Inspect the path before walking.")
	)

func safe_carrier_turn(direction: int) -> bool:
	# Check the attached body through the complete sweep, including side faces.
	for step in range(1, 25):
		var basis_at := Basis(Vector3.RIGHT, carrier.rotation.x + direction * PI * 0.5 * float(step) / 24.0)
		for height in [0.25, 0.8, 1.55]:
			if walker.support != carrier:
				var stationary_point: Vector3 = walker.support.to_global(walker.foot + walker.normal * height)
				var in_carrier := basis_at.inverse() * (stationary_point - carrier.global_position)
				if absf(in_carrier.x) < carrier.half.x + 0.16 and absf(in_carrier.y) < carrier.half.y + 0.16 and absf(in_carrier.z) < carrier.half.z + 0.16:
					return false
				continue
			var point: Vector3 = carrier.global_position + basis_at * (walker.foot + walker.normal * height)
			for other in [arrival, causeway, courtyard, destination]:
				var local: Vector3 = other.to_local(point)
				if other.contains_solid(local, 0.16):
					return false
	return true

func check_passage() -> void:
	if arch_state != 0 or busy or walker.normal != Vector3.UP:
		passage_previous = walker.foot.z
		return
	var forward_crossing := walker.support == courtyard and passage_previous > CROSSING_Z and walker.foot.z <= CROSSING_Z
	var backward_crossing := walker.support == destination and passage_previous < CROSSING_Z and walker.foot.z >= CROSSING_Z
	if (forward_crossing or backward_crossing) and absf(walker.foot.x) <= 0.9:
		var target := destination if forward_crossing else courtyard
		var point := walker.foot
		point.z += -0.02 if forward_crossing else 0.02
		# Parallel gallery frames: contact, orbit and camera translate together.
		walker.place(target, point, Vector3.UP, walker.forward, true)
		if forward_crossing and not crossed:
			crossed = true
			checkpoint = snapshot()
			save_progress()
		# No flash, transition sound or teleport announcement at the hidden seam.
	passage_previous = walker.foot.z

func surface_changed() -> void:
	if walker.support == carrier and not boarded:
		boarded = true
		hint_level = 0
		checkpoint = snapshot()
		save_progress()
		notify("Aboard. Your position is part of the arrangement.")
	if walker.support == courtyard and not reached_court:
		reached_court = true
		hint_level = 0
		checkpoint = snapshot()
		save_progress()
		notify("A new landing. The gallery must meet its distant counterpart.")

func snapshot() -> Dictionary:
	return {"version": SAVE_VERSION, "carrier": carrier.state, "arch": arch_state, "player": walker.snapshot(), "boarded": boarded, "court": reached_court, "crossed": crossed, "track_open": track_open, "carrier_released": carrier_released}

func restore(data: Dictionary) -> void:
	hovered_gallery = null
	if rotation_tween and rotation_tween.is_running():
		rotation_tween.kill()
	if camera_tween and camera_tween.is_valid():
		camera_tween.kill()
	busy = false
	carrier.state = data.carrier
	carrier.rotation.x = carrier.state * PI * 0.5
	arch_state = data.arch
	arch.rotation.y = arch_state * PI * 0.5
	# Existing authored-path progress remains usable after the new opening.
	var prior_progress: bool = data.boarded or data.court or data.crossed or int(data.carrier) != 0
	track_open = data.get("track_open", prior_progress)
	carrier_released = data.get("carrier_released", prior_progress)
	refresh_local_mechanisms()
	update_connections()
	walker.restore(data.player, self)
	boarded = data.boarded
	reached_court = data.court
	crossed = data.crossed
	hint_level = 0
	won = false
	hud.completion.hide()
	if architectural:
		update_overview_camera()
		overview.current = true
	else:
		walker.camera.current = true
	passage_previous = walker.foot.z

func undo() -> void:
	if history.is_empty() or busy:
		notify("No settled transformation to undo.")
		return
	restore(history.pop_back())
	notify("Restored the structure and your place on it.")

func restart_checkpoint() -> void:
	if busy:
		return
	restore(checkpoint)
	history.clear()
	notify("Back at your last safe arrival.")

func new_journey() -> void:
	hovered_gallery = null
	if rotation_tween:
		rotation_tween.kill()
	if camera_tween and camera_tween.is_valid():
		camera_tween.kill()
	busy = false
	select_piece(0)
	carrier.state = 0
	carrier.rotation.x = 0
	arch_state = 1
	arch.rotation.y = PI / 2
	track_open = false
	carrier_released = false
	refresh_local_mechanisms()
	update_connections()
	boarded = false
	reached_court = false
	crossed = false
	won = false
	hud.completion.hide()
	hint_level = 0
	history.clear()
	walker.orbit_yaw = 0.0
	walker.orbit_pitch = 0.42
	walker.place(arrival, START_FOOT, Vector3.UP, Vector3.RIGHT)
	update_overview_camera()
	checkpoint = snapshot()
	save_progress()
	set_pause(false)
	if not architectural:
		toggle_view()
	else:
		overview.current = true
		walker.avatar.visible = true
	notify("Enter the world and inspect the brass control beside the folded walkway.")

func save_progress() -> void:
	if busy or "--self-test" in OS.get_cmdline_user_args():
		return
	var file := FileAccess.open("user://journey.save", FileAccess.WRITE)
	if file:
		file.store_var(checkpoint)

func load_progress() -> void:
	if "--self-test" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args():
		return
	if FileAccess.file_exists("user://journey.save"):
		var file := FileAccess.open("user://journey.save", FileAccess.READ)
		var data = file.get_var()
		if data is Dictionary and data.get("version", 0) not in [3, SAVE_VERSION]:
			notify("Revised paths: the earlier free-walking checkpoint is preserved; this journey starts at the new entrance.")
			return
		if data is Dictionary and data.has_all(["player", "carrier", "arch", "boarded", "court", "crossed"]):
			if data.player is Dictionary and str(data.player.get("piece", "")) in ["Arrival", "Causeway", "Carrier", "Courtyard", "Destination", "RoundedTrack"]:
				checkpoint = data
				restore(data)

func set_pause(value: bool) -> void:
	paused = value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused or architectural or won else Input.MOUSE_MODE_CAPTURED
	if rotation_tween and rotation_tween.is_valid():
		if paused:
			rotation_tween.pause()
		else:
			rotation_tween.play()
	if camera_tween and camera_tween.is_valid():
		if paused:
			camera_tween.pause()
		else:
			camera_tween.play()
	hud.show_menu(value)

func notify(text: String) -> void:
	message = text
	message_time = 7.0

func carrier_connection_text() -> String:
	if busy:
		return "Connections settle after the turn."
	if not carrier_released:
		return "BRAKE ENGAGED\nRelease it from the underside control."
	var connection: String = ["Entrance joined / landing apart", "Landing joined / entrance apart", "Both paths apart", "Both paths apart"][carrier.state]
	return connection + ("\nYou are aboard." if walker.support == carrier else "\nYou are off the carrier.")

func guidance() -> Dictionary:
	var view := key_name("view")
	var turn := key_name("rotate_left") + " / " + key_name("rotate_right")
	if busy:
		return {"id": "settling", "title": "Your ground travels with you", "text": "Wait for the structure to settle before walking."}
	if not track_open:
		return {"id": "extend", "title": "A path waiting to unfold", "text": (view + "  Enter the world.\n" if architectural else "") + "Approach the brass control on the entrance platform.\n" + key_name("interact") + "  Extend the walkway."}
	if not carrier_released:
		return {"id": "release", "title": "Follow the rounded edge", "text": "The ivory ribbon continues beneath the entrance. Walk around its curve to the second control.\n" + key_name("interact") + "  Release the carrier."}
	if walker.support == rounded_track:
		return {"id": "return_curve", "title": "Bring the change back above", "text": "Retrace the curved walkway to the entrance. Board the terracotta carrier, then use " + view + " to turn it."}
	if walker.support == destination:
		return {"id": "light", "title": "Follow the light", "text": "Follow the ivory path out of the gallery to the light."}
	if walker.support == courtyard:
		if arch_state == 0:
			return {"id": "passage", "title": "The galleries meet", "text": (view + "  Enter the world.\n" if architectural else "") + "Follow the ivory path into the covered gallery."}
		if walker.foot.distance_to(Vector3(0, 1, -6)) < 6.6:
			return {"id": "gallery_clear", "title": "Return to the landing", "text": "Step back toward the carrier to give the gallery room to turn."}
		return {"id": "gallery", "title": "Join the two galleries", "text": "2  Select the gallery.\n" + turn + "  Align its corridor." if architectural else view + "  Inspect the two galleries from outside."}
	if walker.support == carrier:
		if carrier.state == 1:
			return {"id": "disembark", "title": "The wall is now your landing", "text": (view + "  Enter the world.\n" if architectural else "") + "Continue along the deck onto the violet path."}
		return {"id": "passenger", "title": "Carry the path into place", "text": "1  Select the carrier.\n" + turn + "  Join the vertical landing." if architectural else view + "  Turn the deck while standing aboard."}
	if carrier.state != 0:
		return {"id": "recall", "title": "Bring the deck back", "text": "1  Select the carrier.\n" + turn + "  Rejoin the entrance." if architectural else view + "  Turn the deck back to meet the entrance path."}
	return {"id": "board", "title": "Walk the ivory path", "text": view + "  Enter the world.\nBoard the terracotta deck before turning it." if architectural else "Edges end the path. Walk onto the terracotta deck; the structure will carry you onto the next surface."}

func show_hint() -> void:
	var context: String = guidance().id
	if context != hint_context:
		hint_level = 0
		hint_context = context
	var hints: Array[String]
	match context:
		"extend":
			hints = ["Some changes need a traveller's hands.", "The brass control is beside the short branch on the entrance platform.", "Use " + key_name("view") + " to enter the world, approach the control, then press " + key_name("interact") + "."]
		"release":
			hints = ["This path has a rounded edge instead of an abrupt end.", "Keep walking along the ribbon. Your ground follows its curve.", "Follow the ribbon onto the underside, then press " + key_name("interact") + " near the second brass control. This releases the carrier for architectural rotation."]
		"return_curve":
			hints = ["The change remains when you leave the control.", "The same curved path returns to the entrance.", "Walk back around the curve, board the terracotta deck, then switch to architectural view and turn it toward the violet landing."]
		"board":
			hints = ["The ivory paving marks where you can walk.", "The deck joins the entrance now, but not the vertical landing.", "Walk along the entrance path onto the middle of the terracotta deck, then open architectural view with " + key_name("view") + "."]
		"recall":
			hints = ["The entrance and deck must share the same ground.", "You can recall the deck from architectural view.", "Select 1 and turn until the panel says Entrance joined, then board before turning again."]
		"passenger":
			hints = ["You must travel with the path.", "Rotating the deck changes your ground while your feet stay on it.", "In architectural view, select 1 and turn until the vertical landing is joined. From the initial state, one " + key_name("rotate_right") + " turn does it."]
		"disembark":
			hints = ["The violet path is your new neighbour.", "Keep following the deck toward the violet landing.", "Return to traversal and walk off the end opposite the entrance. Stay on the ivory paving."]
		"gallery", "gallery_clear":
			hints = ["The two galleries can become one corridor.", "Use architectural view to compare the corridor directions. Hover a gallery to inspect inside.", "Stand on the landing near the carrier. In architectural view select 2, then turn until ALIGNED. Walk along the ivory path into the gallery."]
		"passage":
			hints = ["The route continues through the architecture.", "The covered gallery is now part of the ivory path.", "Follow the path into and through the gallery. The light is beyond its far end."]
		"light":
			hints = ["The light is ahead.", "Stay on the ivory paving beyond the gallery.", "Walk out of the far end of the corridor and approach the light."]
		_:
			hints = ["Let the structure settle before walking."]
	notify(hints[mini(hint_level, hints.size() - 1)])
	hint_level += 1

func complete() -> void:
	won = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_completion()
	play_tone(880, 0.8, 0.13)

func play_tone(frequency: float, duration: float, volume: float) -> void:
	if audio == null or DisplayServer.get_name() == "headless":
		return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var data := PackedByteArray()
	var count := int(duration * 22050)
	data.resize(count * 2)
	for i in range(count):
		var phase := float(i) / 22050.0
		var envelope := sin(PI * float(i) / count) * exp(-phase * 4)
		var sample := sin(TAU * frequency * phase) + 0.25 * sin(TAU * frequency * 1.5 * phase)
		data.encode_s16(i * 2, int(sample * envelope * volume * 16000))
	stream.data = data
	audio.stream = stream
	audio.play()

func capture_preview() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/prototype-preview.png")
	get_tree().quit()

func test_walk(frames: int, direction := Vector2(0, -1)) -> void:
	for frame in range(frames):
		walker.walk(direction, 1.0 / 60.0)
		walker.sync_pose(1.0 / 60.0)
		check_passage()

func run_self_test() -> void:
	await get_tree().process_frame
	var failures: Array[String] = []
	test_local_mechanisms(failures)
	new_journey()
	walker.set_third_person(true)
	walker.keep_world_horizon = false
	if courtyard.contains_solid(Vector3(3, 0, 8)) or not courtyard.contains_solid(Vector3(-3, 0, 0)) or courtyard.contains_solid(Vector3(0, 0.85, -6)):
		failures.append("The fixed landing must not leave a duplicate floor beneath the turning gallery")
	walker.update_overview_visibility(overview, true)
	if walker.overview_silhouette.visible:
		failures.append("An unobstructed arrival must not need an occlusion silhouette")
	# No wall, underside or corner can be entered by walking over a normal edge.
	for up in [Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		if arrival.allows_point(up * arrival.half, up):
			failures.append("Only authored walking faces may accept contact")
	for direction in [Vector3.LEFT, Vector3.FORWARD, Vector3.BACK, Vector3(-1, 0, 1).normalized()]:
		walker.place(arrival, START_FOOT, Vector3.UP, direction)
		test_walk(300)
		if walker.support != arrival or walker.normal != Vector3.UP or not arrival.allows_point(walker.foot, walker.normal):
			failures.append("An ordinary edge must stop movement without changing face")
	# Turning the empty carrier first leaves a genuine break in the authored route.
	track_open = true
	carrier_released = true
	refresh_local_mechanisms()
	carrier.state = 1
	carrier.rotation.x = PI / 2
	update_connections()
	walker.place(causeway, Vector3(1.9, 1, 0), Vector3.UP, Vector3.RIGHT)
	test_walk(90)
	if walker.support != causeway or walker.foot.x > 2.001 or guidance().id != "recall":
		failures.append("A disconnected carrier must not be boardable")
	new_journey()
	track_open = true
	carrier_released = true
	refresh_local_mechanisms()
	update_connections()
	test_walk(254)
	if walker.support != carrier or not boarded or str(checkpoint.player.piece) != "Carrier":
		failures.append("Entrance path must lead onto the carrier and save boarding")
	var before_turn := snapshot()
	var composed_direction := overview.global_basis.z
	var local_camera_frame := walker.support.global_basis.inverse() * overview.global_basis
	var old_up := walker.avatar.global_basis.y
	select_piece(0)
	rotate_selected(1)
	if not busy or not carrier.neighbours.is_empty() or guidance().id != "settling":
		failures.append("Intermediate rotation must disable walking connections")
	rotation_tween.custom_step(1.0)
	walker.sync_pose(1)
	if busy or carrier.state != 1 or walker.snapshot() != before_turn.player or old_up.dot(walker.avatar.global_basis.y) > 0.01:
		failures.append("Occupied roll must transport local pose onto a new gravity plane")
	# The full camera frame, including front/back azimuth, stays fixed relative
	# to the occupied surface through an entire revolution.
	for frame in range(121):
		carrier.rotation.x = TAU * float(frame) / 120.0
		update_overview_camera()
		var ground_up := carrier.global_basis * walker.normal
		if not (carrier.global_basis.inverse() * overview.global_basis).is_equal_approx(local_camera_frame) or overview.global_basis.z.dot(ground_up) < 0.7:
			failures.append("Overview must retain its surface-local azimuth and elevation")
	carrier.rotation.x = PI / 2
	update_overview_camera()
	# Sample actual occupied tweens in both directions through every orientation.
	for turn in [1, -1]:
		for orientation in range(4):
			carrier.state = orientation
			carrier.rotation.x = orientation * PI / 2
			walker.place(carrier, Vector3(0, 1, 0), Vector3.UP, Vector3.RIGHT)
			update_overview_camera()
			rotate_selected(turn)
			for sample in range(81):
				rotation_tween.custom_step(0.01)
				walker.sync_pose(1)
				var up := carrier.global_basis.y
				if overview.global_basis.z.dot(up) < 0.7 or not overview.global_transform.is_finite() or not (carrier.global_basis.inverse() * overview.global_basis).is_equal_approx(local_camera_frame):
					failures.append("Animated overview must retain the same upper-side viewing angle")
					break
			if not (carrier.global_basis.inverse() * overview.global_basis).is_equal_approx(local_camera_frame):
				failures.append("Settling must not introduce a camera side swap")
	restore(before_turn)
	rotate_selected(1)
	rotation_tween.custom_step(1)
	# Frame and clearance across roll orientations at all supported distances.
	for distance in [3.0, 5.5, 8.0]:
		for instant in [false, true]:
			walker.camera_distance = distance
			walker.reduced_motion = instant
			for frame in range(120):
				carrier.rotation.x = float(frame) / 119.0 * TAU
				walker.sync_pose(1.0 / 60.0)
				if not follow_view_is_clear():
					failures.append("Camera must frame a rolling passenger at distance %s" % distance)
					break
	walker.camera_distance = 5.5
	walker.reduced_motion = false
	carrier.rotation.x = PI / 2
	walker.sync_pose(1)
	test_walk(115)
	if walker.support != courtyard or not reached_court or walker.normal != Vector3.UP:
		failures.append("Rolled deck must meet the authored vertical landing")
	# Undo must restore the passenger even after disembarking.
	undo()
	if snapshot() != before_turn:
		failures.append("Undo must restore both geometry and passenger pose")
	walker.reduced_motion = true
	var reduced_frame := overview.global_basis
	rotate_selected(1)
	if not overview.global_basis.is_equal_approx(reduced_frame):
		failures.append("Reduced motion must retain the old frame until the atomic turn")
	rotation_tween.custom_step(1.0)
	if overview.global_basis.y.dot(carrier.global_basis.y) <= 0 or overview.global_basis.is_equal_approx(reduced_frame):
		failures.append("Reduced motion must cut to the settled ground frame")
	undo()
	walker.reduced_motion = false
	rotate_selected(1)
	rotation_tween.custom_step(1.0)
	walker.sync_pose(1)
	test_walk(115)
	var landing_snapshot := snapshot()
	if guidance().id != "gallery":
		failures.append("Landing should introduce gallery alignment")
	# The unaligned corridor is physically closed to the authored walking graph.
	walker.place(courtyard, Vector3(0, 1, 0), Vector3.UP, Vector3.FORWARD)
	test_walk(260)
	if walker.support != courtyard or walker.foot.z < -1.001 or crossed:
		failures.append("An unaligned gallery must not admit a crossing")
	select_piece(1)
	rotate_selected(-1)
	if busy:
		failures.append("A player in the gallery sweep must block its rotation")
	restore(landing_snapshot)
	select_piece(1)
	rotate_selected(-1)
	if not busy:
		failures.append("The safe landing must allow the gallery to turn")
	else:
		rotation_tween.custom_step(1.0)
	if arch_state != 0 or busy:
		failures.append("Gallery should settle aligned")
	test_contextual_cutaway(failures)
	# The authored pair really overlaps in the composed architectural projection.
	update_overview_camera()
	var near_end := courtyard.to_global(Vector3(0, 1, CROSSING_Z))
	var far_end := destination.to_global(Vector3(0, 1, CROSSING_Z))
	if overview.unproject_position(near_end).distance_to(overview.unproject_position(far_end)) > 0.02:
		failures.append("Composed view must align the actual corridor endpoints")
	var before_heading_change := overview.global_transform
	walker.forward = -walker.forward
	update_overview_camera()
	if not overview.global_transform.is_equal_approx(before_heading_change):
		failures.append("Reversing walking direction must not swing the overview around")
	walker.forward = -walker.forward
	var before_view := snapshot()
	var off_support_frame := overview.global_basis
	carrier.rotation.x += PI / 2
	update_overview_camera()
	if not overview.global_basis.is_equal_approx(off_support_frame):
		failures.append("Turning an unoccupied structure must leave overview orientation alone")
	carrier.rotation.x -= PI / 2
	toggle_view()
	toggle_view()
	if snapshot() != before_view:
		failures.append("Switching architectural and traversal views must not change connectivity")
	# Walk the gallery. Compare frames immediately across the concealed seam.
	walker.place(courtyard, Vector3(0, 1, -6), Vector3.UP, Vector3.FORWARD)
	update_overview_camera()
	walker.update_overview_visibility(overview, true)
	if walker.overview_silhouette.visible:
		failures.append("Gallery cutaway must expose the traveller without a silhouette")
	if not walker.camera.cull_mask & 16 or not passage_views[0].camera.cull_mask & 16 or overview.cull_mask & 16:
		failures.append("Cutaway must be restricted to the architectural camera")
	if courtyard.contains_solid(Vector3(0, 0.85, -11.5)) or not destination.contains_solid(Vector3(0, 0.85, -11.5)):
		failures.append("Source floor must end at the seam and destination must continue it")
	walker.update_overview_visibility(overview, false)
	if walker.overview_silhouette.visible or walker.camera.cull_mask & 8:
		failures.append("Occlusion silhouette must be restricted to overview")
	walker.place(courtyard, Vector3(0, 1, -10.95), Vector3.UP, Vector3.FORWARD)
	walker.pitch = 0.24
	walker.orbit_yaw = 0.12
	walker.sync_pose(1)
	var camera_before := walker.camera.global_transform
	passage_previous = walker.foot.z
	walker.advance(courtyard.global_basis * Vector3.FORWARD, 0.1)
	check_passage()
	walker.sync_pose(1)
	if walker.support != destination or not crossed or absf(walker.pitch - 0.24) > 0.001:
		failures.append("Crossing must preserve local position, gravity and look")
	if passage_views[1].mesh.to_local(walker.camera.global_position).z >= 0:
		failures.append("The return seam must face away from the trailing arrival camera")
	if not walker.camera.global_basis.is_equal_approx(camera_before.basis) or walker.camera.global_position.distance_to(camera_before.origin + PASSAGE_OFFSET) > 0.13:
		failures.append("Hidden seam must translate the camera with the player")
	walker.advance(destination.global_basis * Vector3.BACK, 0.15)
	check_passage()
	if walker.support != courtyard:
		failures.append("The joined gallery must support walking back through it")
	walker.advance(courtyard.global_basis * Vector3.FORWARD, 0.2)
	check_passage()
	test_walk(60)
	if walker.support != destination or walker.foot.z >= -14:
		failures.append("The continuous gallery route must reach the light")
	var recovered := snapshot()
	walker.place(arrival, START_FOOT, Vector3.UP, Vector3.RIGHT)
	restore(recovered)
	if snapshot() != recovered or not destination.allows_point(walker.foot, walker.normal):
		failures.append("Checkpoint restoration must retain an authored contact")
	var mode_snapshot := snapshot()
	walker.set_third_person(false)
	if walker.camera.cull_mask & 4:
		failures.append("First person must hide its own avatar")
	walker.set_third_person(true)
	if snapshot() != mode_snapshot:
		failures.append("Camera preference must not mutate puzzle state")
	# First-person crossing uses the same adjacency and preserves intentional look.
	walker.set_third_person(false)
	walker.place(courtyard, Vector3(0, 1, -10.95), Vector3.UP, Vector3.FORWARD)
	walker.pitch = 0.31
	walker.sync_pose(1)
	passage_previous = walker.foot.z
	walker.advance(courtyard.global_basis * Vector3.FORWARD, 0.1)
	check_passage()
	if walker.support != destination or absf(walker.pitch - 0.31) > 0.001:
		failures.append("First-person passage must preserve the player's look")
	walker.set_third_person(true)
	new_journey()
	if not overview.global_basis.y.is_equal_approx(Vector3.UP.slide(composed_direction).normalized()):
		failures.append("New journey must restore the entrance camera frame")
	if failures.is_empty():
		print("SELF TEST PASS: local interactions, rounded track, underside return, mechanism recovery, authored boundaries, occupied gravity roll, ground-relative overview, architectural cutaway, camera matrix, landing, undo, safe gallery rotation, composed alignment, two-way concealed crossing, recovery, camera modes")
	else:
		for failure in failures:
			push_error("SELF TEST FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func test_local_mechanisms(failures: Array[String]) -> void:
	new_journey()
	walker.set_third_person(true)
	var initial := snapshot()
	rotate_selected(1)
	interact()
	if busy or snapshot() != initial or not available_interaction().is_empty():
		failures.append("An engaged brake must reject rotation; overview cannot operate local controls")
	toggle_view()
	if available_interaction() != "extend":
		failures.append("The entry control must be reachable in third person")
	interact()
	if not busy or not arrival.neighbours.is_empty():
		failures.append("Walkway deployment must disable traversal until settled")
	rotation_tween.custom_step(1.5)
	if not track_open or carrier_released or not arrival.neighbours.has(rounded_track):
		failures.append("The local control must extend a connected walkway without releasing the brake")
	undo()
	if snapshot() != initial or rounded_track.deployed or rounded_track.deployment != 0:
		failures.append("Undo must restore the folded route and its contact state")
	walker.set_third_person(false)
	interact()
	rotation_tween.custom_step(1.5)
	if not track_open:
		failures.append("First person must retain the same local interaction")
	walker.set_third_person(true)
	walker.place(carrier, Vector3(0, 1, 0))
	if not available_interaction().is_empty():
		failures.append("Local controls must not operate remotely")
	walker.place(arrival, Vector3(-1.8, 1, -1.9), Vector3.UP, Vector3.FORWARD)
	var max_normal_step := 0.0
	var curve_samples := 0
	update_overview_camera()
	var camera_frame := overview.global_basis
	for frame in range(270):
		var previous_normal := walker.normal
		walker.walk(Vector2(0, -1), 1.0 / 60.0)
		walker.sync_pose(1.0 / 60.0)
		update_overview_camera()
		max_normal_step = maxf(max_normal_step, previous_normal.angle_to(walker.normal))
		if walker.support == rounded_track:
			curve_samples += 1
			var ground := rounded_track.global_basis * rounded_track.surface_frame(walker.foot)
			if not walker.support.allows_point(walker.foot, walker.normal) or not (ground.inverse() * overview.global_basis).is_equal_approx(camera_frame):
				failures.append("Curve contact and consistent above-ground overview must agree")
				break
			if not walker.camera.global_transform.is_finite() or not follow_view_is_clear():
				failures.append("Follow camera must stay clear while rounding the authored track")
				break
	if curve_samples < 150 or max_normal_step > 0.03 or walker.normal.dot(Vector3.DOWN) < 0.999 or rounded_track.distance_at(walker.foot) < rounded_track.length() - 0.05:
		failures.append("Walking must smoothly reach the underside and stop at the tail boundary: %s / %s / %s" % [curve_samples, walker.foot, walker.normal])
	var underside := snapshot()
	if available_interaction() != "release":
		failures.append("Only the underside pose should reach the brake control")
	interact()
	rotation_tween.custom_step(1.5)
	if not carrier_released or not checkpoint.carrier_released:
		failures.append("The underside control must release and checkpoint the architectural mechanism")
	undo()
	if snapshot() != underside or carrier_released:
		failures.append("Undo must re-engage the brake and preserve the underside pose")
	interact()
	rotation_tween.custom_step(1.5)
	var released := snapshot()
	toggle_view()
	rotate_selected(1)
	if not busy:
		failures.append("The third-person interaction must enable isometric carrier rotation")
	else:
		rotation_tween.custom_step(1.0)
	undo()
	if snapshot() != released:
		failures.append("Architectural undo must keep the local mechanism's released state")
	toggle_view()
	# Walk backward continuously: return must transport heading and orbit too.
	test_walk(280, Vector2(0, 1))
	if walker.support != arrival or walker.normal.dot(Vector3.UP) < 0.999:
		failures.append("The same ribbon must return continuously to the entrance")
	for instant in [false, true]:
		walker.reduced_motion = instant
		for third in [false, true]:
			walker.set_third_person(third)
			walker.place(rounded_track, rounded_track.point_at(4.0), rounded_track.surface_frame(rounded_track.point_at(4.0)).y, -rounded_track.surface_frame(rounded_track.point_at(4.0)).z)
			var mid_curve := snapshot()
			test_walk(20)
			restore(mid_curve)
			if snapshot() != mid_curve or not walker.camera.global_transform.is_finite():
				failures.append("Recovery must preserve a curved contact in both camera modes")
	# Side edges do not connect to the underside or to the structural backing.
	test_walk(100, Vector2(1, 0))
	if absf(walker.foot.x) > CurvedTrack.WIDTH + 0.001 or absf(rounded_track.distance_at(walker.foot) - 4.0) > 0.01:
		failures.append("Curved ribbon sides must remain authored boundaries")
	# Exercise held screen-relative input, including the real camera clearance
	# solver at all supported follow distances in both comfort modes.
	walker.set_third_person(true)
	walker.keep_world_horizon = false
	for distance in [3.0, 5.5, 8.0]:
		for instant in [false, true]:
			walker.camera_distance = distance
			walker.reduced_motion = instant
			walker.place(arrival, Vector3(-1.8, 1, -1.9), Vector3.UP, Vector3.FORWARD)
			for movement in [Vector2(0, -1), Vector2(0, 1)]:
				for frame in range(270):
					walker.align_movement_to_camera(movement)
					walker.walk(movement, 1.0 / 60.0)
					walker.sync_pose(1.0 / 60.0)
					if not follow_view_is_clear():
						failures.append("Curved follow camera must stay clear at distance %s, reduced motion %s" % [distance, instant])
						break
				if movement.y < 0 and (walker.support != rounded_track or walker.normal.dot(Vector3.DOWN) < 0.999):
					failures.append("Held screen-relative forward must reach the underside")
				elif movement.y > 0 and walker.support != arrival:
					failures.append("Held screen-relative reverse must return to Arrival")
	walker.camera_distance = 5.5
	walker.reduced_motion = false
	walker.set_third_person(true)
	# Migrate a valid old authored-path save without resetting later progress.
	var legacy := snapshot()
	legacy.version = 3
	legacy.erase("track_open")
	legacy.erase("carrier_released")
	legacy.boarded = true
	legacy.player = {"piece": "Carrier", "foot": Vector3(0, 1, 0), "normal": Vector3.UP, "forward": Vector3.RIGHT, "pitch": -0.08}
	restore(legacy)
	if not carrier_released or not track_open or walker.support != carrier:
		failures.append("Version-3 progress must retain access to the carrier")
	new_journey()
	toggle_view()
	paused = true
	interact()
	paused = false
	won = true
	interact()
	won = false
	if track_open or busy:
		failures.append("Paused and completed games cannot operate controls")
	walker.reduced_motion = true
	interact()
	if rounded_track.deployment != 0.0:
		failures.append("Reduced motion must wait for an atomic settled mechanism change")
	rotation_tween.custom_step(0.01)
	if not track_open or busy or rounded_track.deployment != 1.0:
		failures.append("Reduced motion must finish deployment in a single step")
	var saved_contact := checkpoint.duplicate(true)
	walker.place(carrier, Vector3(0, 1, 0))
	restart_checkpoint()
	if snapshot() != saved_contact:
		failures.append("Checkpoint recovery must restore the last local control and route")
	walker.reduced_motion = false

func test_contextual_cutaway(failures: Array[String]) -> void:
	var saved := snapshot()
	arch_state = 1
	arch.rotation.y = PI / 2
	update_connections()
	hovered_gallery = null
	update_overview_camera()
	for entry in overview_cutaways:
		if entry.mesh.layers != 1 or entry.mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			failures.append("Unoccupied galleries must show the complete model by default")
	var roof_screen := overview.unproject_position(arch.to_global(Vector3(0, 4.4, 0)))
	hovered_gallery = gallery_at_screen(roof_screen)
	if hovered_gallery != arch:
		failures.append("Hover must pick the nearest full gallery volume")
	update_architecture_cutaway()
	var opened := false
	for entry in overview_cutaways:
		if entry.mesh.get_parent() == arch:
			opened = opened or entry.mesh.layers == 16
		elif entry.mesh.layers != 1:
			failures.append("Hover must leave an unaligned counterpart complete")
	if not opened or gallery_at_screen(roof_screen) != arch:
		failures.append("Hovering a cut roof must keep a stable reveal")
	hovered_gallery = gallery_at_screen(Vector2(-10, -10))
	update_architecture_cutaway()
	for entry in overview_cutaways:
		if entry.mesh.layers != 1:
			failures.append("Leaving a module must restore its roof and walls")
	restore(saved)
	walker.place(courtyard, Vector3(0, 1, -6), Vector3.UP, Vector3.FORWARD)
	update_architecture_cutaway()
	if not gallery_contains_player(arch) or gallery_contains_player(gallery_modules[1]):
		failures.append("Occupancy must use the physical module and current support")
	for gallery in gallery_modules:
		opened = false
		for entry in overview_cutaways:
			if entry.mesh.get_parent() == gallery and entry.mesh.layers == 16:
				opened = true
		if not opened:
			failures.append("An occupied aligned passage must reveal both overlapping shells")
	architectural = false
	update_architecture_cutaway()
	for entry in overview_cutaways:
		if entry.mesh.layers != 1 or entry.mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			failures.append("Traversal must restore complete architecture and shadows")
	architectural = true
	walker.place(destination, Vector3(0, 1, -12.5), Vector3.UP, Vector3.FORWARD)
	update_architecture_cutaway()
	for entry in overview_cutaways:
		if entry.mesh.layers != 1:
			failures.append("Leaving the gallery for the goal court must close the cutaway")
	restore(saved)

func follow_view_is_clear() -> bool:
	var pivot := walker.avatar.global_position + walker.avatar.global_basis.y * 0.85
	var target := walker.camera.to_local(pivot)
	if not walker.camera.global_transform.is_finite() or target.z > -0.45 or absf(target.x) > 0.05 or absf(target.y) > 0.05:
		return false
	for piece in pieces:
		var local := piece.to_local(walker.camera.global_position)
		if piece.contains_solid(local, 0.07):
			return false
	return true
