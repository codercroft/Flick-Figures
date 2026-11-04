class_name RallyAbility
extends FigureAbility
## When flicked, sends every other figure on its team (on the board and, for the player, on deck) moving toward
## that teammate's own nearest opposing figure. With no opponent left a teammate is nudged forward instead
## (up the board for the player, down for the enemy). Upgrade Rallying Cry: also makes every other figure
## on its team flickable again.

## Speed (px/s) each teammate gains.
@export var nudge_speed := 440.0
## Rallying Cry: teammates can flick again.
@export var resets_cycle := false


func on_flicked(figure: Figure, _impulse: Vector2) -> void:
	for node in figure.get_tree().get_nodes_in_group("figures"):
		var other := node as Figure
		if other == figure or other.knocked_off or other.team != figure.team:
			continue
		other.nudge(nudge_direction(other) * nudge_speed)
		if resets_cycle:
			var main := figure.get_tree().current_scene
			if main != null and main.has_method("recharge_figure"):
				main.recharge_figure(other)


## The way `figure` is nudged: toward its nearest opposing figure, else forward. Shared with the enemy AI.
static func nudge_direction(figure: Figure) -> Vector2:
	var best: Figure = null
	var best_dist := INF
	for node in figure.get_tree().get_nodes_in_group("figures"):
		var opponent := node as Figure
		if opponent == null or opponent.knocked_off or opponent.team == figure.team:
			continue
		var dist := opponent.global_position.distance_squared_to(figure.global_position)
		if dist < best_dist:
			best_dist = dist
			best = opponent
	if best == null:
		return Vector2.UP if figure.team == Figure.Team.PLAYER else Vector2.DOWN
	return (best.global_position - figure.global_position).normalized()


## AI hint: the nudge speed (0 = this figure nudges nobody).
func get_rally_speed(_figure: Figure) -> float:
	return nudge_speed
