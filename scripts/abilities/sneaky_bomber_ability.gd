class_name SneakyBomberAbility
extends FigureAbility
## If its flick ends without touching any figure, it explodes where it stops,
## pushing away EVERY figure in range, allies included.

@export var explosion_radius := 360.0
@export var explosion_force := 2200.0

var _flicking := false
var _hit_something := false


func on_flicked(_figure: Figure, _impulse: Vector2) -> void:
	_flicking = true
	_hit_something = false


func on_hit(_figure: Figure, _other: Figure) -> void:
	_hit_something = true


func on_stopped(figure: Figure) -> void:
	if _flicking and not _hit_something:
		figure.explode(explosion_radius, explosion_force)
	_flicking = false
