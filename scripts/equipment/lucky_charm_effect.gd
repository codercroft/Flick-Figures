class_name LuckyCharmEffect
extends FigureAbility
## Enemy shots aimed at this figure are less accurate.

## Extra aim error (degrees, either way) added to enemy shots aimed at it.
@export var extra_aim_error_degrees := 15.0


func get_incoming_aim_error_degrees(_figure: Figure) -> float:
	return extra_aim_error_degrees
