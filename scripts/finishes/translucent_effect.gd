class_name TranslucentEffect
extends FigureAbility
## Translucent finish: ignores (passes through) the first ally it touches each flick. Any later
## ally collides normally.

var _active := false
var _passed: Figure
var _ignored: Array[Figure] = []


func on_flicked(figure: Figure, _impulse: Vector2) -> void:
	_forget(figure)
	_active = true
	# Until it touches an ally, it can pass through all of them.
	for node in figure.get_tree().get_nodes_in_group("figures"):
		var other := node as Figure
		if other != figure and other.team == figure.team and not other.knocked_off:
			figure.add_collision_exception_with(other)
			_ignored.append(other)


func on_physics_process(figure: Figure, _delta: float) -> void:
	if not _active or _passed != null:
		return
	for other in _ignored:
		if is_instance_valid(other) and figure.global_position.distance_to(other.global_position) <= figure.radius + other.radius + 4.0:
			_passed = other
			# That was the first ally: every other ally collides normally again.
			for rest in _ignored:
				if rest != other and is_instance_valid(rest):
					figure.remove_collision_exception_with(rest)
			return


func on_stopped(figure: Figure) -> void:
	_forget(figure)


func _forget(figure: Figure) -> void:
	for other in _ignored:
		if is_instance_valid(other) and is_instance_valid(figure):
			figure.remove_collision_exception_with(other)
	_ignored.clear()
	_passed = null
	_active = false
