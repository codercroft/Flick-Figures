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


## Charge path: nudged teammates deal this much more knockback until the end of the next turn (0.2 = +20%) and take
## this much less (0.25 = -25%) until your next turn.
@export var nudged_dealt_bonus := 0.0
@export var nudged_taken_reduction := 0.0
## Formation path: teammates near a table edge are nudged inward instead, and the rally also happens when Rally hits
## an opposing figure.
@export var edge_guard := false
@export var rally_on_hit := false

var _last_rally_ms := -10000


func on_flicked(figure: Figure, _impulse: Vector2) -> void:
	_rally(figure)


func on_hit(figure: Figure, other: Figure) -> void:
	if rally_on_hit and other.team != figure.team and Time.get_ticks_msec() - _last_rally_ms > 400:
		_rally(figure)


func _rally(figure: Figure) -> void:
	_last_rally_ms = Time.get_ticks_msec()
	var main := figure.get_tree().current_scene
	var table := Rect2()
	if edge_guard and main != null and "board" in main:
		table = main.board.get_table_rect()
	for node in figure.get_tree().get_nodes_in_group("figures"):
		var other := node as Figure
		if other == figure or other.knocked_off or other.team != figure.team:
			continue
		var direction := nudge_direction(other)
		if edge_guard and table.size != Vector2.ZERO and not table.grow(-160.0).has_point(other.global_position):
			direction = (table.get_center() - other.global_position).normalized()  # near an edge: inward
		other.nudge(direction * nudge_speed)
		if nudged_dealt_bonus > 0.0 or nudged_taken_reduction > 0.0:
			other.temp_dealt = maxf(other.temp_dealt, nudged_dealt_bonus)
			other.temp_taken = minf(other.temp_taken, 1.0 - nudged_taken_reduction)
			other.temp_taken_team = figure.team
		if resets_cycle and main != null and main.has_method("recharge_figure"):
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
