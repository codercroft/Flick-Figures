class_name ShortFuseEffect
extends FigureAbility
## Explodes when it is knocked off the table.

@export var explosion_radius := 260.0
@export var explosion_force := 1500.0


func on_knocked_off(figure: Figure) -> void:
	figure.explode(explosion_radius, explosion_force)
