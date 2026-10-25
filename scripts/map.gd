extends Control
## The run map, shown before each combat: nodes from bottom to top (the combats, then the boss).
## Done nodes are checked, the current node glows, and tapping it starts the combat.
## Placeholder shapes and text for now. All of it sits in the bottom half of the screen.

const COMBAT_SCENE := "res://scenes/main.tscn"
const SHOP_SCENE := "res://scenes/shop.tscn"
const EQUIP_SCENE := "res://scenes/equip.tscn"
const UPGRADE_SCENE := "res://scenes/upgrade.tscn"
const SHOP_RADIUS := 48.0
const COMBAT_RADIUS := 60.0
const BOSS_RADIUS := 80.0

@export var done_color := Color(0.3, 0.5, 0.36)
@export var current_color := Color(1.0, 0.85, 0.3)
@export var future_color := Color(0.25, 0.27, 0.33)
@export var line_color := Color(0.4, 0.43, 0.52)
@export var text_color := Color(0.9, 0.92, 0.97)
@export var dim_text_color := Color(0.6, 0.63, 0.72)
@export var money_color := Color(1.0, 0.82, 0.25)

var _time := 0.0


func _ready() -> void:
	# The relic icons sit in a row at the top of the map (the bottom half of the screen).
	var relics := RelicBar.new()
	relics.anchor_right = 1.0
	relics.anchor_top = 0.5
	relics.anchor_bottom = 0.5
	relics.offset_left = 24.0
	relics.offset_right = -24.0
	relics.offset_top = 8.0
	relics.offset_bottom = 64.0
	relics.name = "RelicBar"
	add_child(relics)
	# The equip screen button sits at the bottom right, in thumb reach.
	var button := Button.new()
	var held := RunManager.equipment_inventory.size()
	button.text = "Equipment (%d)" % held
	button.add_theme_font_size_override("font_size", 34)
	if held > 0:
		button.add_theme_color_override("font_color", money_color)
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = -300.0
	button.offset_right = -24.0
	button.offset_top = -210.0
	button.offset_bottom = -120.0
	button.pressed.connect(func(): get_tree().change_scene_to_file(EQUIP_SCENE))
	add_child(button)
	if RunManager.config.show_upgrade_screen:
		var upgrades := Button.new()
		upgrades.text = "Upgrades"
		upgrades.add_theme_font_size_override("font_size", 34)
		upgrades.anchor_left = 1.0
		upgrades.anchor_right = 1.0
		upgrades.anchor_top = 1.0
		upgrades.anchor_bottom = 1.0
		upgrades.offset_left = -300.0
		upgrades.offset_right = -24.0
		upgrades.offset_top = -310.0
		upgrades.offset_bottom = -220.0
		upgrades.pressed.connect(func(): get_tree().change_scene_to_file(UPGRADE_SCENE))
		add_child(upgrades)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()  # the current node pulses


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if RunManager.shop_available() and event.position.distance_to(_shop_center()) <= SHOP_RADIUS + 30.0:
			get_tree().change_scene_to_file(SHOP_SCENE)
			return
		var current := RunManager.combat_index
		if event.position.distance_to(_node_center(current)) <= _node_radius(current) + 30.0:
			get_tree().change_scene_to_file(COMBAT_SCENE)


func _node_count() -> int:
	return RunManager.combat_count() + 1


func _is_boss(index: int) -> bool:
	return index >= RunManager.combat_count()


func _node_radius(index: int) -> float:
	return BOSS_RADIUS if _is_boss(index) else COMBAT_RADIUS


## Node 0 is at the bottom, the boss at the top, all within the bottom half of the screen.
func _node_center(index: int) -> Vector2:
	var top := size.y * 0.5 + 140.0
	var bottom := size.y - 160.0
	return Vector2(size.x * 0.28, lerpf(bottom, top, float(index) / (_node_count() - 1)))


## The shop sits beside the path, halfway between the combats before and after it.
func _shop_center() -> Vector2:
	var before := _node_center(RunManager.config.shop_position - 1)
	var after := _node_center(RunManager.config.shop_position)
	return Vector2(size.x * 0.76, (before.y + after.y) / 2.0)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0.0, size.y * 0.5 + 100.0), "Run map", HORIZONTAL_ALIGNMENT_CENTER, size.x, 44, dim_text_color)
	draw_string(font, Vector2(0.0, size.y * 0.5 + 100.0), "$%d" % RunManager.money, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 40.0, 52, money_color)
	for i in _node_count() - 1:
		draw_line(_node_center(i), _node_center(i + 1), line_color, 8.0, true)
	if RunManager.config.shop != null:
		_draw_shop(font)
	for i in _node_count():
		_draw_node(font, i)
	var hint := "Tap the glowing node to fight"
	if RunManager.shop_available():
		hint = "Visit the shop, or skip it and fight"
	draw_string(font, Vector2(0.0, size.y - 40.0), hint, HORIZONTAL_ALIGNMENT_CENTER, size.x, 36, dim_text_color)


func _draw_shop(font: Font) -> void:
	var center := _shop_center()
	var path_x := _node_center(0).x
	var available := RunManager.shop_available()
	var visited := RunManager.shop_done
	draw_line(Vector2(path_x, center.y), center, line_color, 6.0, true)
	var fill := future_color
	if visited:
		fill = done_color
	elif available:
		fill = current_color.darkened(0.45)
	draw_circle(center, SHOP_RADIUS, fill)
	if available:
		var pulse := 5.0 + 3.0 * sin(_time * 4.0 + 1.0)
		draw_arc(center, SHOP_RADIUS + pulse, 0.0, TAU, 40, current_color, 6.0, true)
	draw_string(font, center + Vector2(-SHOP_RADIUS, 16.0), "$", HORIZONTAL_ALIGNMENT_CENTER, SHOP_RADIUS * 2.0, 52, text_color)
	var label := "Shop (visited)" if visited else "Shop (optional)"
	draw_string(font, center + Vector2(-120.0, -SHOP_RADIUS - 28.0), label, HORIZONTAL_ALIGNMENT_CENTER, 240.0, 30, dim_text_color if not available else text_color)


func _draw_node(font: Font, index: int) -> void:
	var center := _node_center(index)
	var radius := _node_radius(index)
	var is_done := index < RunManager.combat_index
	var is_current := index == RunManager.combat_index
	var boss := _is_boss(index)

	var fill := future_color
	if boss:
		fill = RunManager.boss.map_color.darkened(0.5 if not is_current else 0.0)
	elif is_done:
		fill = done_color
	elif is_current:
		fill = current_color.darkened(0.3)
	draw_circle(center, radius, fill)

	if is_current:
		var pulse := 6.0 + 4.0 * sin(_time * 4.0)
		draw_arc(center, radius + pulse, 0.0, TAU, 48, current_color, 8.0, true)

	# Placeholder icon: a number for combats, the boss's own label for the boss.
	var label := RunManager.boss.map_label if boss else str(index + 1)
	draw_string(font, center + Vector2(-radius, 16.0), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 48, text_color)
	if is_done:
		draw_polyline(PackedVector2Array([center + Vector2(-22, 38), center + Vector2(-8, 52), center + Vector2(22, 22)]), text_color, 8.0, true)

	# Name beside the node.
	var text_pos := center + Vector2(radius + 40.0, -4.0)
	if boss:
		draw_string(font, text_pos, "Boss: %s" % RunManager.boss.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, text_color)
		draw_multiline_string(font, text_pos + Vector2(0.0, 40.0), RunManager.boss.description,
				HORIZONTAL_ALIGNMENT_LEFT, size.x - text_pos.x - 30.0, 30, 3, dim_text_color)
	else:
		var name_text := "Combat %d%s" % [index + 1, " (cleared)" if is_done else ""]
		draw_string(font, text_pos + Vector2(0.0, 14.0), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, dim_text_color if is_done else text_color)
