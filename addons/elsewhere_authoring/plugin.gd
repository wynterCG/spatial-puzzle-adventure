@tool
extends EditorPlugin
const C = preload("res://authoring/component.gd")
const Level = preload("res://authoring/level.gd")
const Links = preload("res://authoring/connections.gd")
const Validate = preload("res://authoring/validation.gd")
const Table = preload("res://authoring/connection_table.gd")
var dock: VBoxContainer
var status: Label
var result: RichTextLabel
var states_box: VBoxContainer
var viewport: SubViewport
var camera: Camera3D
var preview: Node3D
var overlay: Node3D
var preview_states: Dictionary = {}
var preview_interactions: Dictionary = {}
var preview_link: Array = []
var reach_from := ""
var connections: RichTextLabel
var table_box: VBoxContainer
var launch_box: VBoxContainer
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
	reset.pressed.connect(func(): preview_states.clear(); preview_interactions.clear(); preview_link.clear(); reach_from = ""; refresh_preview())
	dock.add_child(reset)
	# What joins now, and, for a selected structure, what each of its states changes.
	connections = RichTextLabel.new()
	connections.fit_content = true
	connections.bbcode_enabled = true
	dock.add_child(connections)
	table_box = VBoxContainer.new()
	dock.add_child(table_box)
	var reach := Button.new()
	reach.text = "Show Reachable From Selected Path"
	reach.pressed.connect(show_reachable)
	dock.add_child(reach)
	# The rest of the test condition for Play From Here: interactions and the link pair.
	launch_box = VBoxContainer.new()
	dock.add_child(launch_box)
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
	preview_states.clear(); preview_interactions.clear(); preview_link.clear(); reach_from = ""
	launch_payload = ""
	call_deferred("refresh_preview")
func _selection_changed() -> void:
	var selected := EditorInterface.get_selection().get_selected_nodes()
	if not selected.is_empty() and selected[0] is C:
		status.text = "Selected: " + str(selected[0].name) + "\nEdit data in the Inspector; refresh to inspect connections."
		if selected[0].kind == C.Kind.ROTATOR: call_deferred("refresh_preview")

func selected_component() -> Node3D:
	var selected := EditorInterface.get_selection().get_selected_nodes()
	return selected[0] if selected.size() == 1 and selected[0] is C else null

## Base transforms of every structure, from the authored scene (the preview is posed from these).
func structure_bases(source: Node3D) -> Dictionary:
	var bases := {}
	for c in Table.structures(source): bases[str(source.get_path_to(c))] = c.transform
	return bases

func show_reachable() -> void:
	var source := get_level()
	var c := selected_component()
	if source == null or c == null or not c.kind in [C.Kind.PATH, C.Kind.CURVE] or not source.is_ancestor_of(c):
		result.text = "Select a path or curve, then Show Reachable."; return
	reach_from = str(source.get_path_to(c))
	refresh_preview()
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
	for box in [states_box, table_box, launch_box]:
		for control in box.get_children():
			box.remove_child(control); control.queue_free()
	connections.text = ""
	if source == null:
		status.text = "Open monuments/*.tscn, or duplicate one to begin."
		result.text = "Add behaviours from authoring/components. Use your own architecture under the same pivots."
		return
	if scene_id != source.level_id:
		scene_id = source.level_id; preview_states.clear(); preview_interactions.clear(); preview_link.clear(); reach_from = ""
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
	connection_report(source)
	launch_controls()
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
	if reach_from != "" and preview.has_node(reach_from):
		var highlight := StandardMaterial3D.new()
		highlight.albedo_color = Color(.45, 1, .7, .55)
		highlight.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var names := Table.reachable(preview, preview.get_node(reach_from))
		for c in preview.components():
			if c.kind in [C.Kind.PATH, C.Kind.CURVE] and Table.label(c) in names:
				for mesh in c.find_children("*", "MeshInstance3D", true, false): mesh.material_overlay = highlight
	camera.size = source.overview_size
	# The editor preview shows the authored composition from upright ground.
	camera.position = source.overview_focus + source.overview_local_offset()
	camera.look_at(source.overview_focus)
	camera.current = true

## The Connections section: joins in the current preview, reachability, and the selected
## structure's per-state table (+ new, - removed, = unchanged, stranded paths). Rows preview.
func connection_report(source: Node3D) -> void:
	var lines: Array[String] = ["[b]CONNECTIONS[/b] (current preview)"]
	for pair in Table.joins(preview): lines.append("  %s <-> %s" % pair)
	if lines.size() == 1: lines.append("  nothing joins")
	if reach_from != "" and preview.has_node(reach_from):
		lines.append("[b]REACHABLE[/b] from %s, now: %s" % [Table.label(preview.get_node(reach_from)), ", ".join(Table.reachable(preview, preview.get_node(reach_from)))])
	connections.text = "\n".join(lines)
	var c := selected_component()
	if c == null or c.kind != C.Kind.ROTATOR or not source.is_ancestor_of(c): return
	var id := str(source.get_path_to(c))
	var states := {}
	for structure in Table.structures(source):
		var key := str(source.get_path_to(structure))
		states[key] = preview_states.get(key, structure.initial_state)
	var rows: Array = Table.by_state(preview, preview.get_node(id), states, structure_bases(source))
	var title := Label.new()
	title.text = "%s: what each state changes" % Table.label(c)
	table_box.add_child(title)
	for row in rows:
		var parts: Array[String] = []
		for pair in row.added: parts.append("+ %s <-> %s" % pair)
		for pair in row.removed: parts.append("- %s <-> %s" % pair)
		if row.added.is_empty() and row.removed.is_empty(): parts.append("= no change" if row.state == states[id] else "= same joins")
		if not row.stranded.is_empty(): parts.append("stranded: " + ", ".join(row.stranded))
		var button := Button.new()
		button.text = "%d / %s%s\n%s" % [row.state, row.name, "  (previewed)" if row.state == states[id] else "", "\n".join(parts)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func(): preview_states[id] = row.state; call_deferred("refresh_preview"))
		table_box.add_child(button)

## Interaction values and the link pair that Play From Here starts with.
func launch_controls() -> void:
	for c in preview.components():
		if c.kind != C.Kind.INTERACTION: continue
		var id := str(preview.get_path_to(c))
		var box := CheckBox.new()
		box.text = "Start with %s used" % Table.label(c)
		box.button_pressed = preview_interactions.get(id, c.initial_value)
		box.toggled.connect(func(value: bool): preview_interactions[id] = value)
		launch_box.add_child(box)
	var doorways := Links.thresholds(preview)
	if doorways.size() < 2: return
	var selector := OptionButton.new()
	selector.add_item("Start with no link")
	var pairs: Array = [[]]
	for i in range(doorways.size()):
		for j in range(i + 1, doorways.size()):
			if doorways[i].group != doorways[j].group: continue
			pairs.append([doorways[i].id, doorways[j].id])
			selector.add_item("Start linked: %s <-> %s" % [Table.label(doorways[i].node), Table.label(doorways[j].node)])
	selector.select(maxi(0, pairs.find(preview_link)))
	selector.item_selected.connect(func(index: int): preview_link = pairs[index])
	launch_box.add_child(selector)

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
	launch_payload = Marshalls.utf8_to_base64(JSON.stringify({"level": source.level_id, "marker": str(source.get_path_to(marker)), "states": preview_states, "interactions": preview_interactions, "link": preview_link}))
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
