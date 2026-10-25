class_name BunkerAbility
extends FigureAbility
## Immune to explosion knockback. Every explosion that reaches it makes it permanently heavier
## for the rest of the combat.

## Mass gained per explosion.
@export var mass_gain := 0.5
## It never gets heavier than this.
@export var max_mass := 6.0


func get_explosion_multiplier(_figure: Figure, _source: Figure) -> float:
	return 0.0


func on_exploded(figure: Figure, _source: Figure) -> void:
	figure.mass = minf(figure.mass + mass_gain, max_mass)
	figure.show_popup("Heavier!", Color(0.7, 0.8, 0.95))
