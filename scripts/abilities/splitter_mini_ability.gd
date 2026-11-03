class_name SplitterMiniAbility
extends FigureAbility
## A Splitter's mini: sturdy (bigger and heavier than before) but it does not hit hard. Its flick power is
## on splitter_mini.tres (flick_power_multiplier 0.7); this reduces the knockback it deals.

## Knockback dealt (0.75 = 25% less push on whatever it hits).
@export var knockback_dealt := 0.75


func on_impact(figure: Figure, other: Figure, _speed: float, _point: Vector2) -> void:
	extra_hit_knockback(figure, other, knockback_dealt - 1.0)
