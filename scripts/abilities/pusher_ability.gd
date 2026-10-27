class_name PusherAbility
extends FigureAbility
## While Pusher is moving from its OWN flick it never rebounds: it has no bounce of its own and,
## when it hits a figure, whatever speed it would have bounced back with is cancelled, so it stays
## put and the target is pushed. It is NOT heavier than it looks: the push is plain physics with
## its normal mass, so heavy figures barely budge. It reacts normally when it is hit while resting.

var _pushing := false
var _got_going := false  # the flick's speed shows up a physics step after launch()
var _frames := 0
var _base_bounce := 0.0


func on_flicked(figure: Figure, _impulse: Vector2) -> void:
	if _pushing:
		return
	_pushing = true
	_got_going = false
	_frames = 0
	_base_bounce = figure.physics_material_override.bounce
	figure.physics_material_override.bounce = 0.0


## Called after a collision: cancel any speed pointing away from the figure we just hit.
func on_hit(figure: Figure, other: Figure) -> void:
	if not _pushing:
		return
	var toward := (other.global_position - figure.global_position).normalized()
	var along := figure.linear_velocity.dot(toward)
	if along < 0.0:
		figure.linear_velocity -= toward * along


## Checked every physics frame so it ends even if the flick is cut short (forced settle, freeze...).
func on_physics_process(figure: Figure, _delta: float) -> void:
	if not _pushing:
		return
	_frames += 1
	if figure.linear_velocity.length() >= figure.stop_speed:
		_got_going = true
	elif _got_going or _frames > 30:
		_stop_pushing(figure)


func on_knocked_off(figure: Figure) -> void:
	_stop_pushing(figure)


func is_plowing(_figure: Figure) -> bool:
	return _pushing


func _stop_pushing(figure: Figure) -> void:
	if not _pushing:
		return
	_pushing = false
	figure.physics_material_override.bounce = _base_bounce


func get_flick_bounce(_figure: Figure) -> float:
	return 0.0


func cancels_rebound(_figure: Figure) -> bool:
	return true
