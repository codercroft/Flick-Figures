class_name GhostAbility
extends FigureAbility
## During its OWN side's turn, whenever it leaves the table it wraps to the opposite edge (Pac-Man style)
## and keeps its velocity: no limit, and no condition on what it touched. During the opponent's turn,
## leaving the table knocks it off as usual. (Damping always slows it, so a wrapping Ghost still comes to
## rest and the turn still ends; `max_settle_time` is the safety net.)

## Upgrade switch: it also wraps during the opponent's turn.
@export var wraps_on_opponent_turn := false


## True while Ghost's side is the one taking its turn (or the upgrade lets it wrap any time).
func _wraps_now(figure: Figure) -> bool:
	if wraps_on_opponent_turn:
		return true
	var combat = RunManager.combat  # the Main node (untyped: Main is not a named class)
	return combat != null and combat.turret_side == figure.team


func on_left_table(figure: Figure, table: Rect2) -> bool:
	if not _wraps_now(figure):
		return false
	var position := figure.global_position
	# Re-enter from the far side, keeping the same distance past the edge.
	position.x = table.position.x + fposmod(position.x - table.position.x, table.size.x)
	position.y = table.position.y + fposmod(position.y - table.position.y, table.size.y)
	figure.global_position = position
	figure.show_popup("Boo!", Color(0.85, 0.9, 1.0))
	return true


## For the enemy AI: effectively unlimited while it wraps (the slide ends by damping, not by a wrap count).
func get_wrap_count(figure: Figure) -> int:
	return 99 if _wraps_now(figure) else 0
