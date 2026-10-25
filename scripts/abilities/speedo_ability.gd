class_name SpeedoAbility
extends FigureAbility
## Can be flicked more than once per turn. After the first flick settles, the player may flick
## it again from where it stopped (or tap to skip). The enemy AI only takes the extra shot if
## it scores well (EnemyAI.bonus_flick_min_score).

## Flicks per turn, counting the first one.
@export var flicks_per_turn := 2


func get_flicks_per_turn(_figure: Figure) -> int:
	return flicks_per_turn
