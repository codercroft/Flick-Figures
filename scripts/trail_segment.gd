class_name TrailSegment
extends Node2D
## One piece of Juicer's boost trail: a faint juicy disc with an arrow showing which way it pushes.
## It fades out as its rounds run out (the arena does the pushing and the counting).

var radius := 60.0
var direction := Vector2.UP
var color := Color(0.65, 0.95, 0.2)
## 1 = fresh, 0 = about to vanish.
var life := 1.0:
	set(value):
		life = value
		queue_redraw()


func _draw() -> void:
	var alpha := 0.15 + 0.3 * life
	draw_circle(Vector2.ZERO, radius, Color(color, alpha * 0.6))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(color, alpha), 4.0, true)
	var side := direction.orthogonal()
	var tip := direction * radius * 0.55
	draw_polyline(PackedVector2Array([tip - direction * radius * 0.5 + side * radius * 0.35, tip,
			tip - direction * radius * 0.5 - side * radius * 0.35]), Color(0.9, 1.0, 0.6, alpha + 0.2), 5.0, true)
