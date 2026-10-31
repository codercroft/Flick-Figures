class_name BloodlusterAbility
extends FigureAbility
## If its flick knocks an opposing figure off the table (any knock-off that flick causes, knock-on hits included)
## it can be flicked again right away from where it stopped, before the other side moves; the player may tap to
## skip it. It chains for as long as each flick gets a kill (no cap). No bonus if Bloodluster itself was knocked
## off. Bonus flicks do not count against the flick cycle (it is only marked flicked once).

## "No limit" for get_bloodlust_cap (the chain only ends when a flick gets no kill, or you skip).
const UNLIMITED := 1000000


func get_bloodlust_cap(_figure: Figure) -> int:
	return UNLIMITED
