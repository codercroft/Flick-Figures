class_name PinataAbility
extends FigureAbility
## Caught in an explosion, it pays the player some money and is pushed back less far.

## Money paid each time it is caught in an explosion.
@export var payout := 2
## It can only pay this many times per combat.
@export var max_payouts := 3
## How much of the explosion's push it takes (1 = normal).
@export var explosion_push_scale := 0.4

var _paid := 0


func get_explosion_multiplier(_figure: Figure, _source: Figure) -> float:
	return explosion_push_scale


func on_exploded(figure: Figure, _source: Figure) -> void:
	if _paid >= max_payouts:
		return
	_paid += 1
	RunManager.money += payout
	figure.show_popup("+$%d" % payout)
