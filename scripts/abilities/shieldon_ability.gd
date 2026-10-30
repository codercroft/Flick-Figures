class_name ShieldonAbility
extends FigureAbility
## When it stops after its own flick, it props up a short immovable wall just in front of it, facing the way it
## was moving. Only one wall per Shieldon (a new one replaces the old). If Shieldon is bumped or moved off that
## spot (or flicked again, or knocked off) the wall disappears.

## Length and thickness of the wall (px), and the gap between Shieldon's edge and the wall.
@export var wall_length := 190.0
@export var wall_thickness := 26.0
@export var wall_gap := 10.0
## Shieldon counts as "moved" if it ends up farther than this (px) from where it stood, or moves faster
## than this (px/s).
@export var move_tolerance := 6.0
@export var move_speed := 30.0

var _flicking := false
var _heading := Vector2.ZERO
var _spot := Vector2.INF  # where Shieldon stood when the wall went up (INF = no wall)


func on_flicked(figure: Figure, _impulse: Vector2) -> void:
	_remove_wall(figure)
	_flicking = true
	_heading = Vector2.ZERO


func on_physics_process(figure: Figure, _delta: float) -> void:
	var speed := figure.linear_velocity.length()
	if _flicking and speed > figure.stop_speed * 2.0:
		_heading = figure.linear_velocity / speed  # the way it was going
	if _spot != Vector2.INF and (figure.global_position.distance_to(_spot) > move_tolerance or speed > move_speed):
		_remove_wall(figure)  # bumped or moved: the wall drops


func on_stopped(figure: Figure) -> void:
	if not _flicking:
		return
	_flicking = false
	if _heading == Vector2.ZERO or figure.knocked_off:
		return
	var combat = RunManager.combat
	if combat == null:
		return
	var center := figure.global_position + _heading * (figure.radius + wall_gap + wall_thickness / 2.0)
	# Wall across the heading: its long side is perpendicular to the way Shieldon was moving.
	if combat.arena.place_shield_wall(figure, center, Vector2(wall_length, wall_thickness), _heading.angle() - PI / 2.0):
		_spot = figure.global_position
		figure.show_popup("Wall up!", Color(0.8, 0.9, 1.0))


func on_knocked_off(figure: Figure) -> void:
	_remove_wall(figure)


func has_active_wall(_figure: Figure) -> bool:
	return _spot != Vector2.INF


func _remove_wall(figure: Figure) -> void:
	_spot = Vector2.INF
	var combat = RunManager.combat
	if combat != null:
		combat.arena.remove_shield_wall(figure)
