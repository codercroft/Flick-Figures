class_name SpeedoAbility
extends FigureAbility
## Can be flicked more than once per turn. After the first flick settles, the player may flick
## it again from where it stopped (or tap to skip). The enemy AI only takes the extra shot if
## it scores well (EnemyAI.bonus_flick_min_score).
## Dash path: each flick in a turn is `power_per_flick` stronger than the one before. Zip path (Kill Rush): a knock-off
## made by its own flick earns an extra flick this turn.

## Flicks per turn, counting the first one.
@export var flicks_per_turn := 2
@export var power_per_flick := 0.0
@export var kill_extra_flick := false

var _extra := 0


func get_flicks_per_turn(_figure: Figure) -> int:
	return flicks_per_turn + _extra


func get_flick_power_multiplier(figure: Figure) -> float:
	return 1.0 + power_per_flick * figure.turn_flicks


func on_opponent_knocked_off(figure: Figure, _victim: Figure) -> void:
	var main := figure.get_tree().current_scene
	if kill_extra_flick and main != null and "_flicker" in main and main._flicker == figure:
		_extra += 1
		figure.show_popup("Extra flick!", Color(1.0, 0.9, 0.4))


func on_turn_ended(figure: Figure) -> void:
	var main := figure.get_tree().current_scene
	if main != null and "turret_side" in main and main.turret_side != figure.team:
		_extra = 0  # a fresh turn of its own side begins
