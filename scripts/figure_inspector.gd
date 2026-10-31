class_name FigureInspector
extends PanelContainer
## THE SLOT FOR A FUTURE 3D MODEL VIEWER on a figure's Compendium page. Today it is a clearly marked empty box.
## To add the 3D view later: keep this class and its API, and replace `_build_placeholder()` with a
## SubViewportContainer > SubViewport > (Node3D with a Camera3D, a light and the model) that turns by dragging;
## `show_figure(data)` is where the model for that figure should be loaded (a scene path on FigureData, for
## example). Nothing else (the page, the grid) needs to change.

## How tall the viewer area is (game units).
@export var viewer_height := 520.0

var _caption := Label.new()


func _ready() -> void:
	custom_minimum_size = Vector2(0.0, viewer_height)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.11, 0.16)
	box.set_corner_radius_all(20)
	box.set_border_width_all(4)
	box.border_color = Color(0.35, 0.38, 0.5)
	add_theme_stylebox_override("panel", box)
	_build_placeholder()


## Called by the figure page with the figure to inspect.
func show_figure(figure: FigureData) -> void:
	_caption.text = "3D MODEL VIEWER\n(coming soon)\n\n%s" % figure.display_name


func _build_placeholder() -> void:
	_caption.text = "3D MODEL VIEWER\n(coming soon)"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 38)
	_caption.add_theme_color_override("font_color", Color(0.5, 0.53, 0.65))
	add_child(_caption)
