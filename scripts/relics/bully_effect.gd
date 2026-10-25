class_name BullyEffect
extends RelicEffect
## Your figures knock enemies near the table edge much harder.

## Knockback an enemy takes from your figures when it is near the edge.
@export var knockback_multiplier := 2.0
## "Near the edge" = its center is this close (px) to the table edge.
@export var edge_distance := 200.0


func get_knockback_taken_multiplier(figure: Figure, source: Figure) -> float:
	var main = RunManager.combat
	if main == null or source == null or figure.team != Figure.Team.ENEMY or source.team != Figure.Team.PLAYER:
		return 1.0
	var table: Rect2 = main.board.get_table_rect()
	var pos := figure.global_position
	var nearest := minf(minf(pos.x - table.position.x, table.end.x - pos.x), minf(pos.y - table.position.y, table.end.y - pos.y))
	return knockback_multiplier if nearest <= edge_distance else 1.0
