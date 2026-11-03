class_name MagnetCharmEffect
extends MagnetAbility
## A weak version of the Magnet figure's pull on nearby moving figures (same tunables, weaker defaults).


func on_knocked_off(_figure: Figure) -> void:
	pass  # (only the Magnet figure implodes)


func _init() -> void:
	pull_radius = 320.0
	inner_radius = 90.0
	pull_acceleration = 380.0
