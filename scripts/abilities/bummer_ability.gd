class_name BummerAbility
extends FigureAbility
## Average figure with a small aura (drawn faintly). OPPOSING figures inside it get reckless:
## - the player's figures flick with extra power and a shortened aim line (harder to control);
## - enemy figures flick with extra power and extra aim error, and the enemy AI stops worrying about
##   knocking itself off the table (so they often fly off). The enemy AI also tries to keep its figures
##   out of a player Bummer's aura.

## Radius (px) of the aura.
@export var aura_radius := 260.0
## Flick power multiplier for opposing figures inside it (1.4 = +40%).
@export var power_multiplier := 1.4
## Extra aim error (degrees, either way) for enemy figures flicking inside it.
@export var ai_aim_error_degrees := 12.0
## The aim line of a player figure inside it is drawn this fraction as long as it should be.
@export_range(0.1, 1.0) var aim_line_scale := 0.5


func get_bummer_stats(_figure: Figure) -> Dictionary:
	return {"radius": aura_radius, "power": power_multiplier, "aim_error_degrees": ai_aim_error_degrees,
			"aim_line_scale": aim_line_scale}
