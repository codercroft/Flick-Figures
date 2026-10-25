class_name BomboAbility
extends FigureAbility
## Explodes on its first hit after each flick, pushing nearby figures away.

@export var explosion_radius := 320.0
## Push at the center of the blast; fades to zero at the edge. Like a flick force.
@export var explosion_force := 2000.0

var _exploded := false


func on_flicked(_figure: Figure, _impulse: Vector2) -> void:
	_exploded = false


func on_hit(figure: Figure, _other: Figure) -> void:
	if _exploded:
		return
	_exploded = true
	figure.explode(explosion_radius, explosion_force)
