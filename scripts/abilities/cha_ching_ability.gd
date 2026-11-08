class_name ChaChingAbility
extends FigureAbility
## Earns money for every enemy knocked off while it is still on the table. (Its +$ for surviving a
## won combat is the `income_bonus` on its FigureData.)

## Money earned each time an enemy is knocked off.
@export var knock_off_bonus := 1
## Bounty path: extra money for a knock-off made by its OWN flick.
@export var own_kill_bonus := 0
## Savings path: extra figure choices after a won combat while it is on the table.
@export var reward_choice_bonus := 0


func on_opponent_knocked_off(figure: Figure, _victim: Figure) -> void:
	var amount := knock_off_bonus
	var main := figure.get_tree().current_scene
	if own_kill_bonus > 0 and main != null and "_flicker" in main and main._flicker == figure:
		amount += own_kill_bonus
	RunManager.money += amount
	figure.show_popup("+$%d" % amount)


func get_reward_choice_bonus(_figure: Figure) -> int:
	return reward_choice_bonus
