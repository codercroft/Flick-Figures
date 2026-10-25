class_name PowerhouseAbility
extends FigureAbility
## Hits hard (its 2x flick power is on the FigureData), but takes extra knockback from enemy figures.

@export var enemy_knockback_multiplier := 2.0


func get_knockback_multiplier(figure: Figure, source: Figure) -> float:
	if source != null and source.team != figure.team:
		return enemy_knockback_multiplier
	return 1.0
