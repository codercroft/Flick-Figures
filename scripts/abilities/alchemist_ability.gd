class_name AlchemistAbility
extends FigureAbility
## Instead of flicking, the Alchemist can spend its turn tapping an empty spot on the board to place a small
## debuff zone there: opposing figures inside it take extra knockback. The zone lasts until the Alchemist's side's
## flick cycle resets, and placing it counts as the Alchemist's action for the cycle. One zone per Alchemist
## (a new one replaces the old). It can still flick normally instead.

## Size of the zone (px radius).
@export var zone_radius := 150.0
## Opposing figures inside it take this many times the knockback (1.5 = +50%).
@export var knockback_multiplier := 1.5


func get_zone_stats(_figure: Figure) -> Dictionary:
	return {"radius": zone_radius, "knockback": knockback_multiplier}
