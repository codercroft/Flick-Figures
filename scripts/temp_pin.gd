class_name TempPin
extends StaticBody2D
## A temporary pin placed by Pinhead: looks and bounces like an arena pin (the Arena adds the
## shape and the kicking sensor). It is removed when Pinhead's flick has settled.

var radius := 28.0
var color := Color(0.85, 0.75, 0.3)
var owner_figure: Figure  # the Pinhead that placed it


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color.darkened(0.35))
	draw_circle(Vector2.ZERO, radius - 5.0, color)
	draw_circle(Vector2(-0.3, -0.3) * radius, radius * 0.25, color.lightened(0.5))
	# A thin ring marks it as temporary.
	draw_arc(Vector2.ZERO, radius + 7.0, 0.0, TAU, 32, Color(color, 0.6), 3.0, true)
