class_name RubberEffect
extends FigureAbility
## Rubber finish: much bouncier off walls and pins (a moving figure leaves a wall faster).

## Speed multiplier applied right after it bounces off a wall or pin.
@export var rebound_boost := 1.5
@export var max_speed := 3200.0


func on_hit_wall(figure: Figure, _body: Node) -> void:
	if not figure.is_slow():
		figure.linear_velocity = (figure.linear_velocity * rebound_boost).limit_length(max_speed)
