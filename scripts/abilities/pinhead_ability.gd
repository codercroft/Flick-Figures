class_name PinheadAbility
extends FigureAbility
## Average figure. While it is selected and before it is flicked, the player can TAP any empty spot
## on the board to place one temporary pin there (a solid bouncy bumper, same as an arena pin). The
## pin disappears once Pinhead's flick has settled. Tapping the pin again takes it back. Placing a
## pin is optional. An enemy Pinhead may place a pin that sets up a bank shot (see EnemyAI).

## Size of the pin (arena pins are 28).
@export var pin_radius := 28.0


func get_pin_radius(_figure: Figure) -> float:
	return pin_radius
