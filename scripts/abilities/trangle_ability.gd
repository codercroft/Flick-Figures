class_name TrangleAbility
extends FigureAbility
## Trangle: ONE heavy body shaped like a triangle with concave (inward-curving) sides. The shape is a
## CollisionPolygon2D (Godot splits the concave outline into convex pieces itself) that replaces the usual
## circle. It spins hard when it flicks, so figures sitting in its curved sides get swept or flung out.

## Distance from the center to each tip (px).
@export var tip_distance := 135.0
## How far each side curves inward: 0 = straight, 1 = the side's middle is pulled most of the way to the center.
@export_range(0.0, 1.2) var concavity := 0.85
## Points per side of the outline (more = smoother curve).
@export var points_per_side := 8
## Spin (rad/s) it gets when it flicks (the direction is random), and how fast the spin dies away (angular damp).
@export var flick_spin := 12.0
@export var spin_damp := 1.8

var _outline := PackedVector2Array()


func setup_body(figure: Figure) -> void:
	figure.lock_rotation = false
	figure.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	figure.angular_damp = spin_damp
	_outline = _make_outline()
	# The circle every figure starts with goes; the polygon is the body.
	for child in figure.get_children():
		if child is CollisionShape2D:
			figure.remove_child(child)
			child.queue_free()
	var body := CollisionPolygon2D.new()
	body.polygon = _outline
	figure.add_child(body)


func on_flicked(figure: Figure, _impulse: Vector2) -> void:
	figure.angular_velocity = flick_spin * (1.0 if randf() < 0.5 else -1.0)


func on_physics_process(figure: Figure, _delta: float) -> void:
	if figure.linear_velocity.length() < figure.stop_speed:
		figure.angular_velocity = 0.0  # resting: no more spin


func draws_own_body(_figure: Figure) -> bool:
	return true


func draw_body(figure: Figure) -> void:
	if _outline.is_empty():
		_outline = _make_outline()
	var ring := Figure.ENEMY_RING if figure.team == Figure.Team.ENEMY else Figure.PLAYER_RING
	for piece in Geometry2D.decompose_polygon_in_convex(_outline):
		figure.draw_colored_polygon(piece, figure.data.color)
	var closed := _outline.duplicate()
	closed.append(_outline[0])
	figure.draw_polyline(closed, ring, 8.0, true)


## Three tips, each side a quadratic curve whose middle is pulled toward the center.
func _make_outline() -> PackedVector2Array:
	var tips: Array[Vector2] = []
	for i in 3:
		tips.append(Vector2.from_angle(-PI / 2.0 + TAU * i / 3.0) * tip_distance)
	var points := PackedVector2Array()
	for i in 3:
		var a := tips[i]
		var b := tips[(i + 1) % 3]
		var control := (a + b) * 0.5 * (1.0 - concavity)
		for step in points_per_side:
			var t := float(step) / points_per_side
			points.append(a * (1.0 - t) * (1.0 - t) + control * 2.0 * t * (1.0 - t) + b * t * t)
	return points
