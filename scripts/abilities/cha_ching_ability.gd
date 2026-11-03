class_name ChaChingAbility
extends FigureAbility
## Earns money for every enemy knocked off while it is still on the table. (Its +$ for surviving a
## won combat is the `income_bonus` on its FigureData.)

## Money earned each time an enemy is knocked off.
@export var knock_off_bonus := 1


func on_opponent_knocked_off(figure: Figure, _victim: Figure) -> void:
	var amount := maxi(knock_off_bonus - RunManager.cha_ching_reduction(), 0)  # (Ascension 4 pays $1 less)
	if amount <= 0:
		return
	RunManager.money += amount
	figure.show_popup("+$%d" % amount)
