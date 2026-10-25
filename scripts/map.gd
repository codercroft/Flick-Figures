extends Control
## The run map, shown before each combat: nodes from bottom to top (the combats, then the boss).
## Done nodes are checked, the current node glows, and tapping it starts the combat.
## Placeholder shapes and text for now. All of it sits in the bottom half of the screen.

const COMBAT_SCENE := "res://scenes/main.tscn"
const COMBAT_RADIUS := 60.0
const BOSS_RADIUS := 80.0

@export var done_color := Color(0.3, 0.5, 0.36)
@export var current_color := Color(1.0, 0.85, 0.3)
@export var future_color := Color(0.25, 0.27, 0.33)
@export var line_color := Color(0.4, 0.43, 0.52)
@export var text_color := Color(0.9, 0.92, 0.97)
@export var dim_text_color := Color(0.6, 0.63, 0.72)

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()  # the current node pulses


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
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


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0.0, size.y * 0.5 + 50.0), "Run map", HORIZONTAL_ALIGNMENT_CENTER, size.x, 44, dim_text_color)
	for i in _node_count() - 1:
		draw_line(_node_center(i), _node_center(i + 1), line_color, 8.0, true)
	for i in _node_count():
		_draw_node(font, i)
	draw_string(font, Vector2(0.0, size.y - 40.0), "Tap the glowing node to fight", HORIZONTAL_ALIGNMENT_CENTER, size.x, 36, dim_text_color)


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
