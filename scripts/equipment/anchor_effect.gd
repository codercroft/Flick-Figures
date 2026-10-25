class_name AnchorEffect
extends FigureAbility
## Ignores light hits: a hit slower than the threshold doesn't move it at all.

## Hits with a relative speed below this (px/s) are ignored.
@export var impact_threshold := 500.0


func get_hit_multiplier(_figure: Figure, _other: Figure, impact_speed: float) -> float:
	return 0.0 if impact_speed < impact_threshold else 1.0
