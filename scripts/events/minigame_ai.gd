class_name MinigameAI
extends Node
## The opponent in the competitive minigames. It tries many shots (aim points x angle offsets x
## power levels), predicts each with the combat AI's own maths (EnemyAI: shape casts for the first
## figure hit, elastic-collision prediction, slide distance from damping), scores where the figures
## would end up with a scoring function the minigame supplies, and flicks the best one with a bit of
## aim and power error (its accuracy).

@export_group("Candidate shots")
## Aim this many degrees either side of each aim point.
@export var angle_offsets_degrees: Array[float] = [-9.0, -4.5, 0.0, 4.5, 9.0]
## Power levels tried, as fractions of a full-strength flick: from min to max in steps.
@export var power_min := 0.08
@export var power_max := 1.0
@export var power_step := 0.02
@export_group("Accuracy")
## Aim error at accuracy 0 (the real error is (1 - accuracy) times this, either way).
@export var max_aim_error_degrees := 20.0

var _eval := EnemyAI.new()  # only its shot-prediction helpers are used


func _ready() -> void:
	add_child(_eval)


## Returns the impulse to flick `shooter` with. `max_force` is a full-strength flick. `aim_points` are
## places worth shooting at (the goal, rival figures). `score_fn(moved)` rates a predicted outcome
## (`moved`: figure -> where it ends up, Vector2.INF if it falls off) - higher is better.
func choose(shooter: Figure, table: Rect2, max_force: float, aim_points: Array[Vector2],
		score_fn: Callable, accuracy: float, power_error: float) -> Vector2:
	var shape := CircleShape2D.new()
	shape.radius = shooter.radius
	var from := shooter.global_position
	var best_score := -INF
	var best_direction := Vector2.ZERO
	var best_power := 0.0
	for point in aim_points:
		if point.distance_to(from) < 1.0:
			continue
		var base_angle := (point - from).angle()
		for offset in angle_offsets_degrees:
			var direction := Vector2.from_angle(base_angle + deg_to_rad(offset))
			var power := power_min
			while power <= power_max + 0.0001:
				var speed := power * max_force / shooter.mass
				var score := _score_shot(shooter, shape, table, direction, speed, score_fn)
				if score > best_score:
					best_score = score
					best_direction = direction
					best_power = power
				power += power_step
	if best_direction == Vector2.ZERO:
		return Vector2.ZERO
	# Moderate accuracy: the shot lands a little off.
	var error := deg_to_rad((1.0 - accuracy) * max_aim_error_degrees)
	best_direction = best_direction.rotated(randf_range(-error, error))
	best_power = clampf(best_power * (1.0 + randf_range(-power_error, power_error)), 0.02, 1.0)
	return best_direction * best_power * max_force


func _score_shot(shooter: Figure, shape: CircleShape2D, table: Rect2, direction: Vector2, speed: float,
		score_fn: Callable) -> float:
	var from := shooter.global_position
	var travel: float = _eval._travel_distance(shooter, speed)
	var hit: Dictionary = _eval._first_hit(shooter, shape, direction, travel, from)
	var moved := {}
	if hit.is_empty():
		moved[shooter] = _rest_point(shooter, from, direction * speed, table)
		return score_fn.call(moved)
	var distance: float = hit.distance
	var contact := from + direction * distance
	var target := hit.collider as Figure
	var speed_at_contact := speed - shooter.linear_damp * distance
	if target == null or speed_at_contact <= shooter.stop_speed:
		moved[shooter] = contact
		return score_fn.call(moved)
	var after: Dictionary = _eval._predict_collision(shooter, target, direction * speed_at_contact, contact)
	moved[shooter] = _rest_point(shooter, contact, after.shooter, table)
	moved[target] = _rest_point(target, target.global_position, after.target, table)
	return score_fn.call(moved)


## Where a figure at `from` moving at `velocity` comes to rest (Vector2.INF if that is off the table).
func _rest_point(figure: Figure, from: Vector2, velocity: Vector2, table: Rect2) -> Vector2:
	var speed := velocity.length()
	if speed <= figure.stop_speed:
		return from
	var end: Vector2 = from + velocity / speed * _eval._travel_distance(figure, speed)
	return end if table.has_point(end) else Vector2.INF
