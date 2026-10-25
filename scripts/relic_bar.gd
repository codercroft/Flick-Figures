class_name RelicBar
extends VBoxContainer
## A row of small relic icons. Tap one to read what it does (tap again to hide). Used on the map
## and at the top of the bottom bar in combat.

## True puts the description above the row (for the bottom bar), false below it.
@export var description_above := false

var _row := HBoxContainer.new()
var _description := Label.new()
var _shown: RelicData


func _ready() -> void:
	_row.add_theme_constant_override("separation", 8)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.add_theme_font_size_override("font_size", 30)
	_description.add_theme_color_override("font_outline_color", Color.BLACK)
	_description.add_theme_constant_override("outline_size", 8)
	_description.visible = false
	_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	if description_above:
		add_child(_description)
		move_child(_description, 0)
	else:
		add_child(_description)
	refresh()


## Rebuilds the icons from RunManager.relics.
func refresh() -> void:
	for child in _row.get_children():
		child.queue_free()
	for relic in RunManager.relics:
		var button := Button.new()
		button.text = relic.label
		button.custom_minimum_size = Vector2(56.0, 56.0)
		button.add_theme_font_size_override("font_size", 24)
		button.add_theme_color_override("font_color", Color(0.1, 0.1, 0.12))
		button.add_theme_color_override("font_hover_color", Color(0.1, 0.1, 0.12))
		button.add_theme_color_override("font_pressed_color", Color(0.1, 0.1, 0.12))
		for style_name in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(style_name, _icon_box(relic.color))
		button.pressed.connect(_on_relic_pressed.bind(relic))
		_row.add_child(button)


## True if a screen position is over the icons or the open description.
func is_over(screen_pos: Vector2) -> bool:
	if not is_visible_in_tree():
		return false
	return get_global_rect().has_point(screen_pos) and (_row.get_child_count() > 0 or _description.visible)


func _on_relic_pressed(relic: RelicData) -> void:
	if _shown == relic and _description.visible:
		_description.visible = false
		_shown = null
		return
	_shown = relic
	_description.text = "%s: %s" % [relic.display_name, relic.description]
	_description.visible = true


func _icon_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(28)
	box.set_border_width_all(3)
	box.border_color = Color(0.1, 0.1, 0.12)
	return box
