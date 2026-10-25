extends Node2D
## Dotted aim line shown while dragging. main.gd tells it where to draw.

@export var dot_spacing := 36.0
@export var dot_radius := 8.0
@export var dot_color := Color(1, 1, 1, 0.9)

var _active := false
var _origin := Vector2.ZERO
var _direction := Vector2.UP
var _distance := 0.0


func show_aim(origin: Vector2, direction: Vector2, distance: float) -> void:
	_active = true
	_origin = origin
	_direction = direction
	_distance = distance
	queue_redraw()


func clear() -> void:
	_active = false
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	# Dots shrink and fade along the line; the last one marks where it should stop.
	var along := dot_spacing
	while along <= _distance:
		var t := along / _distance
		var dot := Color(dot_color, dot_color.a * lerpf(1.0, 0.3, t))
		draw_circle(_origin + _direction * along, dot_radius * lerpf(1.0, 0.5, t), dot)
		along += dot_spacing
