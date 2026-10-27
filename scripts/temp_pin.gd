class_name TempPin
extends StaticBody2D
## A temporary pin placed by Pinhead: looks and bounces like an arena pin (the Arena adds the
## shape and the kicking sensor). It stays until its side's flick cycle resets. A small marker shows
## whose it is: a ring in the Pinhead's team color, the Pinhead's label above the pin, and a faint
## line back to the Pinhead.

var radius := 28.0
var color := Color(0.85, 0.75, 0.3)
var owner_figure: Figure  # the Pinhead that placed it


func _process(_delta: float) -> void:
	queue_redraw()  # the tether follows the Pinhead


func _draw() -> void:
	var team_color := Figure.ENEMY_RING if owner_figure != null and owner_figure.team == Figure.Team.ENEMY \
			else Figure.PLAYER_RING
	if is_instance_valid(owner_figure) and not owner_figure.knocked_off:
		draw_dashed_line(Vector2.ZERO, to_local(owner_figure.global_position), Color(team_color, 0.3), 3.0, 14.0)
	draw_circle(Vector2.ZERO, radius, color.darkened(0.35))
	draw_circle(Vector2.ZERO, radius - 5.0, color)
	draw_circle(Vector2(-0.3, -0.3) * radius, radius * 0.25, color.lightened(0.5))
	draw_arc(Vector2.ZERO, radius + 7.0, 0.0, TAU, 32, team_color, 5.0, true)
	if is_instance_valid(owner_figure):
		var label := owner_figure.data.label if owner_figure.data.label != "" else owner_figure.data.display_name.left(1)
		draw_string(ThemeDB.fallback_font, Vector2(-40.0, -radius - 14.0), label, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 30,
				Color(team_color, 0.95))
