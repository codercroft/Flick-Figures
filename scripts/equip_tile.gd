class_name EquipTile
extends Button
## One stored equipment item in the Inventory's grid. Tap it to read it; press and drag it onto a figure in the
## roster to equip it (the roster accepts the drop). `locked` (in combat) turns dragging off.

var item: EquipmentData
var locked := false


func setup(equipment: EquipmentData, tile_size: float) -> void:
	item = equipment
	custom_minimum_size = Vector2(tile_size, tile_size)
	text = "%s\n%s" % [equipment.label, equipment.display_name]
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_theme_font_size_override("font_size", 24)
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = equipment.color.darkened(0.2) if state != "pressed" else equipment.color
		box.set_corner_radius_all(18)
		box.set_border_width_all(4)
		box.border_color = equipment.color.lightened(0.3)
		add_theme_stylebox_override(state, box)


func _get_drag_data(_at_position: Vector2):
	if locked or item == null:
		return null
	var preview := Label.new()
	preview.text = "  %s %s  " % [item.label, item.display_name]
	preview.add_theme_font_size_override("font_size", 34)
	preview.add_theme_color_override("font_color", Color.WHITE)
	var box := StyleBoxFlat.new()
	box.bg_color = item.color.darkened(0.3)
	box.set_corner_radius_all(14)
	preview.add_theme_stylebox_override("normal", box)
	set_drag_preview(preview)
	return {"equipment": item}
