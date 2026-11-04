class_name AbsorberAbility
extends FigureAbility
## A big, short-range figure. When its own flick hits an OPPOSING figure with a smaller radius at `absorb_speed`
## or more, it absorbs it: the figure is held inside (removed from play, shown shrinking in its belly), one at a
## time. The held figure shrinks over `shrink_rounds` rounds; when it is fully shrunk it counts as knocked off. If
## a teammate of the held figure hits the Absorber at `escape_speed` or more, the held figure pops out at its
## current (reduced) size. Bosses, boss pieces and other uneatable figures cannot be absorbed. If the Absorber
## itself is knocked off, the held figure pops out where it fell.

## Minimum impact speed (px/s) of the Absorber's own hit to absorb something.
@export var absorb_speed := 300.0
## Minimum impact speed (px/s) of a teammate of the held figure to free it.
@export var escape_speed := 500.0
## Rounds until the held figure is fully shrunk (and counts as knocked off).
@export var shrink_rounds := 3

var held: Figure
var _held_radius := 0.0
var _held_mass := 0.0
var _held_rounds := 0
var _armed := false


func on_flicked(_figure: Figure, _impulse: Vector2) -> void:
	_armed = true


func on_stopped(_figure: Figure) -> void:
	_armed = false


func on_impact(figure: Figure, other: Figure, speed: float, _point: Vector2) -> void:
	if figure.knocked_off or other.knocked_off:
		return
	if held != null and not is_instance_valid(held):
		held = null
	if held != null:
		if other.team == held.team and speed >= escape_speed:
			_release(figure)
		return
	if not _armed or speed < absorb_speed or other.team == figure.team:
		return
	if other.radius >= figure.radius or other.data.uneatable or other.data.boss_body:
		return
	var main := figure.get_tree().current_scene
	if main == null or not main.has_method("absorb_figure"):
		return
	held = other
	_held_radius = other.radius
	_held_mass = other.mass
	_held_rounds = 0
	_armed = false
	main.absorb_figure(other)
	figure.show_popup("Gulp!", Color(0.8, 0.5, 0.9))


func on_round_ticked(figure: Figure) -> void:
	if held == null:
		return
	if not is_instance_valid(held):
		held = null
		return
	_held_rounds += 1
	if _held_rounds >= shrink_rounds:
		var victim := held
		held = null
		var main := figure.get_tree().current_scene
		if main != null and main.has_method("finish_absorbed"):
			main.finish_absorbed(victim)
		return
	var share := _share()
	held.set_size(_held_radius * share, _held_mass * share)


func on_knocked_off(figure: Figure) -> void:
	if held != null:
		_release(figure)


func _share() -> float:
	return clampf(1.0 - float(_held_rounds) / float(maxi(shrink_rounds, 1)), 0.05, 1.0)


func _release(figure: Figure) -> void:
	var victim := held
	held = null
	if not is_instance_valid(victim):
		return
	var main := figure.get_tree().current_scene
	if main != null and main.has_method("release_absorbed"):
		main.release_absorbed(victim, figure.global_position)
		figure.show_popup("Escaped!", Color(0.9, 0.9, 0.5))


func get_absorb_speed(_figure: Figure) -> float:
	return absorb_speed if held == null else 0.0


func get_escape_speed(_figure: Figure) -> float:
	return escape_speed if held != null and is_instance_valid(held) else 0.0


func get_held_figure(_figure: Figure) -> Figure:
	return held if is_instance_valid(held) else null


## The held figure, shrinking inside the belly.
func draw_overlay(figure: Figure) -> void:
	if held == null or not is_instance_valid(held):
		return
	var inner := minf(_held_radius * _share(), figure.radius * 0.75)
	figure.draw_circle(Vector2.ZERO, inner, Color(held.data.color, 0.9))
	figure.draw_arc(Vector2.ZERO, inner, 0.0, TAU, 20, Color(1, 1, 1, 0.8), 3.0, true)
