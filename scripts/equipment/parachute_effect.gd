class_name ParachuteEffect
extends FigureAbility
## Once per combat, when the figure would fall off the table it stops at the edge instead.

var _used := false


func on_left_table(figure: Figure, table: Rect2) -> bool:
	if _used:
		return false
	_used = true
	var inner := table.grow(-figure.radius)
	var pos := figure.global_position
	figure.global_position = Vector2(clampf(pos.x, inner.position.x, inner.end.x), clampf(pos.y, inner.position.y, inner.end.y))
	figure.linear_velocity = Vector2.ZERO
	figure.show_popup("Parachute!", Color(0.7, 0.9, 1.0))
	return true
