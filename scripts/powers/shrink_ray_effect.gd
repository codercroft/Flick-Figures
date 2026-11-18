class_name ShrinkRayEffect
extends PowerEffect
## Tap an enemy: it shrinks 25% (radius x0.75, mass x0.75) for the rest of the combat.

@export var size_factor := 0.75
@export var mass_factor := 0.75


func _init() -> void:
	target_mode = Target.ENEMY
	prompt = "Tap an enemy to shrink it"


func apply(main, targets: Array) -> bool:
	var figure: Figure = targets[0]
	if figure.shrunk:
		main.notice("It is already shrunk")
		return false
	figure.shrink(size_factor, mass_factor)
	return true
