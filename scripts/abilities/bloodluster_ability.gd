class_name BloodlusterAbility
extends FigureAbility
## If its flick knocks an opposing figure off the table (any knock-off that flick causes, knock-on hits included)
## it can be flicked again right away from where it stopped, before the other side moves; the player may tap to
## skip it. It can chain while each flick gets a kill, up to `max_bonus_flicks` per turn. No bonus if Bloodluster
## itself was knocked off. Bonus flicks do not count against the flick cycle (it is only marked flicked once).

@export var max_bonus_flicks := 2


func get_bloodlust_cap(_figure: Figure) -> int:
	return max_bonus_flicks
