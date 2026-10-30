class_name GlueLink
extends PinJoint2D
## The joint that holds two glued figures together, drawn as a little goo link between them (a thick green
## strand that sags in the middle, with a blob on each figure's edge).

var figure_a: Figure
var figure_b: Figure

const GOO := Color(0.55, 0.9, 0.3)
const GOO_DARK := Color(0.25, 0.5, 0.15)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(figure_a) or not is_instance_valid(figure_b):
		return
	var a := to_local(figure_a.global_position)
	var b := to_local(figure_b.global_position)
	var direction := (b - a).normalized()
	if direction == Vector2.ZERO:
		return
	var start := a + direction * figure_a.radius * 0.55
	var end := b - direction * figure_b.radius * 0.55
	# A strand that sags a little in the middle (thinner there, like stretched goo).
	var points := PackedVector2Array()
	var sag := direction.orthogonal() * 8.0
	for i in 9:
		var t := i / 8.0
		points.append(start.lerp(end, t) + sag * sin(t * PI))
	draw_polyline(points, GOO_DARK, 18.0, true)
	draw_polyline(points, GOO, 11.0, true)
	for blob in [start, end]:
		draw_circle(blob, 13.0, GOO_DARK)
		draw_circle(blob, 9.5, GOO)
	draw_circle(points[4] + Vector2(-2, -2), 3.0, GOO.lightened(0.5))
