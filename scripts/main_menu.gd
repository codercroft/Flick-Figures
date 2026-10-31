extends Control
## The first screen: the title and the buttons Continue (only with a saved run), New Run (asks first if it
## would replace a saved run), Compendium, Run History and Settings. Built in code like the other screens.
## Placeholder styling: a dark background and plain colored buttons.

const BACKGROUND := Color(0.07, 0.08, 0.12)
const TITLE_COLOR := Color(1.0, 0.82, 0.25)

## Button size (game units; the viewport is 1080 wide).
@export var button_width := 760.0
@export var button_height := 120.0

var _root := VBoxContainer.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var insets := SafeArea.insets()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.offset_left = 40.0 + insets.left
	_root.offset_right = -(40.0 + insets.right)
	_root.offset_top = 40.0 + insets.top
	_root.offset_bottom = -(60.0 + insets.bottom)
	_root.add_theme_constant_override("separation", 22)
	add_child(_root)
	_show_main()


# --- Screens -----------------------------------------------------------------------------

func _clear() -> void:
	for child in _root.get_children():
		_root.remove_child(child)
		child.queue_free()


func _title() -> void:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = 0.8
	_root.add_child(spacer)
	_label("Flick Figures", 124, TITLE_COLOR)
	_label("a tabletop roguelike", 36, Color(0.6, 0.64, 0.75))


func _show_main() -> void:
	_clear()
	_title()
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(spacer)
	if RunManager.has_saved_run():
		_button("Continue", Color(0.25, 0.65, 0.4), _on_continue)
	_button("New Run", Color(0.25, 0.5, 0.85), _on_new_run)
	_button("Compendium", Color(0.55, 0.4, 0.8), _show_placeholder.bind("Compendium", "Every figure, relic and power you have found will be listed here."))
	_button("Run History", Color(0.8, 0.5, 0.25), _show_placeholder.bind("Run History", "Your past runs will be listed here."))
	_button("Settings", Color(0.45, 0.48, 0.58), _show_settings)


func _show_confirm_new_run() -> void:
	_clear()
	_title()
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(spacer)
	_label("Start a new run?", 56, Color.WHITE)
	_label("Your saved run will be lost.", 38, Color(1.0, 0.6, 0.5))
	_button("Yes, start a new run", Color(0.8, 0.35, 0.3), _start_new_run)
	_button("No, go back", Color(0.45, 0.48, 0.58), _show_main)


func _show_placeholder(heading: String, text: String) -> void:
	_clear()
	_title()
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(spacer)
	_label(heading, 64, Color.WHITE)
	_label(text, 34, Color(0.7, 0.73, 0.82))
	_label("(coming soon)", 34, Color(0.5, 0.53, 0.62))
	_button("Back", Color(0.45, 0.48, 0.58), _show_main)


func _show_settings() -> void:
	_clear()
	_title()
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(spacer)
	_label("Settings", 64, Color.WHITE)
	_slider("Game sounds", AudioManager.sfx_volume, AudioManager.set_sfx_volume, func(): AudioManager.play_clack(1200.0))
	_slider("Menu sounds", AudioManager.ui_volume, AudioManager.set_ui_volume, AudioManager.play_confirm)
	var mute := CheckButton.new()
	mute.text = "Mute all sound"
	mute.button_pressed = AudioManager.muted
	mute.custom_minimum_size = Vector2(button_width, 90.0)
	mute.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mute.add_theme_font_size_override("font_size", 40)
	mute.toggled.connect(func(on: bool):
		if on != AudioManager.muted:
			AudioManager.toggle_mute())
	_root.add_child(mute)
	_button("Back", Color(0.45, 0.48, 0.58), _show_main)


# --- Actions -----------------------------------------------------------------------------

func _on_continue() -> void:
	var pending := RunManager.load_saved_run()
	if pending == -2:
		_show_placeholder("Save not found", "The saved run could not be loaded.")
		return
	if pending >= 0 and RunManager.enter_node(pending):
		NodeScenes.open_current_node(get_tree())  # quit inside a node: it starts again from the beginning
	else:
		get_tree().change_scene_to_file(NodeScenes.MAP_SCENE)


func _on_new_run() -> void:
	if RunManager.has_saved_run():
		_show_confirm_new_run()
	else:
		_start_new_run()


func _start_new_run() -> void:
	RunSave.delete()
	RunManager.start_new_run()
	get_tree().change_scene_to_file(NodeScenes.MAP_SCENE)


# --- Little builders ---------------------------------------------------------------------

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	_root.add_child(label)
	return label


func _button(text: String, color: Color, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(button_width, button_height)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 46)
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = color.lightened(0.15) if state == "pressed" else color
		box.set_corner_radius_all(22)
		box.set_border_width_all(3)
		box.border_color = color.lightened(0.35)
		button.add_theme_stylebox_override(state, box)
	button.pressed.connect(action)
	_root.add_child(button)
	return button


func _slider(text: String, value: float, on_change: Callable, preview: Callable) -> void:
	_label(text, 36, Color(0.8, 0.83, 0.9))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(button_width, 60.0)
	slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(on_change)
	slider.drag_ended.connect(func(_changed: bool): preview.call())
	_root.add_child(slider)
