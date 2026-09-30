extends CanvasLayer
## Quiet, scalable interface. No route line or axis legend.
var game: Node3D
var root: Control
var mode: Label
var task: Label
var chapter_title: Label
var selection: Label
var connection: Label
var guide: PanelContainer
var guide_title: Label
var guide_body: Label
var contextual_guidance := true
var status: Label
var toast: Label
var controls: Label
var sidebar: PanelContainer
var crosshair: Label
var menu: PanelContainer
var completion: PanelContainer
var rebind_action := ""
var rebind_button: Button
var key_buttons: Dictionary = {}
var cream := Color("f1e7d5")
var muted := Color("9daec2")

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 17
	theme.set_color("font_color", "Label", cream)
	theme.set_color("font_color", "Button", cream)
	theme.set_stylebox("normal", "Button", style(Color("233048"), 7))
	theme.set_stylebox("hover", "Button", style(Color("394963"), 7))
	theme.set_stylebox("pressed", "Button", style(Color("4e596d"), 7))
	root.theme = theme
	var top := VBoxContainer.new()
	root.add_child(top)
	top.position = Vector2(44, 32)
	var eyebrow := label("A N   A R C H I T E C T U R A L   J O U R N E Y", 12, muted)
	top.add_child(eyebrow)
	top.add_child(label("Elsewhere", 42))
	mode = label("", 14, Color("e2bd87"))
	top.add_child(mode)
	var chapter := VBoxContainer.new()
	root.add_child(chapter)
	chapter.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	chapter.offset_left = -338
	chapter.offset_top = 40
	chapter.offset_right = -44
	chapter.offset_bottom = 140
	chapter.custom_minimum_size.x = 295
	chapter_title = label("01   /   THE PASSENGER", 13, muted)
	chapter.add_child(chapter_title)
	task = label("", 19)
	task.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chapter.add_child(task)
	status = label("", 13, muted)
	chapter.add_child(status)
	guide = panel(Vector2.ZERO, Vector2(294, 0))
	guide.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	guide.offset_left = -338
	guide.offset_right = -44
	guide.offset_top = 156
	guide.offset_bottom = 285
	guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var guide_column := VBoxContainer.new()
	guide_column.add_theme_constant_override("separation", 9)
	guide_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide.add_child(guide_column)
	guide_title = label("", 16, Color("e2bd87"))
	guide_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_column.add_child(guide_title)
	guide_body = label("", 15, cream)
	guide_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_column.add_child(guide_body)
	sidebar = panel(Vector2(44, 590), Vector2(306, 190))
	sidebar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	sidebar.offset_left = 44
	sidebar.offset_right = 350
	sidebar.offset_top = -365
	sidebar.offset_bottom = -96
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	sidebar.add_child(column)
	column.add_child(label("RECONFIGURE", 12, muted))
	selection = label("", 20)
	column.add_child(selection)
	connection = label("", 13, muted)
	connection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(connection)
	var selector := HBoxContainer.new()
	selector.add_theme_constant_override("separation", 8)
	column.add_child(selector)
	selector.add_child(button("1  Carrier", func(): game.select_piece(0)))
	selector.add_child(button("2  Gallery", func(): game.select_piece(1)))
	var rotations := HBoxContainer.new()
	rotations.add_theme_constant_override("separation", 8)
	column.add_child(rotations)
	rotations.add_child(button("↶  Turn left", func(): game.rotate_selected(-1)))
	rotations.add_child(button("Turn right  ↷", func(): game.rotate_selected(1)))
	var bottom := PanelContainer.new()
	root.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 44
	bottom.offset_right = -44
	bottom.offset_top = -68
	bottom.offset_bottom = -26
	bottom.add_theme_stylebox_override("panel", style(Color(0.055, 0.08, 0.14, 0.9), 8))
	controls = label("", 14, muted)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(controls)
	toast = label("", 18)
	root.add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast.offset_left = -420
	toast.offset_right = 420
	toast.offset_top = -133
	toast.offset_bottom = -82
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	crosshair = label("·", 30, cream)
	root.add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -5
	crosshair.offset_top = -19
	build_menu()
	build_completion()
	load_settings()

func label(text: String, size: int, color := Color("f1e7d5")) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item

func style(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

func panel(at: Vector2, dimensions: Vector2) -> PanelContainer:
	var item := PanelContainer.new()
	root.add_child(item)
	item.position = at
	item.custom_minimum_size = dimensions
	item.add_theme_stylebox_override("panel", style(Color(0.055, 0.08, 0.14, 0.94), 10))
	return item

func button(text: String, callback: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.focus_mode = Control.FOCUS_NONE
	item.pressed.connect(callback)
	return item

func build_menu() -> void:
	menu = panel(Vector2.ZERO, Vector2(600, 740))
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.offset_left = -300
	menu.offset_right = 300
	menu.offset_top = -370
	menu.offset_bottom = 370
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	column.add_child(label("Take a moment", 30))
	column.add_child(label("COMFORT & CONTROLS", 12, muted))
	column.add_child(label("Traversal camera", 15, muted))
	var camera_mode := OptionButton.new()
	camera_mode.name = "CameraMode"
	camera_mode.add_item("Third person · surface follow")
	camera_mode.add_item("First person")
	camera_mode.item_selected.connect(func(index): game.walker.set_third_person(index == 0); save_settings())
	column.add_child(camera_mode)
	var horizon := CheckButton.new()
	horizon.name = "WorldHorizon"
	horizon.text = "Keep world horizon level (optional)"
	horizon.toggled.connect(func(value): game.walker.keep_world_horizon = value; game.walker.sync_pose(1.0); save_settings())
	column.add_child(horizon)
	var guidance_toggle := CheckButton.new()
	guidance_toggle.name = "ContextualGuidance"
	guidance_toggle.text = "Show contextual guidance"
	guidance_toggle.button_pressed = contextual_guidance
	guidance_toggle.toggled.connect(func(value): contextual_guidance = value; save_settings())
	column.add_child(guidance_toggle)
	column.add_child(label("Third-person camera distance", 15, muted))
	var distance := HSlider.new()
	distance.name = "CameraDistance"
	distance.min_value = 3.0
	distance.max_value = 8.0
	distance.step = 0.25
	distance.value = 5.5
	distance.value_changed.connect(func(value): game.walker.camera_distance = value; save_settings())
	column.add_child(distance)
	var reduced := CheckButton.new()
	reduced.name = "ReducedMotion"
	reduced.text = "Reduced motion"
	reduced.toggled.connect(func(value): game.walker.reduced_motion = value; save_settings())
	column.add_child(reduced)
	column.add_child(label("Look sensitivity", 15, muted))
	var sensitivity := HSlider.new()
	sensitivity.name = "Sensitivity"
	sensitivity.min_value = 0.0005
	sensitivity.max_value = 0.006
	sensitivity.step = 0.0001
	sensitivity.value = 0.0022
	sensitivity.value_changed.connect(func(value): game.walker.sensitivity = value; save_settings())
	column.add_child(sensitivity)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	column.add_child(grid)
	for action in game.input_bindings:
		grid.add_child(label(action.replace("_", " ").capitalize(), 14, muted))
		var key_button := button(game.key_name(action), func(): begin_rebind(action))
		key_button.custom_minimum_size.x = 70
		grid.add_child(key_button)
		key_buttons[action] = key_button
	column.add_child(label("Click a key to remap it. Escape cancels.\nWalk on ivory paths; ordinary edges stop you.\nIn architectural view, click a piece or use 1 / 2.", 14, muted))
	column.add_child(button("Continue journey", func(): game.set_pause(false)))
	column.add_child(button("Return to checkpoint", func(): game.restart_checkpoint(); game.set_pause(false)))
	column.add_child(button("Start a new journey", func(): game.new_journey()))
	column.add_child(button("Quit", func(): get_tree().quit()))
	menu.visible = false

func build_completion() -> void:
	completion = panel(Vector2.ZERO, Vector2(600, 330))
	completion.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	completion.offset_left = -300
	completion.offset_right = 300
	completion.offset_top = -165
	completion.offset_bottom = 165
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	completion.add_child(column)
	column.add_child(label("THE FIRST CONNECTION", 13, Color("e2bd87")))
	column.add_child(label("You found another way.", 34))
	column.add_child(label("A deck carried your ground. Two galleries aligned.\nA distant place became the next step.\n\nThe courtyard is complete. The wider world awaits.", 18, muted))
	column.add_child(button("Explore again", func(): completion.hide(); game.new_journey()))
	completion.visible = false

func refresh() -> void:
	mode.text = "ARCHITECT  /  observe & transform" if game.architectural else ("INHABITANT  /  third person" if game.walker.third_person else "INHABITANT  /  first person")
	sidebar.visible = game.architectural and not game.paused and not game.won
	controls.get_parent().visible = not game.paused and not game.won
	crosshair.visible = not game.architectural and not game.walker.third_person and not game.paused and not game.won
	selection.text = ("The Passenger  ·  " + ["ENTRANCE", "LANDING", "UNJOINED", "UNJOINED"][game.carrier.state]) if game.selected == 0 else ("Turning Gallery  ·  " + ("ALIGNED" if game.arch_state == 0 else "UNALIGNED"))
	connection.text = game.carrier_connection_text() if game.selected == 0 else ("Connections settle after the turn." if game.busy else ("The two corridors are aligned." if game.arch_state == 0 else "The corridors are unaligned."))
	var current_guide: Dictionary = game.guidance()
	guide_title.text = current_guide.title
	guide_body.text = current_guide.text
	guide.visible = contextual_guidance and not game.paused and not game.won
	chapter_title.text = "03   /   THE JOINED GALLERIES" if game.reached_court else ("02   /   THE FOLDED LANDING" if game.boarded else "01   /   THE PASSENGER")
	if game.walker.support == game.destination:
		task.text = "Reach the light"
	elif game.walker.support == game.courtyard:
		task.text = "Cross the joined galleries" if game.arch_state == 0 else "Align the galleries"
	elif game.walker.support == game.carrier:
		task.text = "Reach the violet landing" if game.carrier.state == 1 else "Travel with the deck"
	else:
		task.text = "Return to the deck" if game.boarded else "Board the carrier"
	var face: String = "walkway"
	status.text = "GROUND  /  " + game.walker.support.title + " · " + face + ("  ·  transforming" if game.busy else "")
	toast.text = game.message if game.message_time > 0 else ""
	toast.offset_left = -220 if game.architectural else -420
	toast.offset_right = 600 if game.architectural else 420
	toast.visible = not game.paused and not game.won
	var view_key: String = game.key_name("view")
	controls.text = view_key + "  " + ("Enter the world" if game.architectural else "Architectural view") + "     /     "
	var walk_keys: String = game.key_name("forward") + game.key_name("left") + game.key_name("back") + game.key_name("right")
	controls.text += (game.key_name("rotate_left") + " · " + game.key_name("rotate_right") + "  Rotate" if game.architectural else walk_keys + ("  Walk  ·  Mouse  Orbit" if game.walker.third_person else "  Walk  ·  Mouse  Look"))
	controls.text += "     /     " + game.key_name("undo") + "  Undo     /     " + game.key_name("hint") + "  Hint     /     Esc  Pause"

func show_menu(value: bool) -> void:
	menu.visible = value
	if not value:
		rebind_action = ""

func show_completion() -> void:
	completion.show()

func begin_rebind(action: String) -> void:
	if rebind_action != "":
		key_buttons[rebind_action].text = game.key_name(rebind_action)
	rebind_action = action
	rebind_button = key_buttons[action]
	rebind_button.text = "…"

func _input(event: InputEvent) -> void:
	if rebind_action == "" or not event is InputEventKey or not event.pressed:
		return
	get_viewport().set_input_as_handled()
	if event.keycode != KEY_ESCAPE and event.keycode not in [KEY_1, KEY_2]:
		# Swap duplicates so remapping cannot silently disable another action.
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		var old: int = game.input_bindings[rebind_action]
		for action in game.input_bindings:
			if action != rebind_action and game.input_bindings[action] == code:
				game.bind_key(action, old)
				key_buttons[action].text = game.key_name(action)
		game.bind_key(rebind_action, code)
	rebind_button.text = game.key_name(rebind_action)
	rebind_action = ""
	save_settings()

func save_settings() -> void:
	var settings := ConfigFile.new()
	settings.set_value("comfort", "reduced_motion", game.walker.reduced_motion)
	settings.set_value("comfort", "sensitivity", game.walker.sensitivity)
	settings.set_value("comfort", "third_person", game.walker.third_person)
	settings.set_value("comfort", "camera_distance", game.walker.camera_distance)
	settings.set_value("comfort", "keep_world_horizon", game.walker.keep_world_horizon)
	settings.set_value("interface", "contextual_guidance", contextual_guidance)
	for action in game.input_bindings:
		settings.set_value("keys", action, game.input_bindings[action])
	settings.save("user://settings.cfg")

func load_settings() -> void:
	var settings := ConfigFile.new()
	if settings.load("user://settings.cfg") != OK:
		return
	game.walker.reduced_motion = settings.get_value("comfort", "reduced_motion", false)
	game.walker.sensitivity = settings.get_value("comfort", "sensitivity", 0.0022)
	game.walker.third_person = settings.get_value("comfort", "third_person", true)
	game.walker.camera_distance = clampf(settings.get_value("comfort", "camera_distance", 5.5), 3.0, 8.0)
	game.walker.keep_world_horizon = settings.get_value("comfort", "keep_world_horizon", false)
	contextual_guidance = settings.get_value("interface", "contextual_guidance", true)
	menu.find_child("ContextualGuidance", true, false).set_pressed_no_signal(contextual_guidance)
	menu.find_child("WorldHorizon", true, false).set_pressed_no_signal(game.walker.keep_world_horizon)
	menu.find_child("CameraMode", true, false).select(0 if game.walker.third_person else 1)
	menu.find_child("CameraDistance", true, false).set_value_no_signal(game.walker.camera_distance)
	game.walker.sync_pose(1.0)
	menu.find_child("ReducedMotion", true, false).set_pressed_no_signal(game.walker.reduced_motion)
	menu.find_child("Sensitivity", true, false).set_value_no_signal(game.walker.sensitivity)
