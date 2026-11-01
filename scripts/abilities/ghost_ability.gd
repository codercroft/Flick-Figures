class_name GhostAbility
extends FigureAbility
## During its OWN side's turn, whenever it leaves the table it wraps to the opposite edge (Pac-Man style)
## and keeps its velocity: no limit, and no condition on what it touched. During the opponent's turn,
## leaving the table knocks it off as usual. (Damping always slows it, so a wrapping Ghost still comes to
## rest and the turn still ends; `max_settle_time` is the safety net.)

## Upgrade switch (Full Haunt): it can also wrap during the opponent's turn, but only `opponent_wraps_per_turn`
## times per turn; after that it falls off the table normally (so it can still be killed).
@export var wraps_on_opponent_turn := false
@export var opponent_wraps_per_turn := 1

var _opponent_wraps_used := 0


## True while Ghost's side is the one taking its turn.
func _own_turn(figure: Figure) -> bool:
	var combat = RunManager.combat  # the Main node (untyped: Main is not a named class)
	return combat != null and combat.turret_side == figure.team


## Can it wrap right now? Always on its own turn; on the opponent's turn only with the upgrade and wraps left.
func _wraps_now(figure: Figure) -> bool:
	if _own_turn(figure):
		return true
	return wraps_on_opponent_turn and _opponent_wraps_used < opponent_wraps_per_turn


func on_turn_ended(_figure: Figure) -> void:
	_opponent_wraps_used = 0


func on_left_table(figure: Figure, table: Rect2) -> bool:
	if not _wraps_now(figure):
		return false
	if not _own_turn(figure):
		_opponent_wraps_used += 1
	var position := figure.global_position
	# Re-enter from the far side, keeping the same distance past the edge.
	position.x = table.position.x + fposmod(position.x - table.position.x, table.size.x)
	position.y = table.position.y + fposmod(position.y - table.position.y, table.size.y)
	figure.global_position = position
	figure.show_popup("Boo!", Color(0.85, 0.9, 1.0))
	return true


## For the enemy AI: effectively unlimited on its own turn, otherwise the opponent-turn wraps it has left.
func get_wrap_count(figure: Figure) -> int:
	if _own_turn(figure):
		return 99
	return maxi(opponent_wraps_per_turn - _opponent_wraps_used, 0) if wraps_on_opponent_turn else 0
