class_name AbsorberAbility
extends FigureAbility
## A big, short-range figure. When its own flick hits an OPPOSING figure with a smaller radius at `absorb_speed`
## or more, it absorbs it: the figure is held inside (removed from play, shown shrinking in its belly). The held
## figure shrinks over `shrink_rounds` rounds; when it is fully shrunk it counts as knocked off. If a teammate of a
## held figure hits the Absorber at `escape_speed` or more, that figure pops out at its current (reduced) size.
## Bosses, boss pieces and other uneatable figures cannot be absorbed. If the Absorber is knocked off, the held
## figures pop out where it fell.

## Minimum impact speed (px/s) of the Absorber's own hit to absorb something.
@export var absorb_speed := 150.0
## Minimum impact speed (px/s) of a teammate of a held figure to free it.
@export var escape_speed := 1100.0
## Tight Grip (Spit tier 1): hits never free a held figure (it still pops out where it fell if the Absorber is knocked off).
@export var escape_immune := false
## Rounds until a held figure is fully shrunk (and counts as knocked off).
@export var shrink_rounds := 3
## Gut path: how many figures it can hold, and how much a figure shrinks at once when absorbed (0.5 = half size).
@export var capacity := 1
@export var instant_shrink := 0.0
## Spit path: tap to spit the oldest held figure out at this speed (uses the action); spat figures explode on impact.
@export var spit_speed := 0.0
@export var spat_explode := false
@export var spat_blast_radius := 170.0
@export var spat_blast_force := 900.0

var held: Array[Dictionary] = []  # {figure, radius, mass, rounds}
var _armed := false


func on_flicked(_figure: Figure, _impulse: Vector2) -> void:
	_armed = true


func on_stopped(_figure: Figure) -> void:
	_armed = false


func _prune() -> void:
	for i in range(held.size() - 1, -1, -1):
		if not is_instance_valid(held[i].figure):
			held.remove_at(i)


func on_impact(figure: Figure, other: Figure, speed: float, _point: Vector2) -> void:
	if figure.knocked_off or other.knocked_off:
		return
	_prune()
	# A teammate of a held figure hits hard: the most recently absorbed one escapes.
	if other.team != figure.team and speed >= escape_speed and not escape_immune:
		for i in range(held.size() - 1, -1, -1):
			if held[i].figure.team == other.team:
				_release(figure, i, Vector2.ZERO)
				return
	if held.size() >= capacity or not _armed or speed < absorb_speed or other.team == figure.team:
		return
	if other.radius >= figure.radius or other.data.uneatable or other.data.boss_body:
		return
	var main := figure.get_tree().current_scene
	if main == null or not main.has_method("absorb_figure"):
		return
	var entry := {"figure": other, "radius": other.radius, "mass": other.mass, "rounds": 0}
	held.append(entry)
	_armed = false
	main.absorb_figure(other)
	_apply_size(entry)
	figure.show_popup("Gulp!", Color(0.8, 0.5, 0.9))


func on_round_ticked(figure: Figure) -> void:
	_prune()
	for i in range(held.size() - 1, -1, -1):
		var entry: Dictionary = held[i]
		entry.rounds += 1
		if entry.rounds >= shrink_rounds:
			var victim: Figure = entry.figure
			held.remove_at(i)
			var main := figure.get_tree().current_scene
			if main != null and main.has_method("finish_absorbed"):
				main.finish_absorbed(victim)
		else:
			_apply_size(entry)


func on_knocked_off(figure: Figure) -> void:
	while not held.is_empty():
		_release(figure, held.size() - 1, Vector2.ZERO)


func _share(entry: Dictionary) -> float:
	var share := (1.0 - instant_shrink) * (1.0 - float(entry.rounds) / float(maxi(shrink_rounds, 1)))
	return clampf(share, 0.05, 1.0)


func _apply_size(entry: Dictionary) -> void:
	var share := _share(entry)
	entry.figure.set_size(entry.radius * share, entry.mass * share)


func _release(figure: Figure, index: int, velocity: Vector2) -> void:
	var entry: Dictionary = held[index]
	held.remove_at(index)
	var victim: Figure = entry.figure
	if not is_instance_valid(victim):
		return
	var main := figure.get_tree().current_scene
	if main != null and main.has_method("release_absorbed"):
		main.release_absorbed(victim, figure.global_position, velocity)
		if velocity != Vector2.ZERO and spat_explode:
			victim.set_meta("spat_explode", [spat_blast_radius, spat_blast_force])
		figure.show_popup("Escaped!" if velocity == Vector2.ZERO else "Spit!", Color(0.9, 0.9, 0.5))


## Spit path: tap the Absorber to spit the oldest held figure toward a figure of ITS OWN team (or away if none).
func get_tap_ability(figure: Figure) -> Dictionary:
	if spit_speed <= 0.0 or figure.knocked_off:
		return {}
	_prune()
	return {"kind": "self", "ready": not held.is_empty() and figure.can_act_now(), "uses_action": true, "hint": "Spit!"}


func use_tap_ability(figure: Figure, _point: Vector2) -> bool:
	_prune()
	if held.is_empty() or spit_speed <= 0.0:
		return false
	var victim: Figure = held[0].figure
	var best: Figure = null
	var best_distance := INF
	for node in figure.get_tree().get_nodes_in_group("figures"):
		var other := node as Figure
		if other == null or other == victim or other.knocked_off or other.team != victim.team:
			continue
		var d := other.global_position.distance_to(figure.global_position)
		if d < best_distance:
			best_distance = d
			best = other
	var direction := (best.global_position - figure.global_position).normalized() if best != null else Vector2.UP
	_release(figure, 0, direction * spit_speed)
	return true


func get_absorb_speed(_figure: Figure) -> float:
	return absorb_speed if held.size() < capacity else 0.0


func get_escape_speed(_figure: Figure) -> float:
	_prune()
	return escape_speed if not held.is_empty() and not escape_immune else 0.0


func get_held_figure(_figure: Figure) -> Figure:
	_prune()
	return held[held.size() - 1].figure if not held.is_empty() else null


## The held figures, shrinking inside the belly.
func draw_overlay(figure: Figure) -> void:
	_prune()
	for i in held.size():
		var entry: Dictionary = held[i]
		var inner := minf(entry.radius * _share(entry), figure.radius * (0.75 if held.size() == 1 else 0.45))
		var spot := Vector2.ZERO if held.size() == 1 else Vector2.from_angle(TAU * i / held.size() - PI / 2.0) * figure.radius * 0.4
		figure.draw_circle(spot, inner, Color(entry.figure.data.color, 0.9))
		figure.draw_arc(spot, inner, 0.0, TAU, 20, Color(1, 1, 1, 0.8), 3.0, true)


## Enemy AI: spit whenever it holds a figure and another of the same team is left to hit.
func ai_wants_tap(figure: Figure, opponents: Array) -> bool:
	_prune()
	if held.is_empty():
		return false
	var victim: Figure = held[0].figure
	for other in opponents:
		if is_instance_valid(other) and other != victim and not other.knocked_off and other.team == victim.team:
			return true
	return false
