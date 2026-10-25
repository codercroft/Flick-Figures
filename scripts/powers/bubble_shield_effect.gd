class_name BubbleShieldEffect
extends PowerEffect
## Tap one of your figures: for a round it stops at the table edge instead of falling off.

## Rounds the shield lasts (1 = until the start of your next turn).
@export var rounds := 1


func _init() -> void:
	target_mode = Target.OWN_FIGURE
	prompt = "Tap one of your figures to shield it"


func apply(_main, targets: Array) -> bool:
	targets[0].set_bubble(rounds)
	return true
