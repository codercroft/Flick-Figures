class_name LuckyCoinEffect
extends RelicEffect
## Extra money after every won combat.

@export var bonus := 2


func get_income_bonus() -> int:
	return bonus
