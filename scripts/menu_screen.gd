class_name MenuScreen
extends Control
## The shared layout of the menu-side screens (Run History, Compendium): a dark background, a title, a
## scrolling `content` list in the middle and `actions` buttons pinned to the bottom (thumb reach). Unlike
## ScreenFrame it has no status bar, because there is no run to show. Subclass it and fill `content`.

const BACKGROUND := Color(0.07, 0.08, 0.12)

var title := Label.new()
var scroll := ScrollContainer.new()
var content := VBoxContainer.new()
var actions := VBoxContainer.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var insets := SafeArea.insets()
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 36.0 + insets.left
	column.offset_right = -(36.0 + insets.right)
	column.offset_top = 24.0 + insets.top
	column.offset_bottom = -(24.0 + insets.bottom)
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	actions.add_theme_constant_override("separation", 10)
	column.add_child(actions)
	build()


## Override: fill title, content and actions.
func build() -> void:
	pass


func clear_content() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()


func clear_actions() -> void:
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()


func add_action(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 96.0)
	button.add_theme_font_size_override("font_size", 40)
	button.pressed.connect(callback)
	actions.add_child(button)
	return button


func add_heading(text: String, size := 42) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.98))
	content.add_child(label)
	return label


func add_text(text: String, size := 32, color := Color(0.78, 0.81, 0.9)) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	content.add_child(label)
	return label


func go_to_menu() -> void:
	get_tree().change_scene_to_file(NodeScenes.MENU_SCENE)
