class_name AlchemistAbility
extends FigureAbility
## Tapping an empty spot on the board places a small debuff zone there: opposing figures inside it take extra
## knockback. At most ONE placement per turn (locked in, no moving it until the next turn) and it does NOT use up
## the Alchemist's flick: it can place and then flick. The zone lasts until the Alchemist's side's flick cycle
## resets; one zone per Alchemist (placing on a later turn replaces the old one).
## Any opposing figure that touches or passes through the zone is "Doused": it keeps the extra knockback for
## `douse_rounds` rounds even after it leaves the zone. Touching a zone again refreshes the time (no stacking).

## Size of the zone (px radius).
@export var zone_radius := 150.0
## Opposing figures inside it take this many times the knockback (1.5 = +50%).
@export var knockback_multiplier := 1.5


## How many rounds a figure stays Doused (a round = one player turn plus one enemy turn).
@export var douse_rounds := 2


func get_zone_stats(_figure: Figure) -> Dictionary:
	return {"radius": zone_radius, "knockback": knockback_multiplier, "douse_rounds": douse_rounds}
