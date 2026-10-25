class_name GluePuddleEffect
extends PowerEffect
## Tap the board: a sticky puddle appears there. Any figure that slides into it stops dead
## (a figure flicked from inside it leaves normally).

@export var puddle_radius := 130.0
## Rounds it lasts. 0 = the rest of the combat.
@export var rounds := 0


func _init() -> void:
	target_mode = Target.POINT
	prompt = "Tap the board to place a puddle"


func apply(main, targets: Array) -> bool:
	main.arena.add_glue_puddle(targets[0], puddle_radius, rounds)
	return true
