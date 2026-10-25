class_name CrazyManAbility
extends FigureAbility
## Bounces off anything faster than it arrived. (Godot adds two bounce values together and
## caps them at 1, so a high bounce alone only gets you a perfect bounce, not more.)

## Speed multiplier applied after each bump (1.3 = leaves 30% faster than a perfect bounce).
@export var bounce_boost := 1.3
@export var max_speed := 3000.0


func on_hit(figure: Figure, _other: Figure) -> void:
	figure.linear_velocity = (figure.linear_velocity * bounce_boost).limit_length(max_speed)
