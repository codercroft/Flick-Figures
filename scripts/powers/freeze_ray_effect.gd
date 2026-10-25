class_name FreezeRayEffect
extends PowerEffect
## Tap an enemy: it can't flick and can't be moved for a round.

## Rounds it stays frozen (1 = until the start of your next turn).
@export var rounds := 1


func _init() -> void:
	target_mode = Target.ENEMY
	prompt = "Tap an enemy to freeze it"


func apply(_main, targets: Array) -> bool:
	targets[0].freeze_for(rounds)
	return true
