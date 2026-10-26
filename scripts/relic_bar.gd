class_name RelicBar
extends HBoxContainer
## A row of small round relic icons for the top bar. Tapping one opens the run info overlay on that
## relic. If there are more than `max_icons`, the rest collapse into a "+N" button.

@export var max_icons := 8
@export var icon_size := 50.0


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	refresh()


## Rebuilds the icons from RunManager.relics.
func refresh() -> void:
	for child in get_children():
		child.queue_free()
	var shown := mini(RunManager.relics.size(), max_icons)
	for i in shown:
		var relic: RelicData = RunManager.relics[i]
		var button := _icon_button(relic.label, relic.color)
		button.pressed.connect(RunInfo.open.bind("relics", relic))
		add_child(button)
	if RunManager.relics.size() > shown:
		var more := _icon_button("+%d" % (RunManager.relics.size() - shown), Color(0.4, 0.43, 0.52))
		more.pressed.connect(RunInfo.open.bind("relics", null))
		add_child(more)


func _icon_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(icon_size, icon_size)
	button.add_theme_font_size_override("font_size", int(icon_size * 0.44))
	for style_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(style_name, Color(0.1, 0.1, 0.12))
	for style_name in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = color
		box.set_corner_radius_all(int(icon_size / 2.0))
		box.set_border_width_all(3)
		box.border_color = Color(0.1, 0.1, 0.12)
		button.add_theme_stylebox_override(style_name, box)
	return button
