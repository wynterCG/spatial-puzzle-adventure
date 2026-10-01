extends CanvasLayer
## Minimal player HUD (spec §33): the question, feedback and controls. Ground/connection
## details are developer information, shown only while debug is toggled with F3.
const MONUMENT_DIR := "res://monuments/"
var game: Node3D
var debug := false
var root: Control
var title: Label
var mode: Label
var question: Label
var status: Label
var controls: Label
var feedback: Label
var menu: PanelContainer
var finish: PanelContainer
var finish_title: Label
var explanation: Label
var reflection: Label
var reflection_button: Button
var reduced: CheckButton
var sensitivity: HSlider

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
	top.add_child(label("E L S E W H E R E", 12))
	title = label("", 30)
	top.add_child(title)
	mode = label("", 14)
	top.add_child(mode)
	question = label("", 19)
	top.add_child(question)
	status = label("", 14)
	top.add_child(status)
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
	menu = panel(Vector2(-280, -330), Vector2(560, 660), Control.PRESET_CENTER)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	column.add_child(label("Take a moment", 27))
	column.add_child(label("Monuments", 15))
	for scene in monument_scenes():
		column.add_child(button(scene.get_file().get_basename().capitalize(), func(): game.open_level(scene)))
	column.add_child(label("Isometric view", 15))
	column.add_child(label("Wheel: zoom  /  Home: reset zoom", 14))
	column.add_child(button("Reset zoom", func(): game.reset_overview()))
	column.add_child(label("Comfort", 15))
	reduced = CheckButton.new()
	reduced.text = "Reduced motion"
	reduced.toggled.connect(func(value): game.walker.reduced_motion = value; game.save_preferences())
	column.add_child(reduced)
	column.add_child(label("Look sensitivity", 15))
	sensitivity = HSlider.new()
	sensitivity.min_value = 0.0005
	sensitivity.max_value = 0.006
	sensitivity.step = 0.0001
	sensitivity.value_changed.connect(func(value): game.walker.sensitivity = value; game.save_preferences())
	column.add_child(sensitivity)
	column.add_child(button("Restart this monument", func(): game.restart(); game.set_pause(false)))
	reflection_button = button("View puzzle reflection", func(): game.show_reflection())
	column.add_child(reflection_button)
	column.add_child(button("Continue", func(): game.set_pause(false)))
	finish = panel(Vector2(-290, -160), Vector2(580, 320), Control.PRESET_CENTER)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	finish.add_child(column)
	finish_title = label("", 28)
	column.add_child(finish_title)
	reflection = label("", 20)
	column.add_child(reflection)
	explanation = label("", 17)
	column.add_child(explanation)
	column.add_child(button("Compare your explanation", func(): explanation.visible = true))
	column.add_child(button("Look back / keep exploring", func(): game.continue_exploring()))
	column.add_child(button("Choose another monument", func(): game.set_pause(true)))
	column.add_child(button("Try this monument again", func(): game.restart()))

static func monument_scenes() -> Array[String]:
	var scenes: Array[String] = []
	for file in DirAccess.get_files_at(MONUMENT_DIR):
		# Exported builds list remapped scenes.
		file = file.trim_suffix(".remap")
		if file.ends_with(".tscn") and not scenes.has(MONUMENT_DIR + file): scenes.append(MONUMENT_DIR + file)
	scenes.sort()
	return scenes

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
	reduced.set_pressed_no_signal(game.walker.reduced_motion)
	sensitivity.set_value_no_signal(game.walker.sensitivity)

func refresh() -> void:
	if game.walker.support == null:
		return
	title.text = game.puzzle_title()
	mode.text = "ARCHITECT  /  arrange the space" if game.architectural else "INHABITANT  /  first person"
	question.text = game.puzzle_question()
	status.visible = debug
	status.text = game.connection_text() if debug else ""
	menu.visible = game.paused
	if game.won and not finish.visible:
		explanation.visible = false
	finish.visible = game.won and game.finish_open and not game.paused
	reflection_button.visible = game.won
	finish_title.text = game.puzzle_title()
	reflection.text = "Before continuing: " + game.puzzle_question()
	explanation.text = game.puzzle_reason()
	feedback.text = game.message
	feedback.visible = not game.paused and not game.blocks_play()
	controls.text = game.key_name("view") + "  Change view  /  "
	if game.architectural:
		controls.text += "Click  Select  /  " + game.key_name("rotate_left") + " · " + game.key_name("rotate_right") + "  Turn  /  Wheel  Zoom  /  " + game.key_name("reset_view") + "  Reset zoom  /  "
	else:
		controls.text += game.key_name("forward") + game.key_name("left") + game.key_name("back") + game.key_name("right") + "  Walk  /  Mouse  Look  /  "
	controls.text += game.key_name("undo") + "  Undo  /  " + game.key_name("reset") + "  Restart  /  " + game.key_name("hint") + "  Hint  /  F3  Debug  /  Esc  Settings"
