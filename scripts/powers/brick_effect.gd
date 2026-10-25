class_name BrickEffect
extends PowerEffect
## Tap the board: a short wall segment appears there and lasts a couple of rounds.

## Size (px) of the wall segment (wide, then tall).
@export var brick_size := Vector2(240.0, 44.0)
## Rounds it lasts (2 = through the enemy's turn and the next full round).
@export var rounds := 2


func _init() -> void:
	target_mode = Target.POINT
	prompt = "Tap the board to place a brick"


func apply(main, targets: Array) -> bool:
	if not main.arena.add_brick(targets[0], brick_size, rounds):
		main.notice("No room for a brick there")
		return false
	return true
