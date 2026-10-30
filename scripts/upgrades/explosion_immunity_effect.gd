class_name ExplosionImmunityEffect
extends FigureAbility
## Immune to the push of explosions.


func get_explosion_multiplier(figure: Figure, _source: Figure) -> float:
	return 1.0 if figure.shell_broken else 0.0  # (a burst shell leaves a plain Grunt)
