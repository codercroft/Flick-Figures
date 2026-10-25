class_name BlastCapEffect
extends RelicEffect
## Explosions are bigger.

## Explosion size multiplier (1.5 = 50% bigger).
@export var radius_multiplier := 1.5


func get_explosion_radius_multiplier() -> float:
	return radius_multiplier
