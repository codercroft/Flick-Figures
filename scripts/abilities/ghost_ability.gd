class_name GhostAbility
extends FigureAbility
## If it leaves the table during its own flick without having touched anything, it wraps around
## to the opposite edge (Pac-Man style) and keeps its velocity. If it touched or was hit by
## anything on the way (a figure or a wall), it is knocked off as usual.

## How many times per flick it can wrap around.
@export var max_wraps_per_flick := 1

var _flicking := false
var _wraps := 0


func on_flicked(_figure: Figure, _impulse: Vector2) -> void:
	_flicking = true
	_wraps = 0


func on_stopped(_figure: Figure) -> void:
	_flicking = false


func on_left_table(figure: Figure, table: Rect2) -> bool:
	if not _flicking or figure.touched_since_flick or _wraps >= max_wraps_per_flick:
		return false
	_wraps += 1
	var position := figure.global_position
	# Re-enter from the far side, keeping the same distance past the edge.
	position.x = table.position.x + fposmod(position.x - table.position.x, table.size.x)
	position.y = table.position.y + fposmod(position.y - table.position.y, table.size.y)
	figure.global_position = position
	figure.show_popup("Boo!", Color(0.85, 0.9, 1.0))
	return true


func get_wrap_count(_figure: Figure) -> int:
	return max_wraps_per_flick
