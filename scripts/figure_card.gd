class_name FigureCard
extends Button
## A big tappable button showing a figure's picture, name and description.

var data: FigureData


## `text_override` replaces the default "name + description" text (the shop adds prices).
## `figure_data` may be null for a card with no picture.
func setup(figure_data: FigureData, card_height: float, text_override := "") -> void:
	data = figure_data
	custom_minimum_size = Vector2(0.0, card_height)
	if text_override != "":
		text = text_override
	else:
		text = "%s\n%s" % [data.display_name, data.description]
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_theme_font_size_override("font_size", 40 if text_override == "" else 32)
	# Leave room on the left for the figure's picture.
	add_theme_stylebox_override("normal", _box(Color(0.2, 0.22, 0.28), card_height))
	add_theme_stylebox_override("hover", _box(Color(0.26, 0.28, 0.36), card_height))
	add_theme_stylebox_override("pressed", _box(Color(0.34, 0.37, 0.48), card_height))
	add_theme_stylebox_override("focus", _box(Color(0.26, 0.28, 0.36), card_height))
	add_theme_stylebox_override("disabled", _box(Color(0.14, 0.15, 0.19), card_height))
	add_theme_color_override("font_disabled_color", Color(0.5, 0.52, 0.58))


func _box(background: Color, card_height: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.set_corner_radius_all(24)
	box.content_margin_left = card_height * 1.15 if data != null else 28.0
	box.content_margin_right = 24.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box


func _draw() -> void:
	if data == null:
		return
	var radius := size.y * 0.32
	var center := Vector2(size.y * 0.55, size.y * 0.5)
	draw_circle(center, radius, data.color)
	draw_arc(center, radius - 4.0, 0.0, TAU, 48, Figure.PLAYER_RING, 8.0, true)
	draw_circle(center + Vector2(-radius, -radius) * 0.3, radius * 0.22, data.color.lightened(0.4))
	var label := data.label if data.label != "" else data.display_name.left(1)
	var ink := data.color.darkened(0.5)
	var font_size := int(radius * (1.0 if label.length() <= 1 else 0.75))
	if data.icon == FigureIcons.Icon.NONE:
		draw_string(ThemeDB.fallback_font, center + Vector2(-radius, font_size * 0.35), label,
				HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, ink)
	else:
		font_size = int(font_size * 0.8)
		draw_string(ThemeDB.fallback_font, center + Vector2(-radius, -radius * 0.08), label,
				HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, ink)
		FigureIcons.draw(self, data.icon, center + Vector2(0.0, radius * 0.46), radius * 0.3, ink)
