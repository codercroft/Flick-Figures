class_name BlastEffect
extends Node2D
## A ring that expands from a point and fades: the picture of an explosion (no physics).

var radius := 300.0
var progress := 0.0:
	set(value):
		progress = value
		queue_redraw()


func start(blast_radius: float) -> void:
	radius = blast_radius
	var tween := create_tween()
	tween.tween_property(self, "progress", 1.0, 0.45).from(0.0)
	tween.tween_callback(queue_free)


func _draw() -> void:
	var alpha := 1.0 - progress
	draw_circle(Vector2.ZERO, radius * progress, Color(1.0, 0.7, 0.2, 0.25 * alpha))
	draw_arc(Vector2.ZERO, radius * progress, 0.0, TAU, 64, Color(1.0, 0.85, 0.4, alpha), 12.0, true)
