class_name SlipperyAbility
extends FigureAbility
## Slippery Jim's coat. While it has stacks, every hit and every explosion on it is nullified: no knockback, and the figure
## that hit it bounces off as if it had hit a wall. Only hits on the PLAYER's turn use a stack up (one per hit, and at most
## every separate hit or explosion strips one; the same continuous contact (a figure grinding against it) counts once until that figure
## separates); hits on its own side's turn are nullified for free.
## A Blastoid rocket PIERCES the coat: it strips one stack (its direct hit and blast together count once, only on the player's turn) and
## still pushes him with full force (a "Pierced!" starburst shows it).
## Stacks never come back. At 0 it is a normal figure. Pips show the stacks left.

## Stacks at the start of a fight (Boss Upgrades adds 2, see AscensionConfig).
@export var stacks := 5
## A figure that counted counts again only after its body is this many px clear of Jim.
@export var separate_gap := 6.0
## A hit slower than this (px/s, relative) is too gentle to count (it is still nullified).
@export var min_hit_speed := 120.0
## How lively the bounce-off is (1 = a perfect rebound; 0.6 is about a wall).
@export var rebound := 0.6
@export var pip_color := Color(0.45, 0.9, 1.0)

var _left := -1
var _max := 0
var _touching := {}  # figure instance id -> figure whose hit already counted and that is still in contact
var _flash_ms := -100000
var _pierce_ms := -100000
var _last_rocket := 0
var _skip_exploded_until := 0


func _ensure() -> void:
	if _left < 0:
		_left = stacks
		_max = stacks


func stacks_left() -> int:
	_ensure()
	return _left


func is_slippery() -> bool:
	return stacks_left() > 0


## The hitter is the faster of the two (so a Jim that rams something is not nullified).
func _is_hit_by(figure: Figure, source: Figure) -> bool:
	return source != null and source.team != figure.team \
			and source._last_velocity.length() >= figure._last_velocity.length()


## Slippery: immune to magnets and glue (see Figure.field_immune) while any stack is left.
func get_field_immunity(_figure: Figure) -> bool:
	return is_slippery()


func get_knockback_multiplier(figure: Figure, source: Figure) -> float:
	return 0.0 if is_slippery() and _is_hit_by(figure, source) else 1.0


func get_explosion_multiplier(_figure: Figure, _source: Figure) -> float:
	return 0.0 if is_slippery() else 1.0


## A rocket from the player's side on the player's turn pierces: one stack per rocket, full knockback.
func on_pierced(figure: Figure, source: Figure, rocket_id: int) -> bool:
	if not is_slippery() or figure.knocked_off or source == null or source.team != Figure.Team.PLAYER or not _player_turn():
		return false
	if rocket_id != _last_rocket:  # (its direct hit and its blast are one rocket)
		_last_rocket = rocket_id
		_pierce_ms = Time.get_ticks_msec()
		_lose_stack(figure, null, true)
	_skip_exploded_until = Time.get_ticks_msec() + 150  # (the blast's on_exploded must not strip a second stack)
	return true


func _player_turn() -> bool:
	var combat = RunManager.combat
	return combat != null and combat.turret_side == Figure.Team.PLAYER


func on_impact(figure: Figure, other: Figure, speed: float, _point: Vector2) -> void:
	if figure.knocked_off or other.knocked_off or not is_slippery() or not _is_hit_by(figure, other):
		return
	# Bounce the hitter off like a wall (it was already pushed by the engine as if Jim were light).
	var normal := (other.global_position - figure.global_position).normalized()
	var before := other._last_velocity if other._last_velocity.length() >= other._prev_velocity.length() else other._prev_velocity
	var into := before.dot(normal)
	if into < 0.0:
		other.linear_velocity = before - (1.0 + rebound) * into * normal
	if speed >= min_hit_speed and other.team == Figure.Team.PLAYER and _player_turn():
		_lose_stack(figure, other)


func on_exploded(figure: Figure, source: Figure) -> void:
	if figure.knocked_off or not is_slippery():
		return
	if Time.get_ticks_msec() < _skip_exploded_until:
		return
	if (source == null or source.team == Figure.Team.PLAYER) and _player_turn():
		_lose_stack(figure, null)


## Frees the debounce for figures that have separated from him.
func on_physics_process(figure: Figure, _delta: float) -> void:
	for id in _touching.keys():
		var other = _touching[id]
		if not is_instance_valid(other) or other.knocked_off \
				or other.global_position.distance_to(figure.global_position) > figure.radius + other.radius + separate_gap:
			_touching.erase(id)


func _lose_stack(figure: Figure, hitter: Figure, pierced := false) -> void:
	_ensure()
	if _left <= 0:
		return
	if hitter != null:
		if _touching.has(hitter.get_instance_id()):
			return  # the same contact, still grinding
		_touching[hitter.get_instance_id()] = hitter
	_flash_ms = Time.get_ticks_msec()
	_left -= 1
	if pierced:
		figure.show_popup("Pierced! %d left" % _left if _left > 0 else "Pierced! Open!", Color(1.0, 0.55, 0.15))
	elif _left <= 0:
		figure.show_popup("Slip! Open!", Color(1.0, 0.85, 0.3))
	else:
		figure.show_popup("Slip! %d left" % _left, Color(0.55, 0.92, 1.0))
	figure.queue_redraw()


## A glossy ring while slippery, a flash when a stack goes, and the pips above.
func draw_overlay(figure: Figure) -> void:
	_ensure()
	var age := (Time.get_ticks_msec() - _flash_ms) / 1000.0
	if age < 0.45:
		var t := age / 0.45
		figure.draw_arc(Vector2.ZERO, figure.radius * (1.0 + 0.7 * t), 0.0, TAU, 40, Color(pip_color, 1.0 - t), 8.0 * (1.0 - t) + 2.0, true)
	var pierce_age := (Time.get_ticks_msec() - _pierce_ms) / 1000.0
	if pierce_age < 0.6:  # a starburst: the rocket went through the coat
		var t := pierce_age / 0.6
		for i in 12:
			var dir := Vector2.from_angle(TAU * i / 12.0)
			figure.draw_line(dir * figure.radius * (0.7 + 0.5 * t), dir * figure.radius * (1.1 + 1.1 * t), Color(1.0, 0.55, 0.15, 1.0 - t), 7.0 * (1.0 - t) + 2.0, true)
		figure.queue_redraw()
	if _left <= 0:
		return
	figure.draw_arc(Vector2.ZERO, figure.radius + 5.0, 0.0, TAU, 40, Color(pip_color, 0.55), 6.0, true)
	figure.draw_arc(Vector2.ZERO, figure.radius * 0.6, deg_to_rad(200.0), deg_to_rad(260.0), 10, Color(1, 1, 1, 0.7), 5.0, true)
	var spacing := 26.0
	var start_x := -spacing * (_max - 1) / 2.0
	var y := -figure.radius - 22.0
	for i in _max:
		var center := Vector2(start_x + spacing * i, y)
		if i < _left:
			figure.draw_circle(center, 10.0, pip_color)
			figure.draw_arc(center, 10.0, 0.0, TAU, 16, Color.WHITE, 2.0, true)
		else:
			figure.draw_arc(center, 8.0, 0.0, TAU, 16, Color(pip_color, 0.4), 2.0, true)

