class_name UnderdogEffect
extends RelicEffect
## More flick power while you have fewer figures on the table than the enemy.

## Flick power multiplier while behind (1.5 = +50%).
@export var power_multiplier := 1.5


func get_flick_power_multiplier(main, _figure: Figure) -> float:
	return power_multiplier if main.get_player_count() < main.get_enemy_count() else 1.0
