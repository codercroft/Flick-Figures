class_name BombDropEffect
extends PowerEffect
## Tap a point on the board: an explosion goes off there, pushing every figure nearby.

@export var blast_radius := 330.0
@export var blast_force := 2600.0


func _init() -> void:
	target_mode = Target.POINT
	settle_after = true
	prompt = "Tap the board to drop a bomb"


func apply(main, targets: Array) -> bool:
	main.explode_at(targets[0], blast_radius, blast_force)
	return true
