class_name BummerAbility
extends FigureAbility
## Average figure with a very small aura (drawn faintly). When an OPPOSING figure is inside it at the moment
## its side goes to flick it, control is taken away ("Bummed out!") and the figure instead takes a shot
## chosen by the enemy AI with inverted goals: knock ITSELF off the table and hit its own teammates on the
## way (see EnemyAI.choose_takeover). The takeover counts as that figure's flick for the cycle.
## A figure counts as inside when its body touches the aura circle.

## Radius (px) of the aura from the Bummer's center (about 1.5x its own radius of 60).
@export var aura_radius := 90.0


func get_bummer_stats(_figure: Figure) -> Dictionary:
	return {"radius": aura_radius}
