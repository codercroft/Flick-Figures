class_name CleanSheetEffect
extends RelicEffect
## Win a combat without losing a figure to gain a random power.


func on_combat_won(run, info: Dictionary) -> String:
	if info.figures_lost > 0:
		return ""
	var power: PowerData = run.random_power()
	if power == null:
		return ""
	if run.add_power(power):
		return "Clean Sheet: gained %s!" % power.display_name
	return "Clean Sheet: power slots full."
