class_name FigureBadge
extends Control
## A figure's picture (colored disc, ring, label and icon, like on the table), or a dark "???" silhouette when
## `locked`. Used by the Compendium grid and the figure page. Set `data` and `locked`, give it a size.

var data: FigureData:
	set(value):
		data = value
		queue_redraw()
## Small extras like on the table: a gold pip for a figure-specific upgrade, the equipment's badge label.
var upgraded := false:
	set(value):
		upgraded = value
		queue_redraw()
var item_label := "":
	set(value):
		item_label = value
		queue_redraw()
var locked := false:
	set(value):
		locked = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if data == null:
		return
	var radius := minf(size.x, size.y) * 0.4
	var center := size / 2.0
	var font := ThemeDB.fallback_font
	if locked:
		draw_circle(center, radius, Color(0.03, 0.03, 0.05))
		draw_arc(center, radius - 4.0, 0.0, TAU, 48, Color(0.16, 0.17, 0.22), 6.0, true)
		var font_size := int(radius * 0.8)
		draw_string(font, center + Vector2(-radius, font_size * 0.35), "???", HORIZONTAL_ALIGNMENT_CENTER,
				radius * 2.0, font_size, Color(0.3, 0.32, 0.4))
		return
	draw_circle(center, radius, data.color)
	draw_arc(center, radius - 4.0, 0.0, TAU, 48, Figure.PLAYER_RING, 8.0, true)
	if upgraded:
		draw_circle(center + Vector2(radius, -radius) * 0.7, radius * 0.14, Color(1.0, 0.82, 0.25))
	if item_label != "":
		var badge_center := center + Vector2(radius, radius) * 0.7
		draw_circle(badge_center, radius * 0.26, Color(0.1, 0.1, 0.14, 0.9))
		draw_string(ThemeDB.fallback_font, badge_center + Vector2(-radius * 0.26, radius * 0.1), item_label,
				HORIZONTAL_ALIGNMENT_CENTER, radius * 0.52, int(radius * 0.3), Color.WHITE)
	draw_circle(center + Vector2(-radius, -radius) * 0.3, radius * 0.22, data.color.lightened(0.4))
	var label := data.label if data.label != "" else data.display_name.left(1)
	var ink := data.color.darkened(0.5)
	var label_size := int(radius * (1.0 if label.length() <= 1 else 0.75))
	if data.icon == FigureIcons.Icon.NONE:
		draw_string(font, center + Vector2(-radius, label_size * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER,
				radius * 2.0, label_size, ink)
	else:
		label_size = int(label_size * 0.8)
		draw_string(font, center + Vector2(-radius, -radius * 0.08), label, HORIZONTAL_ALIGNMENT_CENTER,
				radius * 2.0, label_size, ink)
		FigureIcons.draw(self, data.icon, center + Vector2(0.0, radius * 0.46), radius * 0.3, ink)
