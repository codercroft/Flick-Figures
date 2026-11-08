class_name SneakyBomberAbility
extends FigureAbility
## If its flick ends without touching any figure, it explodes where it stops,
## pushing away EVERY figure in range, allies included.

@export var explosion_radius := 270.0
@export var explosion_force := 2200.0
## Upgrade: the explosion radius grows by this much (px) for every 100px the figure travelled.
@export var radius_per_100px := 0.0
## Fuse path: touching only allies does not count as touching something.
@export var ally_touch_ok := false
## Stealth path: extra aim error (degrees) for enemy shots aimed at it, and Ambush: if no enemy hit it during the
## enemy's turn, it explodes when that turn ends.
@export var incoming_aim_error := 0.0
@export var ambush := false

var _flicking := false
var _hit_something := false
var _start := Vector2.ZERO


func on_flicked(figure: Figure, _impulse: Vector2) -> void:
	_start = figure.global_position
	_flicking = true
	_hit_something = false


var _hit_by_enemy := false


func on_hit(figure: Figure, other: Figure) -> void:
	if other.team != figure.team:
		_hit_by_enemy = true
	elif ally_touch_ok:
		return
	_hit_something = true


func get_incoming_aim_error_degrees(_figure: Figure) -> float:
	return incoming_aim_error


## Ambush: called as each turn ends. When the OPPONENT's turn just ended and nothing of theirs touched it, it explodes.
func on_turn_ended(figure: Figure) -> void:
	var main := figure.get_tree().current_scene
	if main == null or not ("turret_side" in main):
		return
	if main.turret_side == figure.team:  # its own side's turn ended: the opponent's turn starts now
		_hit_by_enemy = false
		return
	if ambush and not figure.on_deck and not figure.knocked_off and not _hit_by_enemy:
		figure.show_popup("Ambush!", Color(1.0, 0.6, 0.3))
		figure.explode(explosion_radius, explosion_force)


func on_stopped(figure: Figure) -> void:
	if _flicking and not _hit_something:
		var travelled := figure.global_position.distance_to(_start)
		figure.explode(explosion_radius + radius_per_100px * travelled / 100.0, explosion_force)
	_flicking = false


func detonate(figure: Figure) -> void:
	figure.explode(explosion_radius, explosion_force)


func get_ai_blast(_figure: Figure) -> Dictionary:
	return {"radius": explosion_radius, "force": explosion_force, "when": "stop"}
