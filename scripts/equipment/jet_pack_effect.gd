class_name JetPackEffect
extends FigureAbility
## One extra flick per combat, at reduced power. After the figure's normal flick settles you may
## flick it again (or tap to skip; the charge is only spent when you do flick).

## Extra flicks per combat.
@export var charges := 1
## Force of the extra flick (0.5 = half power).
@export var extra_flick_power := 0.5

var _charges_left := -1


func _left() -> int:
	if _charges_left < 0:
		_charges_left = charges
	return _charges_left


func get_flicks_per_turn(_figure: Figure) -> int:
	return 2 if _left() > 0 else 1


func get_flick_power_multiplier(figure: Figure) -> float:
	return extra_flick_power if figure.turn_flicks >= 1 else 1.0


func on_flicked(figure: Figure, _impulse: Vector2) -> void:
	if figure.turn_flicks >= 2:
		_charges_left = _left() - 1
		figure.show_popup("Whoosh!", Color(1.0, 0.8, 0.5))
