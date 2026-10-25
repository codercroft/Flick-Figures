class_name HomeFieldEffect
extends RelicEffect
## Your figures take less knockback while in your bottom third of the board.

## Knockback taken there (0.5 = half).
@export var knockback_multiplier := 0.5


func get_knockback_taken_multiplier(figure: Figure, _source: Figure) -> float:
	var main = RunManager.combat
	if main == null or figure.team != Figure.Team.PLAYER:
		return 1.0
	var board: Rect2 = main.board.board_rect
	return knockback_multiplier if figure.global_position.y >= board.position.y + board.size.y * 2.0 / 3.0 else 1.0
