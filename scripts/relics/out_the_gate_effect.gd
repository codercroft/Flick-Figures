class_name OutTheGateEffect
extends RelicEffect
## On the player's first turn of each combat they flick twice (normal cycle rules; the second flick can be skipped).


func grants_first_turn_extra_flick() -> bool:
	return true
