class_name BocceMinigame
extends VersusMinigame
## Bocce: a small white jack is tossed near the middle of an open table. You and the AI take turns
## flicking 3 Grunts each (the opponent flicks down from the top). Grunts can knock each other and the
## jack. The Grunt nearest the jack wins.

@export_group("Jack")
@export var jack_radius := 24.0
@export var jack_mass := 0.4
## The jack lands within this far (px) of the middle of the table, either way.
@export var jack_spread := Vector2(140.0, 120.0)
## If the jack is knocked off, it is put back this far inside the nearest edge.
@export var jack_return_margin := 80.0

var _jack: Figure


func _init() -> void:
	opponent_from_top = true


func _goal() -> Vector2:
	return _jack.global_position if is_instance_valid(_jack) else board_rect.get_center()


func _goal_after(moved: Dictionary) -> Vector2:
	return moved.get(_jack, _jack.global_position)


func _draw_table() -> void:
	# A faint center cross.
	var center := board_rect.get_center()
	draw_line(center + Vector2(-30, 0), center + Vector2(30, 0), Color(0, 0, 0, 0.12), 4.0)
	draw_line(center + Vector2(0, -30), center + Vector2(0, 30), Color(0, 0, 0, 0.12), 4.0)


## The jack is really flicked: it slides to a random spot near the middle.
func _setup_table() -> void:
	status_label.text = "Tossing the jack..."
	var target := board_rect.get_center() + Vector2(randf_range(-jack_spread.x, jack_spread.x),
			randf_range(-jack_spread.y, jack_spread.y))
	var data := make_data("Jack", "J", Color.WHITE, jack_radius, jack_mass)
	var start := Vector2(board_rect.get_center().x, board_rect.end.y - launch_margin)
	_jack = spawn_figure(data, Figure.Team.ENEMY, start)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var speed := start.distance_to(target) * _jack.linear_damp + stop_speed
	_jack.launch((target - start).normalized() * speed * _jack.mass)
	await wait_until_settled()


func on_fell(figure: Figure) -> void:
	if figure == _jack:
		var spot := Vector2(
				clampf(figure.global_position.x, board_rect.position.x + jack_return_margin, board_rect.end.x - jack_return_margin),
				clampf(figure.global_position.y, board_rect.position.y + jack_return_margin, board_rect.end.y - jack_return_margin))
		figure.global_position = spot
		figure.linear_velocity = Vector2.ZERO
		figure.show_popup("Back on the table")
		return
	super.on_fell(figure)
