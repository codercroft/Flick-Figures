class_name TrophyCaseEffect
extends RelicEffect
## Figure reward screens offer more choices.

@export var extra_choices := 1


func get_reward_choice_bonus() -> int:
	return extra_choices
