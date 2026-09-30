extends CanvasLayer
var game: Node3D
var root: Control
var title: Label
var mode: Label
var question: Label
var status: Label
var selected_label: Label
var controls: Label
var feedback: Label
var sidebar: PanelContainer
var menu: PanelContainer
var finish: PanelContainer
var explanation: Label
var reflection: Label
var camera_choice: OptionButton
var world_camera: CheckButton
var reduced: CheckButton
var distance: HSlider
var sensitivity: HSlider
var selectors: Array[Button] = []

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 17
	theme.set_color("font_color", "Label", Color("f1e7d5"))
	theme.set_color("font_color", "Button", Color("f1e7d5"))
	for state in ["normal", "hover", "pressed"]:
		theme.set_stylebox(state, "Button", style(Color("354158") if state != "normal" else Color("253149")))
	root.theme = theme
	var top := VBoxContainer.new()
	root.add_child(top)
	top.position = Vector2(38, 28)
	top.custom_minimum_size.x = 760
	top.add_child(label("E L S E W H E R E   /   P O S I T I O N I N G   S T U D I E S", 12))
	title = label("", 32)
	top.add_child(title)
	mode = label("", 14)
	top.add_child(mode)
	var right := panel(Vector2(-375, 34), Vector2(337, 146), Control.PRESET_TOP_RIGHT)
	var column := VBoxContainer.new()
	right.add_child(column)
	question = label("", 19)
	column.add_child(question)
	status = label("", 14)
	column.add_child(status)
	sidebar = panel(Vector2(38, -266), Vector2(310, 175), Control.PRESET_BOTTOM_LEFT)
	column = VBoxContainer.new()
	sidebar.add_child(column)
	column.add_child(label("RECONFIGURE", 12))
	selected_label = label("", 21)
	column.add_child(selected_label)
	var row := HBoxContainer.new()
	column.add_child(row)
	for index in range(2):
		var choice := button(str(index + 1), func(): game.select_rig(index))
		selectors.append(choice)
		row.add_child(choice)
	row = HBoxContainer.new()
	column.add_child(row)
	row.add_child(button("Turn left", func(): game.rotate_selected(-1)))
	row.add_child(button("Turn right", func(): game.rotate_selected(1)))
	feedback = label("", 17)
	root.add_child(feedback)
	feedback.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	feedback.offset_left = -820
	feedback.offset_right = -38
	feedback.offset_top = -130
	feedback.offset_bottom = -86
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var bottom := panel(Vector2(38, -65), Vector2(1364, 40), Control.PRESET_BOTTOM_LEFT)
	controls = label("", 14)
	bottom.add_child(controls)
	menu = panel(Vector2(-280, -355), Vector2(560, 710), Control.PRESET_CENTER)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(scroll)
	column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	column.add_child(label("Take a moment", 27))
	column.add_child(label("Choose a study", 15))
	for index in range(3):
		column.add_child(button(str(index + 1) + "  " + game.TITLES[index], func(): game.load_trial(index); game.save_progress()))
	column.add_child(label("Traversal camera", 15))
	camera_choice = OptionButton.new()
	camera_choice.add_item("Third person")
	camera_choice.add_item("First person")
	camera_choice.item_selected.connect(func(index): game.walker.set_third_person(index == 0); game.save_preferences())
	column.add_child(camera_choice)
	world_camera = CheckButton.new()
	world_camera.text = "World-aligned camera (character can turn upside down)"
	world_camera.toggled.connect(func(value): game.walker.keep_world_horizon = value; game.walker.camera_initialized = false; game.walker.sync_pose(1); game.save_preferences())
	column.add_child(world_camera)
	reduced = CheckButton.new()
	reduced.text = "Reduced motion"
	reduced.toggled.connect(func(value): game.walker.reduced_motion = value; game.save_preferences())
	column.add_child(reduced)
	column.add_child(label("Follow distance", 15))
	distance = HSlider.new()
	distance.min_value = 3
	distance.max_value = 8
	distance.step = 0.25
	distance.value_changed.connect(func(value): game.walker.camera_distance = value; game.save_preferences())
	column.add_child(distance)
	column.add_child(label("Look sensitivity", 15))
	sensitivity = HSlider.new()
	sensitivity.min_value = 0.0005
	sensitivity.max_value = 0.006
	sensitivity.step = 0.0001
	sensitivity.value_changed.connect(func(value): game.walker.sensitivity = value; game.save_preferences())
	column.add_child(sensitivity)
	column.add_child(button("Optional: original gallery experiment", func(): game.open_gallery()))
	column.add_child(button("Restart this study", func(): game.restart(); game.set_pause(false)))
	column.add_child(button("Continue", func(): game.set_pause(false)))
	finish = panel(Vector2(-290, -160), Vector2(580, 320), Control.PRESET_CENTER)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	finish.add_child(column)
	column.add_child(label("Connection reached", 28))
	reflection = label("", 20)
	column.add_child(reflection)
	explanation = label("", 17)
	column.add_child(explanation)
	column.add_child(button("Compare your explanation", func(): explanation.visible = true))
	column.add_child(button("Next study / return to first", func(): game.load_trial((game.trial + 1) % 3); game.save_progress()))
	column.add_child(button("Try this study again", func(): game.restart()))

func style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(8)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

func panel(at: Vector2, size: Vector2, anchor: int) -> PanelContainer:
	var node := PanelContainer.new()
	root.add_child(node)
	node.set_anchors_and_offsets_preset(anchor)
	node.offset_left = at.x
	node.offset_top = at.y
	node.offset_right = at.x + size.x
	node.offset_bottom = at.y + size.y
	node.add_theme_stylebox_override("panel", style(Color(0.045, 0.067, 0.12, 0.96)))
	return node

func label(text: String, size: int) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func button(text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.pressed.connect(action)
	return node

func sync_preferences() -> void:
	camera_choice.select(0 if game.walker.third_person else 1)
	world_camera.set_pressed_no_signal(game.walker.keep_world_horizon)
	reduced.set_pressed_no_signal(game.walker.reduced_motion)
	distance.set_value_no_signal(game.walker.camera_distance)
	sensitivity.set_value_no_signal(game.walker.sensitivity)

func refresh() -> void:
	if game.rigs.is_empty():
		return
	title.text = "%02d  /  %s" % [game.trial + 1, game.TITLES[game.trial]]
	mode.text = "ARCHITECT  /  arrange the space" if game.architectural else ("INHABITANT  /  third person" if game.walker.third_person else "INHABITANT  /  first person")
	question.text = game.QUESTIONS[game.trial]
	status.text = game.connection_text()
	selected_label.text = game.rigs[game.selected].label
	for i in range(selectors.size()):
		selectors[i].visible = i < game.rigs.size()
		if i < game.rigs.size():
			selectors[i].text = str(i + 1) + "  " + game.rigs[i].label
	sidebar.visible = game.architectural and not game.paused and not game.won
	menu.visible = game.paused
	if game.won and not finish.visible:
		explanation.visible = false
	finish.visible = game.won and not game.paused
	reflection.text = "Before continuing: " + game.QUESTIONS[game.trial]
	explanation.text = game.REASONS[game.trial]
	feedback.text = game.message
	feedback.visible = not game.paused and not game.won
	controls.text = game.key_name("view") + "  Change view     /     " + game.key_name("forward") + game.key_name("left") + game.key_name("back") + game.key_name("right") + "  Walk     /     Mouse  Look     /     " + game.key_name("rotate_left") + " · " + game.key_name("rotate_right") + "  Turn     /     " + game.key_name("undo") + "  Undo     /     " + game.key_name("reset") + "  Restart     /     " + game.key_name("hint") + "  Hint     /     Esc  Studies & settings"
