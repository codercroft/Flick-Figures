class_name PusherAbility
extends FigureAbility
## Pusher: short range, but it shoves. During its OWN flick it counts as heavier on its hits
## (`hit_mass_multiplier`), it never rebounds (little bounce of its own, and any speed pointing away from
## the figure it hit is cancelled), and after its first contact it keeps driving forward into the target
## (`drive_acceleration`) for up to `push_seconds`. When that time is up the push ends and it is a normal
## figure again (it can rebound and slows down normally). A faint glow shows the push, fading with the timer.
## It reacts normally when it is hit while resting.

## Its mass while pushing (on its own flick) is multiplied by this: 1.75 = hits as if 75% heavier.
@export var hit_mass_multiplier := 1.75
## After touching a figure it keeps pushing with this acceleration (px/s per second)...
@export var drive_acceleration := 2600.0
## ...and the whole push (driving, no rebound, extra weight) lasts at most this long (seconds) from its first
## contact during a flick. It drives only while it is still touching a target.
@export var push_seconds := 2.5
## Color of the glow shown while the push is active (it fades out as the timer runs down).
@export var glow_color := Color(1.0, 0.85, 0.3)
## Bounce it has during its own flick. Godot adds the two bounce values, so 0 would make every hit nearly
## inelastic and weaken the push; a little keeps the transfer full. It still never rebounds (see above).
@export var flick_bounce := 0.3

var _pushing := false
var _got_going := false  # the flick's speed shows up a physics step after launch()
var _frames := 0
var _base_bounce := 0.0
var _base_mass := 0.0
var _drive_target: Figure
var _drive_direction := Vector2.ZERO
var _drive_left := 0.0  # seconds of push left; 0 until the first contact
var _touched := false  # has it made contact during this flick yet


func on_flicked(figure: Figure, _impulse: Vector2) -> void:
	if _pushing:
		return
	_pushing = true
	_got_going = false
	_frames = 0
	_drive_left = 0.0
	_touched = false
	_base_bounce = figure.physics_material_override.bounce
	_base_mass = figure.mass
	figure.physics_material_override.bounce = flick_bounce
	# The flick's speed is already set, so changing the mass now doesn't slow it down.
	figure.mass = _base_mass * hit_mass_multiplier


## After a collision: no rebound, and start driving into the target.
func on_hit(figure: Figure, other: Figure) -> void:
	if not _pushing:
		return
	var toward := (other.global_position - figure.global_position).normalized()
	var along := figure.linear_velocity.dot(toward)
	if along < 0.0:
		figure.linear_velocity -= toward * along
	_drive_target = other
	_drive_direction = toward
	if not _touched:  # the timer starts at the first contact only
		_touched = true
		_drive_left = push_seconds


## Checked every physics frame: keeps driving after contact, and ends when the flick is over.
func on_physics_process(figure: Figure, delta: float) -> void:
	if not _pushing:
		return
	_frames += 1
	if _touched:
		_drive_left -= delta
		if _drive_left <= 0.0:  # time is up: normal figure again
			_stop_pushing(figure)
			return
		if is_instance_valid(_drive_target) and not _drive_target.knocked_off \
				and figure.global_position.distance_to(_drive_target.global_position) < figure.radius + _drive_target.radius + 25.0:
			figure.apply_central_force(_drive_direction * drive_acceleration * _base_mass)
		figure.queue_redraw()  # the glow fades with the timer
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
	_touched = false
	_drive_left = 0.0
	figure.queue_redraw()
	figure.physics_material_override.bounce = _base_bounce
	figure.mass = _base_mass


func get_flick_bounce(_figure: Figure) -> float:
	return flick_bounce


func cancels_rebound(_figure: Figure) -> bool:
	return true


## What the enemy AI should use for this figure's mass when it predicts a hit.
func get_hit_mass_multiplier(_figure: Figure) -> float:
	return hit_mass_multiplier


## A subtle glow around the figure while the push is active, fading out as the timer runs down.
func draw_overlay(figure: Figure) -> void:
	if not _pushing or not _touched:
		return
	var strength := clampf(_drive_left / push_seconds, 0.0, 1.0)
	var color := glow_color
	color.a = 0.45 * strength
	figure.draw_circle(Vector2.ZERO, figure.radius * 1.15, color)
	color.a = 0.8 * strength
	figure.draw_arc(Vector2.ZERO, figure.radius * 1.15, 0.0, TAU, 48, color, 4.0, true)
