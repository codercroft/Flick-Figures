class_name WingsEffect
extends FigureAbility
## Once per combat: if the figure leaves the table during its own flick without touching
## anything, it wraps around to the opposite edge and keeps its velocity (like Ghost).

var _flicking := false
var _used := false


func on_flicked(_figure: Figure, _impulse: Vector2) -> void:
	_flicking = true


func on_stopped(_figure: Figure) -> void:
	_flicking = false


func on_left_table(figure: Figure, table: Rect2) -> bool:
	if _used or not _flicking or figure.touched_since_flick:
		return false
	_used = true
	var pos := figure.global_position
	pos.x = table.position.x + fposmod(pos.x - table.position.x, table.size.x)
	pos.y = table.position.y + fposmod(pos.y - table.position.y, table.size.y)
	figure.global_position = pos
	figure.show_popup("Flap!", Color(1.0, 1.0, 0.8))
	return true


func get_wrap_count(_figure: Figure) -> int:
	return 0 if _used else 1
