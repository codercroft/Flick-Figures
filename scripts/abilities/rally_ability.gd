class_name RallyAbility
extends FigureAbility
## When flicked, gives a forward nudge to every other figure on its team: the ones out on the board
## and, for the player, the ones still on deck. Forward is up the board for the player, down for the enemy.

## Speed (px/s) each teammate gains.
@export var nudge_speed := 440.0


func on_flicked(figure: Figure, _impulse: Vector2) -> void:
	var forward := Vector2.UP if figure.team == Figure.Team.PLAYER else Vector2.DOWN
	for node in figure.get_tree().get_nodes_in_group("figures"):
		var other := node as Figure
		if other == figure or other.knocked_off or other.team != figure.team:
			continue
		other.nudge(forward * nudge_speed)
