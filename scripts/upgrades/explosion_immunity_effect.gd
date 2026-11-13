class_name ExplosionImmunityEffect
extends FigureAbility
## Immune to the push of explosions; explosions still crack a Duwall shell, but for half the damage.

## Share of the explosion's shell damage that still lands.
@export var shell_damage_multiplier := 0.5


func get_explosion_damage_multiplier(_figure: Figure) -> float:
	return shell_damage_multiplier



func get_explosion_multiplier(figure: Figure, _source: Figure) -> float:
	return 1.0 if figure.shell_broken else 0.0  # (a burst shell leaves a plain Grunt)
