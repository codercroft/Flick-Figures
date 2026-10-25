class_name GrippyTableEffect
extends RelicEffect
## Your figures stop sooner.

## Share of the usual slide distance your figures lose (0.3 = they stop 30% sooner).
@export_range(0.0, 0.9) var shorter_slide := 0.3


func get_player_damping_multiplier() -> float:
	return 1.0 / (1.0 - shorter_slide)
