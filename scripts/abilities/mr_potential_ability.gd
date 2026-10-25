class_name MrPotentialAbility
extends FigureAbility
## While on the board, takes extra knockback from figures on his own team,
## so you can bonk him into the other side.

@export var team_knockback_multiplier := 2.0


func get_knockback_multiplier(figure: Figure, source: Figure) -> float:
	if source != null and not figure.on_deck and source.team == figure.team:
		return team_knockback_multiplier
	return 1.0
