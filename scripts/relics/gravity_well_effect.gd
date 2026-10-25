class_name GravityWellEffect
extends RelicEffect
## Magnet-type pulls (Magnet, Magnet Charm, Magnet Throw) are stronger.

@export var pull_multiplier := 2.0


func get_pull_multiplier() -> float:
	return pull_multiplier
