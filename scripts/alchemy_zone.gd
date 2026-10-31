class_name AlchemyZone
extends Node2D
## An Alchemist's debuff zone: a bubbling puddle. Opposing figures inside it take `knockback` x knockback
## (see Figure.zone_knockback_multiplier). It is just a picture plus data: the Arena finds figures inside it.

var radius := 150.0
var knockback := 1.5
## Opposing figures that touch it stay Doused (extra knockback) for this many rounds.
var douse_rounds := 2
var owner_figure: Figure
var _age := 0.0


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _draw() -> void:
	var team_color := Figure.ENEMY_RING if owner_figure != null and owner_figure.team == Figure.Team.ENEMY else Figure.PLAYER_RING
	draw_circle(Vector2.ZERO, radius, Color(0.55, 0.2, 0.75, 0.2))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.7, 0.35, 0.9, 0.8), 5.0, true)
	draw_arc(Vector2.ZERO, radius + 7.0, 0.0, TAU, 64, Color(team_color, 0.35), 3.0, true)
	for i in 6:
		var phase := fposmod(_age * 0.5 + i / 6.0, 1.0)
		var angle := TAU * i / 6.0 + i
		var spot := Vector2.from_angle(angle) * radius * (0.25 + 0.5 * fposmod(i * 0.37, 1.0))
		draw_circle(spot + Vector2(0, -phase * 26.0), 8.0 * (1.0 - phase), Color(0.85, 0.6, 1.0, 0.8 * (1.0 - phase)))
