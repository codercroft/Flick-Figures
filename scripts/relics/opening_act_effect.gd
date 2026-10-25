class_name OpeningActEffect
extends RelicEffect
## The first flick of each combat has extra power.

@export var power_multiplier := 2.0


func get_flick_power_multiplier(main, _figure: Figure) -> float:
	return power_multiplier if main.player_flicks == 0 else 1.0
