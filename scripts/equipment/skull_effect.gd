class_name SkullEffect
extends FigureAbility
## Mr Potential's Skull: while on the board, the figure takes extra knockback from its OWN team's figures,
## so you can bonk it into the other side (and the enemy can too).

@export var team_knockback_multiplier := 2.0


func get_knockback_multiplier(figure: Figure, source: Figure) -> float:
	if source != null and not figure.on_deck and source.team == figure.team:
		return team_knockback_multiplier
	return 1.0
