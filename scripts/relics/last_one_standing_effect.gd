class_name LastOneStandingEffect
extends RelicEffect
## Your last remaining figure flicks harder and takes less knockback.

@export var power_multiplier := 2.0
@export var knockback_multiplier := 0.5


func get_flick_power_multiplier(main, _figure: Figure) -> float:
	return power_multiplier if main.get_player_count() == 1 else 1.0


func get_knockback_taken_multiplier(figure: Figure, _source: Figure) -> float:
	var main = RunManager.combat
	if main == null or figure.team != Figure.Team.PLAYER:
		return 1.0
	return knockback_multiplier if main.get_player_count() == 1 else 1.0
