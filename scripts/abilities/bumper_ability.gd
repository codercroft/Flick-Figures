class_name BumperAbility
extends FigureAbility
## Anything that bounces off it gets extra knockback, away from the bumper.

## Extra push as a fraction of the other figure's speed after the bounce.
@export var bump_ratio := 0.8
## Ignore bounces slower than this (px/s).
@export var min_bump_speed := 100.0
@export var max_bump_speed := 1800.0


func on_hit(figure: Figure, other: Figure) -> void:
	var speed := other.linear_velocity.length()
	if speed < min_bump_speed:
		return
	var away := (other.global_position - figure.global_position).normalized()
	other.take_knockback(away * minf(speed * bump_ratio, max_bump_speed) * other.mass, figure)
