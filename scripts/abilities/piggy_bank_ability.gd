class_name PiggyBankAbility
extends FigureAbility
## Hits harder the more money the player holds: every figure it hits gets extra knockback,
## scaled by the player's current $.

## Extra knockback per $ held (0.05 = +5% per $).
@export var bonus_per_dollar := 0.05
## The bonus never goes above this (1.0 = +100%).
@export var max_bonus := 1.0


func on_impact(figure: Figure, other: Figure, speed: float, _point: Vector2) -> void:
	var direction := (other.global_position - figure.global_position).normalized()
	# Only when the Piggy Bank is the one doing the hitting.
	if figure._prev_velocity.dot(direction) + other._prev_velocity.dot(direction) <= 0.0:
		return
	var bonus := minf(RunManager.money * bonus_per_dollar, max_bonus)
	if bonus <= 0.0:
		return
	# Roughly the speed a normal hit gives the other figure, times the bonus.
	var share := figure.mass / (figure.mass + other.mass)
	other.take_knockback(direction * speed * share * bonus * other.mass, figure)
