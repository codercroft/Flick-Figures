class_name GlitterEffect
extends FigureAbility
## Glitter finish: hits it deals push the other figure harder.

## Extra knockback dealt (0.25 = +25%).
@export var knockback_bonus := 0.25


func on_impact(figure: Figure, other: Figure, _speed: float, _point: Vector2) -> void:
	extra_hit_knockback(figure, other, knockback_bonus)
