class_name ZoneVisual
extends Node2D
## What a placed power zone looks like (the arena does the physics).

enum Kind { MAGNET, PUDDLE }

var kind := Kind.MAGNET
var radius := 200.0
var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if kind == Kind.MAGNET:
		draw_circle(Vector2.ZERO, radius, Color(0.6, 0.3, 0.9, 0.14))
		for i in 3:
			var t := fposmod(_time * 0.6 + i / 3.0, 1.0)
			draw_arc(Vector2.ZERO, radius * (1.0 - t), 0.0, TAU, 48, Color(0.8, 0.6, 1.0, t), 6.0, true)
		draw_circle(Vector2.ZERO, 22.0, Color(0.85, 0.7, 1.0))
	else:
		draw_circle(Vector2.ZERO, radius, Color(0.75, 0.9, 0.2, 0.45))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.55, 0.7, 0.1, 0.9), 8.0, true)
		draw_circle(Vector2(-radius * 0.3, -radius * 0.2), radius * 0.18, Color(1.0, 1.0, 0.7, 0.5))
