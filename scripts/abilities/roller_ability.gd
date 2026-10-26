class_name RollerAbility
extends FigureAbility
## While Roller is moving from its OWN flick it plows: it doesn't rebound off the figures it hits, it
## keeps its momentum and pushes them as if it were much heavier, and its own bounce and Bumper's
## extra knockback don't apply to it. It reacts normally when it is hit while resting.
## (Done with physics: for the length of the flick its mass is multiplied and its bounce is zero.)

## Its mass while plowing is multiplied by this. Higher = pushes harder and loses less speed.
@export var plow_mass_multiplier := 8.0

var _plowing := false
var _base_mass := 0.0
var _base_bounce := 0.0


func on_flicked(figure: Figure, _impulse: Vector2) -> void:
	if _plowing:
		return
	_plowing = true
	_base_mass = figure.mass
	_base_bounce = figure.physics_material_override.bounce
	# The flick's speed is already set, so changing the mass now doesn't slow it down.
	figure.mass = _base_mass * plow_mass_multiplier
	figure.physics_material_override.bounce = 0.0


## Checked every physics frame so it ends even if the flick is cut short (forced settle, freeze...).
func on_physics_process(figure: Figure, _delta: float) -> void:
	if _plowing and figure.linear_velocity.length() < figure.stop_speed:
		_stop_plowing(figure)


func on_knocked_off(figure: Figure) -> void:
	_stop_plowing(figure)


func is_plowing(_figure: Figure) -> bool:
	return _plowing


func _stop_plowing(figure: Figure) -> void:
	if not _plowing:
		return
	_plowing = false
	figure.mass = _base_mass
	figure.physics_material_override.bounce = _base_bounce
