class_name SneakyBomberAbility
extends FigureAbility
## If its flick ends without touching any figure, it explodes where it stops,
## pushing away EVERY figure in range, allies included.

@export var explosion_radius := 270.0
@export var explosion_force := 2200.0
## Upgrade: the explosion radius grows by this much (px) for every 100px the figure travelled.
@export var radius_per_100px := 0.0

var _flicking := false
var _hit_something := false
var _start := Vector2.ZERO


func on_flicked(figure: Figure, _impulse: Vector2) -> void:
	_start = figure.global_position
	_flicking = true
	_hit_something = false


func on_hit(_figure: Figure, _other: Figure) -> void:
	_hit_something = true


func on_stopped(figure: Figure) -> void:
	if _flicking and not _hit_something:
		var travelled := figure.global_position.distance_to(_start)
		figure.explode(explosion_radius + radius_per_100px * travelled / 100.0, explosion_force)
	_flicking = false
