class_name PinheadAbility
extends FigureAbility
## Average figure. While it is selected and before it is flicked, the player can TAP any empty spot
## on the board to place one temporary pin there (a solid bouncy bumper, same as an arena pin). The
## pin disappears once Pinhead's flick has settled. Tapping the pin again takes it back. Placing a
## pin is optional. An enemy Pinhead may place a pin that sets up a bank shot (see EnemyAI).

## Size of the pin (arena pins are 28).
@export var pin_radius := 28.0
## Pin Count path: pins placed per turn and kept at once; Lasting Pins stay the whole combat (at most `permanent_cap` in all).
@export var pins_per_turn := 1
@export var max_pins := 1
@export var permanent_pins := false
@export var permanent_cap := 4
## Bumper Pins path: launch multiplier (the arena's pin_kick is 1.3; 0 = the normal one), opponents that hit a pin get
## Doused, and a pin explodes the first time an opponent hits it.
@export var pin_kick := 0.0
@export var douse_hitters := false
@export var explode_force := 0.0
@export var explode_radius := 180.0


func get_pin_radius(_figure: Figure) -> float:
	return pin_radius


func get_pin_options(_figure: Figure) -> Dictionary:
	return {"per_turn": pins_per_turn, "max": max_pins, "permanent": permanent_pins, "cap": permanent_cap,
			"kick": pin_kick, "douse": douse_hitters, "explode_force": explode_force, "explode_radius": explode_radius}
