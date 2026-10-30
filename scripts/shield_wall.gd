class_name ShieldWall
extends StaticBody2D
## A short immovable wall propped up by a Shieldon Ooper (the Arena adds the collision shape). It is drawn as a
## small shield-like slab in the owner's team color.

var size := Vector2(170.0, 24.0)
var owner_figure: Figure


func _draw() -> void:
	var team_color := Figure.ENEMY_RING if owner_figure != null and owner_figure.team == Figure.Team.ENEMY else Figure.PLAYER_RING
	var rect := Rect2(-size / 2.0, size)
	draw_rect(rect, Color(0.45, 0.55, 0.7))
	draw_rect(rect, Color(0.8, 0.88, 1.0), false, 4.0)
	draw_rect(rect.grow(-7.0), Color(0.3, 0.4, 0.55), false, 3.0)
	draw_line(Vector2(-size.x / 2.0, size.y / 2.0 + 6.0), Vector2(size.x / 2.0, size.y / 2.0 + 6.0), Color(team_color, 0.7), 4.0)
