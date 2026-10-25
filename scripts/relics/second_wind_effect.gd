class_name SecondWindEffect
extends RelicEffect
## The first of your figures knocked off each combat returns to the deck strip instead.
## (RelicData effects are shared, so the "used" flag lives on the Main node and resets each combat.)


func on_player_figure_falling(main, figure: Figure) -> bool:
	if main.second_wind_used:
		return false
	main.second_wind_used = true
	figure.return_to_deck()
	figure.show_popup("Second wind!", Color(0.6, 1.0, 0.7))
	return true
