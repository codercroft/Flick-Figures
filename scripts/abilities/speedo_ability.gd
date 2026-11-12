class_name SpeedoAbility
extends FigureAbility
## Can be flicked more than once per turn. After the first flick settles, the player may flick
## it again from where it stopped (or tap to skip). The enemy AI only takes the extra shot if
## it scores well (EnemyAI.bonus_flick_min_score).
## Dash path: each flick in a turn is `power_per_flick` stronger than the one before; every flick Speedo has taken this combat
## adds `flick_knockback_per_flick` knockback dealt (stacking up to `max_flick_stacks`); Triple Dash raises the flicks per turn.
## Zip path: `knockback_dealt_bonus` extra knockback dealt always.

## Flicks per turn, counting the first one.
@export var flicks_per_turn := 2
@export var power_per_flick := 0.0
## Dash tier 2: knockback dealt +this per flick taken this combat (each flick, bonus flicks included), up to `max_flick_stacks` flicks.
@export var flick_knockback_per_flick := 0.0
@export var max_flick_stacks := 10
## Zip tier 3: flat extra knockback dealt (0.25 = +25%).
@export var knockback_dealt_bonus := 0.0

var _combat_flicks := 0


func get_flicks_per_turn(_figure: Figure) -> int:
	return flicks_per_turn


func get_flick_power_multiplier(figure: Figure) -> float:
	return 1.0 + power_per_flick * figure.turn_flicks


func on_flicked(_figure: Figure, _impulse: Vector2) -> void:
	_combat_flicks += 1


func get_dealt_knockback_bonus(_figure: Figure, _other: Figure) -> float:
	return knockback_dealt_bonus + flick_knockback_per_flick * mini(_combat_flicks, max_flick_stacks)
