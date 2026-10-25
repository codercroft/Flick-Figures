class_name MagnetThrowEffect
extends PowerEffect
## Tap the board: a magnet field appears there and bends the path of moving figures (both
## sides) for a round.

## How far (px) the field reaches.
@export var field_radius := 450.0
## Inside this distance (px) of the center there is no pull.
@export var inner_radius := 90.0
## Pull (px/s per second) at the edge of the field; it fades to zero at inner_radius.
@export var pull_acceleration := 1400.0
@export var rounds := 1


func _init() -> void:
	target_mode = Target.POINT
	prompt = "Tap the board to place a magnet"


func apply(main, targets: Array) -> bool:
	main.arena.add_magnet_zone(targets[0], field_radius, inner_radius, pull_acceleration, rounds)
	return true
