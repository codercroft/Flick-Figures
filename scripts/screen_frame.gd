class_name ScreenFrame
extends Control
## The common layout of the choice screens (rewards, shop, equip, upgrades): the status bar on top, a
## title, the content (cards) scrolling in the MIDDLE of the screen, and the action buttons (skip,
## take, back, leave) pinned at the bottom where a thumb reaches them. Everything is anchored, so it
## fills any phone aspect ratio, and it stays clear of the camera cutout and gesture bar.
## Add it with `frame = ScreenFrame.new(); add_child(frame)` and use frame.title, frame.subtitle,
## frame.content (put cards here) and frame.actions (put buttons here).

var top_bar := TopBar.new()
var title := Label.new()
var subtitle := Label.new()
var scroll := ScrollContainer.new()
var content := VBoxContainer.new()
var actions := VBoxContainer.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_bar)
	var insets := SafeArea.insets()
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 36.0 + insets.left
	column.offset_right = -(36.0 + insets.right)
	column.offset_top = TopBar.height() + 16.0
	column.offset_bottom = -(24.0 + insets.bottom)
	column.add_theme_constant_override("separation", 12)
	add_child(column)

	title.add_theme_font_size_override("font_size", 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)

	subtitle.add_theme_font_size_override("font_size", 34)
	subtitle.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(subtitle)

	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)

	actions.add_theme_constant_override("separation", 10)
	column.add_child(actions)


func _process(_delta: float) -> void:
	subtitle.visible = subtitle.text != ""


## Removes everything from the content list and the action buttons.
func clear() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()


## A big button in the bottom action area.
func add_action(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 96.0)
	button.add_theme_font_size_override("font_size", 40)
	button.pressed.connect(callback)
	actions.add_child(button)
	return button
