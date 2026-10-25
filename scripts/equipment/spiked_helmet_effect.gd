class_name SpikedHelmetEffect
extends FigureAbility
## Hits it deals push the other figure harder.

## Extra knockback dealt (0.4 = +40%).
@export var knockback_bonus := 0.4


func on_impact(figure: Figure, other: Figure, _speed: float, _point: Vector2) -> void:
	extra_hit_knockback(figure, other, knockback_bonus)
