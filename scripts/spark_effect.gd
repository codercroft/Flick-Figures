class_name SparkEffect
extends Node2D
## A short burst of electric zigzags (Energizer recharging a friend). Add it with SparkEffect.spawn().

var _age := 0.0
var _bolts: Array[PackedVector2Array] = []
const LIFETIME := 0.55


static func spawn(parent: Node, at: Vector2) -> void:
	var spark := SparkEffect.new()
	spark.position = at
	spark.z_index = 7
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 6:
		var direction := Vector2.from_angle(TAU * i / 6.0 + rng.randf_range(-0.3, 0.3))
		var points := PackedVector2Array([Vector2.ZERO])
		for step in 4:
			points.append(direction * (30.0 + step * 22.0) + direction.orthogonal() * rng.randf_range(-12.0, 12.0))
		spark._bolts.append(points)
	parent.add_child(spark)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var fade := 1.0 - _age / LIFETIME
	for bolt in _bolts:
		draw_polyline(bolt, Color(1.0, 0.95, 0.4, fade), 6.0 * fade + 1.0, true)
		draw_polyline(bolt, Color(1.0, 1.0, 0.9, fade), 2.0, true)
