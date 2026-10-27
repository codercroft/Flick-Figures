class_name CrazyManAbility
extends FigureAbility
## Bounces off anything faster than it arrived. (Godot adds two bounce values together and
## caps them at 1, so a high bounce alone only gets you a perfect bounce, not more.)
## Aura: teammates within `aura_radius` flick harder and are tougher to knock back.

## Speed multiplier applied after each bump (1.3 = leaves 30% faster than a perfect bounce).
@export var bounce_boost := 1.3
@export var max_speed := 3000.0
## Teammates this close (px) get the aura. It is drawn faintly around Crazy Man.
@export var aura_radius := 300.0
## Flick power multiplier for teammates inside the aura (1.5 = +50%).
@export var aura_flick_power := 1.5
## Knockback taken by teammates inside the aura is divided by this (1.5 = +50% resistance).
@export var aura_knockback_resistance := 1.5


func on_hit(figure: Figure, _other: Figure) -> void:
	figure.linear_velocity = (figure.linear_velocity * bounce_boost).limit_length(max_speed)


func get_aura_radius(_figure: Figure) -> float:
	return aura_radius


func get_aura_flick_multiplier(_figure: Figure) -> float:
	return aura_flick_power


func get_aura_knockback_multiplier(_figure: Figure) -> float:
	return 1.0 / aura_knockback_resistance
