class_name PopcornAbility
extends FigureAbility
## Caught in an explosion, it ignores the normal push and instead pops off in a random
## direction at a very high speed.

## Speed (px/s) it launches at. Very high: it usually leaves the table.
@export var launch_speed := 3000.0


func get_explosion_multiplier(_figure: Figure, _source: Figure) -> float:
	return 0.0


func on_exploded(figure: Figure, _source: Figure) -> void:
	figure.nudge(Vector2.from_angle(randf() * TAU) * launch_speed)
	figure.show_popup("Pop!", Color(1.0, 0.95, 0.6))
