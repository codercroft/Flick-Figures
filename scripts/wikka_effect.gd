class_name WikkaEffect
extends Node2D
## A small "Wikka!" burst: two curved arrows around a point (Wikka Wat reversing). Add it with WikkaEffect.spawn().

var _age := 0.0
var _angle := 0.0
const LIFETIME := 0.45


static func spawn(parent: Node, at: Vector2, direction: Vector2) -> void:
	var effect := WikkaEffect.new()
	effect.position = at
	effect.z_index = 7
	effect._angle = direction.angle()
	parent.add_child(effect)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	var alpha := 1.0 - t
	var radius := 46.0 + 38.0 * t
	var color := Color(1.0, 0.55, 0.95, alpha)
	for side in [-1.0, 1.0]:
		var start: float = _angle + PI / 2.0 * side - 0.9
		draw_arc(Vector2.ZERO, radius, start, start + 1.8, 14, color, 7.0, true)
		var tip := Vector2.from_angle(start + 1.8) * radius
		draw_circle(tip, 8.0, color)
