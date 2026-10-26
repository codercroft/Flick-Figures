class_name BumperAbility
extends FigureAbility
## Anything that bounces off it is launched away from it, hard.

## Extra push as a multiple of the other figure's speed after the bounce (1.8 = nearly triples it).
@export var bump_ratio := 1.8
## Ignore bounces slower than this (px/s).
@export var min_bump_speed := 100.0
@export var max_bump_speed := 2400.0


func on_hit(figure: Figure, other: Figure) -> void:
	if other.ability.is_plowing(other):
		return  # a Roller plowing from its own flick doesn't rebound, so there is nothing to launch
	var speed := other.linear_velocity.length()
	if speed < min_bump_speed:
		return
	var away := (other.global_position - figure.global_position).normalized()
	other.take_knockback(away * minf(speed * bump_ratio, max_bump_speed) * other.mass, figure)
