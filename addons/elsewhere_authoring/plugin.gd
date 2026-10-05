@tool
extends EditorPlugin
const C = preload("res://authoring/component.gd")
const Level = preload("res://authoring/level.gd")
const Links = preload("res://authoring/connections.gd")
const Validate = preload("res://authoring/validation.gd")
var dock: VBoxContainer
var status: Label
var result: RichTextLabel
var states_box: VBoxContainer
var viewport: SubViewport
var camera: Camera3D
var preview: Node3D
var overlay: Node3D
var preview_states: Dictionary = {}
var scene_id := ""
var launch_payload := ""
var launch_scene := ""

func _enter_tree() -> void:
	dock = VBoxContainer.new()
	dock.name = "Elsewhere"
	dock.custom_minimum_size.x = 310
	var title := Label.new()
	title.text = "ELSEWHERE / AUTHORING"
	dock.add_child(title)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock.add_child(status)
	var refresh := Button.new()
	refresh.text = "Refresh preview and validate"
	refresh.pressed.connect(refresh_preview)
	dock.add_child(refresh)
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(310, 240)
	container.stretch = true
	dock.add_child(container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(620, 480)
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	container.add_child(viewport)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	for rotation_value in [Vector3(-50, -35, 0), Vector3(40, 120, 0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = rotation_value
		light.light_energy = .8
		viewport.add_child(light)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("10182f")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("a5b8ef")
	settings.ambient_light_energy = .6
	environment.environment = settings
	viewport.add_child(environment)
	states_box = VBoxContainer.new()
	dock.add_child(states_box)
	var reset := Button.new()
	reset.text = "Reset preview to authored initial states"
	reset.pressed.connect(func(): preview_states.clear(); refresh_preview())
	dock.add_child(reset)
	var play := Button.new()
	play.text = "Play From Selected Path / Marker"
	play.pressed.connect(play_from_selection)
	dock.add_child(play)
	var legend := Label.new()
	legend.text = "Green: joined   Amber: open   Red: invalid\nBlue: ground normal   Gold: travel direction\nPreview is temporary; scene transforms stay unchanged."
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock.add_child(legend)
	result = RichTextLabel.new()
	result.custom_minimum_size.y = 140
	result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock.add_child(result)
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)
	scene_changed.connect(_scene_changed)
	EditorInterface.get_selection().selection_changed.connect(_selection_changed)
	call_deferred("refresh_preview")

func _exit_tree() -> void:
	if is_instance_valid(dock):
		remove_control_from_docks(dock)
		dock.queue_free()
	if EditorInterface.get_selection().selection_changed.is_connected(_selection_changed): EditorInterface.get_selection().selection_changed.disconnect(_selection_changed)

func _scene_changed(_root: Node) -> void:
	preview_states.clear()
	launch_payload = ""
	call_deferred("refresh_preview")
func _selection_changed() -> void:
	var selected := EditorInterface.get_selection().get_selected_nodes()
	if not selected.is_empty() and selected[0] is C:
		status.text = "Selected: " + str(selected[0].name) + "\nEdit data in the Inspector; refresh to inspect connections."
func get_level() -> Node3D:
	var root := EditorInterface.get_edited_scene_root()
	if root == null: return null
	if root is Level: return root
	return root.get_node_or_null("Level") as ElsewhereLevel

func refresh_preview() -> void:
	var source := get_level()
	if is_instance_valid(preview):
		viewport.remove_child(preview); preview.queue_free()
	if is_instance_valid(overlay):
		viewport.remove_child(overlay); overlay.queue_free()
	for control in states_box.get_children():
		states_box.remove_child(control); control.queue_free()
	if source == null:
		status.text = "Open monuments/*.tscn, or duplicate one to begin."
		result.text = "Add behaviours from authoring/components. Use your own architecture under the same pivots."
		return
	if scene_id != source.level_id:
		scene_id = source.level_id; preview_states.clear()
	preview = source.duplicate()
	preview.name = "Preview"
	viewport.add_child(preview)
	preview.show()
	for c in preview.components():
		c.rebuild_preview()
		if c.kind == C.Kind.ROTATOR and c.state_count() > 0:
			var id := str(preview.get_path_to(c))
			var index: int = clampi(preview_states.get(id, c.initial_state), 0, c.state_count() - 1)
			c.transform = c.state_local_transform(c.transform, index)
			var row := HBoxContainer.new()
			var name_label := Label.new()
			name_label.text = str(c.name)
			row.add_child(name_label)
			var selector := OptionButton.new()
			for i in range(c.state_count()): selector.add_item("%d / %s" % [i, c.state_label(i) if not c.state_names.is_empty() else ("%s°" % c.angles[i] if c.motion == C.Motion.ROTATE else str(c.offsets[i]))])
			selector.select(index)
			selector.item_selected.connect(func(value: int): preview_states[id] = value; call_deferred("refresh_preview"))
			row.add_child(selector)
			states_box.add_child(row)
	var report := Validate.validate(preview)
	status.text = source.title + "\nIsolated state preview — editor scene is the authored base pose."
	result.text = ("No structural errors.\n" if report.errors.is_empty() else "ERRORS\n" + "\n".join(report.errors) + "\n") + "\nOPEN CONTACTS / WARNINGS\n" + "\n".join(report.warnings)
	overlay = Node3D.new()
	viewport.add_child(overlay)
	var sockets := Links.descriptors(preview)
	for socket in sockets:
		var joined := false
		for other in sockets:
			if Links.compatible(socket, other): joined = true
		var colour := Color("80d2a6") if joined else Color("e0b36b")
		if not socket.active or not Validate.valid_contact(socket.path, socket.path.to_local(socket.position), socket.path.global_basis.inverse() * socket.normal): colour = Color("e87777")
		C.line(overlay, socket.position, socket.position + socket.direction * .8, colour)
		C.line(overlay, socket.position, socket.position + socket.normal * .9, Color("6dbbe8"))
		var tangent: Vector3 = socket.direction.cross(socket.normal).normalized() * socket.width / 2
		C.line(overlay, socket.position - tangent, socket.position + tangent, colour)
	camera.size = source.overview_size
	# The editor preview shows the authored composition from upright ground.
	camera.position = source.overview_focus + source.overview_local_offset()
	camera.look_at(source.overview_focus)
	camera.current = true

func play_from_selection() -> void:
	var source := get_level()
	var root := EditorInterface.get_edited_scene_root()
	var selected := EditorInterface.get_selection().get_selected_nodes()
	if source == null or root.scene_file_path.is_empty() or selected.size() != 1:
		result.text = "Select one path, PlayerStart or Checkpoint in a saved authored level."; return
	var marker = selected[0]
	if not marker is C or not marker.kind in [C.Kind.PATH, C.Kind.CURVE, C.Kind.START, C.Kind.CHECKPOINT] or not source.is_ancestor_of(marker) or not marker.active:
		result.text = "Play From Here needs an active path or a valid start/checkpoint marker."; return
	var report := Validate.validate(source)
	if not report.errors.is_empty(): result.text = "Fix errors before play:\n" + "\n".join(report.errors); return
	# Saving may open an editor progress task. Wait until outside a deferred
	# callback/message-queue flush (including MCP-driven editor tests).
	await get_tree().process_frame
	if not is_instance_valid(root) or root != EditorInterface.get_edited_scene_root(): return
	if EditorInterface.save_scene() != OK:
		result.text = "Save the scene successfully before Play From Here."; return
	launch_payload = Marshalls.utf8_to_base64(JSON.stringify({"level": source.level_id, "marker": str(source.get_path_to(marker)), "states": preview_states}))
	launch_scene = root.scene_file_path
	EditorInterface.play_custom_scene(launch_scene)

func _run_scene(scene: String, args: PackedStringArray) -> PackedStringArray:
	if scene == launch_scene and not launch_payload.is_empty():
		if not "--" in args: args.append("--")
		args.append("--authoring-launch=" + launch_payload)
	return args

func _process(_delta: float) -> void:
	# Clear once the launch has consumed the command-line payload. A later F6
	# starts normally and never consumes a stale marker or saves debug progress.
	if not launch_payload.is_empty() and EditorInterface.is_playing_scene(): launch_payload = ""
