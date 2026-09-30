extends Node3D
## One continuous courtyard, three rules, one distant destination.

const Piece = preload("res://scripts/surface_piece.gd")
const Walker = preload("res://scripts/surface_walker.gd")
const HUD = preload("res://scripts/hud.gd")
var pieces: Array[SurfacePiece] = []
var arrival: SurfacePiece
var carrier: SurfacePiece
var courtyard: SurfacePiece
var destination: SurfacePiece
var arch: Node3D
var arch_state := 1
var portal: MeshInstance3D
var portal_view: SubViewport
var portal_camera: Camera3D
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
var message := "A world with more than one ground."
var message_time := 8.0
var rotation_tween: Tween
var camera_tween: Tween
var audio: AudioStreamPlayer
var portal_previous := 0.0
var time := 0.0
var transition_camera: Camera3D
var input_bindings := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "view": KEY_TAB, "rotate_left": KEY_Q, "rotate_right": KEY_E, "undo": KEY_Z, "reset": KEY_R, "hint": KEY_H}

func _ready() -> void:
	configure_input()
	build_world()
	walker = Walker.new()
	walker.name = "Walker"
	add_child(walker)
	walker.pieces = pieces
	walker.place(arrival, Vector3(-1, 1, 0), Vector3.UP, Vector3.RIGHT)
	walker.stepped.connect(func(): play_tone(130.0, 0.035, 0.05))
	walker.changed_surface.connect(surface_changed)
	overview = Camera3D.new()
	add_child(overview)
	overview.projection = Camera3D.PROJECTION_ORTHOGONAL
	overview.size = 46.0
	overview.position = Vector3(34, 35, 35)
	overview.look_at(Vector3(2, 0, -7))
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
	arrival = make_piece("Arrival", Vector3(-10, 0, 0), Vector3(8, 2, 7), Color("647790"))
	carrier = make_piece("Carrier", Vector3.ZERO, Vector3(12, 2, 3), Color("a97166"), true)
	courtyard = make_piece("Courtyard", Vector3(0, 0, -10), Vector3(7, 2, 8), Color("777299"))
	destination = make_piece("Destination", Vector3(19, 0, -22), Vector3(8, 2, 10), Color("719899"))
	# An engraved underside discovery rewards trying the first spatial rule.
	var inscription := Label3D.new()
	inscription.text = "THERE IS NO OTHER SIDE"
	inscription.font_size = 40
	inscription.pixel_size = 0.008
	inscription.modulate = Color("ffe2ac")
	arrival.add_child(inscription)
	inscription.position = Vector3(0, -1.02, 0)
	inscription.rotation_degrees.x = 90
	# Surface inlays: directional architecture, never an axis legend.
	for p in [arrival, carrier, courtyard, destination]:
		for i in range(-2, 3):
			Piece.box(p, Vector3(i * 0.8, 1.012, 0), Vector3(0.035, 0.018, minf(p.half.z * 1.5, 3.0)), Piece.material(Color("decda9"), 0.15))
	build_arch()
	# Goal is its own volume, unreachable across the visible gap.
	var shrine := Node3D.new()
	destination.add_child(shrine)
	shrine.position = Vector3(0, 1, -3.5)
	arch_frame(shrine, Color("d1c2a8"), 3.8)
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.42
	sphere.height = 0.84
	orb.mesh = sphere
	orb.material_override = Piece.material(Color("ffdda0"), 2.0)
	shrine.add_child(orb)
	orb.position.y = 2.2
	var light := OmniLight3D.new()
	light.position = Vector3(19, 4, -25.5)
	light.light_color = Color("ffca81")
	light.light_energy = 2
	light.omni_range = 9
	add_child(light)
	# Disconnected distant monuments establish scale without false traversal.
	var rng := RandomNumberGenerator.new()
	rng.seed = 431
	for i in range(32):
		var angle := float(i) / 32.0 * TAU
		var radius := rng.randf_range(45, 75)
		var height := rng.randf_range(6, 28)
		var pos := Vector3(cos(angle) * radius, -34 - height * 0.5, sin(angle) * radius - 8)
		Piece.box(self, pos, Vector3(rng.randf_range(3, 7), height, rng.randf_range(3, 7)), Piece.material(Color("29374f")))
		if i % 3 == 0:
			Piece.box(self, pos + Vector3(0, height * 0.5, 0), Vector3(2.5, 0.06, 2.5), Piece.material(Color("a0b6c1"), 0.4))
	for i in range(100):
		var at := Vector3(rng.randf_range(-90, 90), rng.randf_range(15, 65), rng.randf_range(-95, -40))
		Piece.box(self, at, Vector3.ONE * rng.randf_range(0.035, 0.12), Piece.material(Color("afbdd9"), 0.8))
	# Pivot spindle stays below the walkable carrier.
	Piece.box(self, Vector3(0, -2, 0), Vector3(1.2, 2, 1.2), Piece.material(Color("b7a181")))

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
	arch = Node3D.new()
	arch.name = "DistantArch"
	add_child(arch)
	arch.position = Vector3(0, 1, -11.6)
	arch_frame(arch, Color("d1bd9c"))
	arch.rotation.y = PI * 0.5
	portal_view = SubViewport.new()
	portal_view.size = Vector2i(1280, 800)
	portal_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(portal_view)
	portal_view.world_3d = get_world_3d()
	portal_camera = Camera3D.new()
	portal_camera.cull_mask = 1
	portal_camera.fov = 76
	portal_view.add_child(portal_camera)
	portal_camera.current = true
	portal = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.7, 3.8)
	portal.mesh = quad
	portal.layers = 2
	arch.add_child(portal)
	portal.position = Vector3(0, 1.9, 0)
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, cull_disabled; uniform sampler2D view_texture : source_color, filter_linear; void fragment(){ ALBEDO = texture(view_texture, SCREEN_UV).rgb; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("view_texture", portal_view.get_texture())
	portal.material_override = material
	portal.visible = false

func _process(delta: float) -> void:
	time += delta
	message_time = maxf(0, message_time - delta)
	if walker == null:
		return
	if not architectural and not busy and not paused and not won:
		walker.walk(Input.get_vector("left", "right", "forward", "back"), minf(delta, 0.1))
		check_passage()
		if walker.support == destination and walker.foot.z < -2.6 and walker.normal.y > 0.9:
			complete()
	walker.sync_pose(delta)
	if portal.visible:
		var active_camera := overview if architectural else walker.camera
		portal_camera.global_transform = active_camera.global_transform
		portal_camera.global_position += Vector3(19, 0, -10)
		portal_camera.projection = active_camera.projection
		portal_camera.size = active_camera.size
		portal_camera.fov = active_camera.fov
		portal_camera.near = maxf(0.08, absf(active_camera.global_position.z + 11.6) - 0.1) if not architectural else 0.1
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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if architectural else Input.MOUSE_MODE_CAPTURED
	walker.avatar.visible = architectural
	if architectural:
		overview.current = true
	else:
		walker.sync_pose(1.0)
		walker.camera.current = true
		portal_previous = walker.support.to_global(walker.foot).z + 11.6
	if not walker.reduced_motion:
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
	var arch_screen := overview.unproject_position(arch.global_position + Vector3(0, 2, 0))
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
	if selected == 1 and walker.support == courtyard and walker.foot.distance_to(Vector3(0, 1, -1.6)) < 2.5:
		notify("Step away from the arch before turning it.")
		return
	if selected == 0 and not safe_carrier_turn(direction):
		notify("That turn would trap you at the joint. Move toward the carrier's centre.")
		return
	history.append(snapshot())
	busy = true
	portal.visible = false
	var target: Node3D = carrier if selected == 0 else arch
	if selected == 0:
		carrier.state = posmod(carrier.state + direction, 4)
	else:
		arch_state = posmod(arch_state + direction, 4)
	play_tone(175, 0.45, 0.12)
	rotation_tween = create_tween()
	rotation_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	rotation_tween.tween_property(target, "rotation:y", target.rotation.y + direction * PI * 0.5, 0.12 if walker.reduced_motion else 0.8)
	rotation_tween.tween_callback(func():
		busy = false
		portal.visible = arch_state == 0
		play_tone(620 if portal.visible else 300, 0.2, 0.1)
		notify("The distant passage is connected." if portal.visible else "The structure settles. Your ground travels with you.")
	)

func safe_carrier_turn(direction: int) -> bool:
	# Check the attached body through the complete sweep, including side faces.
	for step in range(1, 25):
		var basis_at := Basis(Vector3.UP, carrier.rotation.y + direction * PI * 0.5 * float(step) / 24.0)
		for height in [0.25, 0.8, 1.55]:
			if walker.support != carrier:
				var stationary_point: Vector3 = walker.support.to_global(walker.foot + walker.normal * height)
				var in_carrier := basis_at.inverse() * (stationary_point - carrier.global_position)
				if absf(in_carrier.x) < carrier.half.x + 0.16 and absf(in_carrier.y) < carrier.half.y + 0.16 and absf(in_carrier.z) < carrier.half.z + 0.16:
					return false
				continue
			var point: Vector3 = carrier.global_position + basis_at * (walker.foot + walker.normal * height)
			for other in [arrival, courtyard, destination]:
				var local: Vector3 = other.to_local(point)
				if absf(local.x) < other.half.x + 0.16 and absf(local.y) < other.half.y + 0.16 and absf(local.z) < other.half.z + 0.16:
					return false
	return true

func check_passage() -> void:
	var position_world := walker.support.to_global(walker.foot)
	var current := position_world.z + 11.6
	if arch_state == 0 and not busy and walker.support == courtyard and walker.normal.y > 0.99:
		if portal_previous > 0 and current <= 0 and absf(position_world.x) < 1.30:
			var mapped := position_world + Vector3(19, 0, -10.08)
			var heading := walker.support.global_basis * walker.forward
			walker.place(destination, destination.to_local(mapped), Vector3.UP, heading)
			crossed = true
			notify("Far away was only another kind of next door.")
			play_tone(740, 0.45, 0.15)
			checkpoint = snapshot()
			save_progress()
	portal_previous = current

func surface_changed() -> void:
	if walker.support == carrier and not boarded:
		boarded = true
		notify("You are the passenger. Change the world from here.")
	if walker.support == courtyard and not reached_court:
		reached_court = true
		checkpoint = snapshot()
		save_progress()
		notify("A distant opening. A familiar shape. Try the architectural view.")
	if walker.normal.y < -0.9 and walker.support == arrival:
		notify("The underside is ground, too.")

func snapshot() -> Dictionary:
	return {"carrier": carrier.state, "arch": arch_state, "player": walker.snapshot(), "boarded": boarded, "court": reached_court, "crossed": crossed}

func restore(data: Dictionary) -> void:
	if rotation_tween and rotation_tween.is_running():
		rotation_tween.kill()
	busy = false
	carrier.state = data.carrier
	carrier.rotation.y = carrier.state * PI * 0.5
	arch_state = data.arch
	arch.rotation.y = arch_state * PI * 0.5
	portal.visible = arch_state == 0
	walker.restore(data.player, self)
	boarded = data.boarded
	reached_court = data.court
	crossed = data.crossed
	won = false
	portal_previous = walker.support.to_global(walker.foot).z + 11.6

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
	if rotation_tween:
		rotation_tween.kill()
	busy = false
	carrier.state = 0
	carrier.rotation.y = 0
	arch_state = 1
	arch.rotation.y = PI / 2
	portal.visible = false
	boarded = false
	reached_court = false
	crossed = false
	won = false
	hud.completion.hide()
	hint_level = 0
	history.clear()
	walker.place(arrival, Vector3(-1, 1, 0), Vector3.UP, Vector3.RIGHT)
	checkpoint = snapshot()
	save_progress()
	set_pause(false)
	if not architectural:
		toggle_view()

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
		if data is Dictionary and data.has_all(["player", "carrier", "arch", "boarded", "court", "crossed"]):
			if data.player is Dictionary and str(data.player.get("piece", "")) in ["Arrival", "Carrier", "Courtyard", "Destination"]:
				checkpoint = data
				restore(data)

func set_pause(value: bool) -> void:
	paused = value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused or architectural or won else Input.MOUSE_MODE_CAPTURED
	if rotation_tween and rotation_tween.is_running():
		if paused:
			rotation_tween.pause()
		else:
			rotation_tween.play()
	if camera_tween:
		if paused:
			camera_tween.pause()
		else:
			camera_tween.play()
	hud.show_menu(value)

func notify(text: String) -> void:
	message = text
	message_time = 7.0

func show_hint() -> void:
	var hints: Array[String]
	if not boarded:
		hints = ["The long terracotta structure can carry more than a path.", "Its two orientations connect different islands.", "Walk onto the carrier before rotating it. The sides and underside are also walkable."]
	elif not reached_court:
		hints = ["Your position is part of the arrangement.", "Stand on the carrier, then give it a quarter-turn.", "After rotating, walk toward the violet courtyard. On a side face, round an edge to reach the top."]
	else:
		hints = ["The small arch and the distant tower share an opening.", "Select the arch in architectural view. An accepted alignment will stay connected.", "Press 2 to select the arch, then Q until it reads CONNECTED. Return inside and walk through it toward the light."]
	notify(hints[mini(hint_level, 2)])
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

func run_self_test() -> void:
	await get_tree().process_frame
	var failures: Array[String] = []
	# Follow actual surface movement across the start/carrier seam.
	walker.place(arrival, Vector3(3.9, 1, 0), Vector3.UP, Vector3.RIGHT)
	walker.advance(Vector3.RIGHT, 0.2)
	if walker.support != carrier:
		failures.append("Arrival to carrier seam")
	var local_before := walker.foot
	var up_before := walker.normal
	carrier.rotation.y = PI / 2
	carrier.state = 1
	walker.sync_pose(1)
	if not walker.foot.is_equal_approx(local_before) or walker.normal != up_before:
		failures.append("Carrier local attachment")
	# Separate start cannot connect to rotated carrier.
	walker.place(arrival, Vector3(3.9, 1, 0), Vector3.UP, Vector3.RIGHT)
	walker.advance(Vector3.RIGHT, 0.2)
	if walker.support != arrival or walker.normal != Vector3.RIGHT:
		failures.append("Gap must fold, never magnetize")
	# Top -> side -> underside.
	walker.place(arrival, Vector3(4, 0.9, 0), Vector3.RIGHT, Vector3.DOWN)
	for i in range(22):
		walker.advance(Vector3.DOWN if walker.normal == Vector3.RIGHT else Vector3.LEFT, 0.1)
	if walker.normal != Vector3.DOWN:
		failures.append("Continuous underside traversal")
	# Carrier's positive local X ends at courtyard in state B.
	walker.place(carrier, Vector3(5.95, 1, 0), Vector3.UP, Vector3.RIGHT)
	walker.advance(Vector3.FORWARD, 0.1)
	if walker.support != courtyard:
		failures.append("Carrier to courtyard seam")
	var saved := snapshot()
	walker.place(arrival, Vector3(0, 1, 0))
	restore(saved)
	if walker.support != courtyard:
		failures.append("Atomic restore")
	# Active portal transports to the separate destination volume.
	arch_state = 1
	walker.place(courtyard, Vector3(0, 1, -1.5))
	portal_previous = 0.1
	walker.advance(Vector3.FORWARD, 0.2)
	check_passage()
	if walker.support != courtyard:
		failures.append("Inactive passage must not transport")
	arch_state = 0
	walker.place(courtyard, Vector3(0, 1, -1.5))
	portal_previous = 0.1
	walker.advance(Vector3.FORWARD, 0.2)
	check_passage()
	if walker.support != destination or not crossed:
		failures.append("Persistent impossible passage")
	# Repeated diagonal corner folds must stay on the bounded solid.
	walker.place(arrival, Vector3(3.95, 1, 3.45), Vector3.UP, Vector3(1, 0, 1).normalized())
	for i in range(240):
		walker.walk(Vector2(0.65, -1).normalized(), 1.0 / 60.0)
		var p := walker.foot.abs()
		if p.x > walker.support.half.x + 0.001 or p.y > walker.support.half.y + 0.001 or p.z > walker.support.half.z + 0.001:
			failures.append("Corner folds must remain on support")
			break
	# A side-face passenger rotates their world up but retains their local up.
	walker.place(carrier, Vector3(0, 0, 1.5), Vector3.BACK, Vector3.RIGHT)
	var world_up_before := carrier.global_basis * walker.normal
	carrier.rotation.y += PI / 2
	walker.sync_pose(1)
	if walker.normal != Vector3.BACK or world_up_before.is_equal_approx(carrier.global_basis * walker.normal):
		failures.append("Side-face attachment must carry gravity")
	if failures.is_empty():
		print("SELF TEST PASS: seams, attachment, gaps, underside, restore, passage")
	else:
		for failure in failures:
			push_error("SELF TEST FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)
