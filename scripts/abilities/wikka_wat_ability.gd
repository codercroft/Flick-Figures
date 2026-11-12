class_name WikkaWatAbility
extends FigureAbility
## Wikka Wat: while it is MOVING on its own side's turn (its own flick, or a bump from a teammate) the player can TAP the
## screen to fully reverse its momentum: same speed, opposite direction (Seek path: toward the nearest opponent instead).
## It is not a flick. Charges (`reverses_per_turn`) are refilled every turn change and do not carry over.
## Scratch path: more charges, and each use adds speed and knockback until it rests. Seek path: redirect, refresh on hit,
## and a growing flick power and mass per kill.

## Reverses per turn (Scratch tiers 1 and 3 raise it).
@export var reverses_per_turn := 1
## It must be moving faster than this (px/s) to be reversed.
@export var min_reverse_speed := 120.0
## Scratch tier 2: each use multiplies its speed by 1 + this, and adds this much knockback dealt (per use) until it rests.
@export var speed_bonus := 0.0
@export var knockback_bonus := 0.0
## Seek tier 1: the reverse points at the nearest opponent (same speed) instead of straight back.
@export var redirect_to_nearest := false
## Seek tier 2: hitting an opponent refills the charges for this turn.
@export var refresh_on_hit := false
## Seek tier 3: per kill (for the rest of the combat, stacking up to `max_kill_stacks`) its flick power and mass grow by this.
@export var kill_power_bonus := 0.0
@export var kill_mass_bonus := 0.0
@export var max_kill_stacks := 5

var _used := 0
var _motion_uses := 0  # uses since it last came to rest (the knockback bonus stacks with them)
var _kills := 0
var _base_mass := 0.0


func get_reverse_stats(_figure: Figure) -> Dictionary:
	return {"charges_left": maxi(reverses_per_turn - _used, 0), "per_turn": reverses_per_turn, "seek": redirect_to_nearest}


## True if a reverse could be used right now: moving fast enough, on its own side's turn, a charge left.
func can_reverse(figure: Figure) -> bool:
	if figure.knocked_off or not figure.is_inside_tree() or _used >= reverses_per_turn:
		return false
	var combat := RunManager.combat
	if combat == null or combat.turret_side != figure.team:
		return false
	return figure.linear_velocity.length() >= min_reverse_speed


## Reverses the momentum. `direction` (optional) overrides where it goes (the enemy AI picks it); a zero vector means
## "straight back" (or the nearest opponent with Seek). Returns whether it happened.
func use_reverse(figure: Figure, direction := Vector2.ZERO) -> bool:
	if not can_reverse(figure):
		return false
	var velocity := figure.linear_velocity
	var speed := velocity.length() * (1.0 + speed_bonus)
	var heading := direction.normalized() if direction != Vector2.ZERO else -velocity.normalized()
	if direction == Vector2.ZERO and redirect_to_nearest:
		var toward := _toward_nearest_opponent(figure)
		if toward != Vector2.ZERO:
			heading = toward
	figure.nudge(heading * speed - velocity)  # (a nudge: no knockback multipliers, and the settle logic is told it is moving)
	_used += 1
	_motion_uses += 1
	figure.show_popup("Wikka!", Color(1.0, 0.55, 0.95))
	var parent := figure.get_parent()
	if parent != null:
		WikkaEffect.spawn(parent, figure.global_position, heading)
	figure.queue_redraw()
	return true


func _toward_nearest_opponent(figure: Figure) -> Vector2:
	var best := Vector2.ZERO
	var best_distance := INF
	for node in figure.get_tree().get_nodes_in_group("figures"):
		var other := node as Figure
		if other == null or other.knocked_off or other.team == figure.team:
			continue
		var distance := other.global_position.distance_to(figure.global_position)
		if distance < best_distance:
			best_distance = distance
			best = (other.global_position - figure.global_position).normalized()
	return best


func get_dealt_knockback_bonus(_figure: Figure, _other: Figure) -> float:
	return knockback_bonus * _motion_uses


func on_stopped(_figure: Figure) -> void:
	_motion_uses = 0  # "until it comes to rest"


func on_hit(figure: Figure, other: Figure) -> void:
	if refresh_on_hit and other.team != figure.team and _used > 0 and figure.linear_velocity.length() >= min_reverse_speed:
		_used = 0
		figure.show_popup("Again!", Color(1.0, 0.8, 1.0))
		figure.queue_redraw()


func on_turn_ended(figure: Figure) -> void:
	_used = 0  # unused charges do not carry over
	figure.queue_redraw()


func on_opponent_knocked_off(figure: Figure, _victim: Figure) -> void:
	if kill_power_bonus <= 0.0 and kill_mass_bonus <= 0.0:
		return
	var combat := RunManager.combat
	if combat == null or combat._flicker != figure:  # (its own movement's kill)
		return
	if _base_mass <= 0.0:
		_base_mass = figure.mass
	_kills = mini(_kills + 1, max_kill_stacks)
	figure.mass = _base_mass * pow(1.0 + kill_mass_bonus, _kills)
	figure.show_popup("Stronger!", Color(1.0, 0.7, 0.9))


func get_flick_power_multiplier(_figure: Figure) -> float:
	return pow(1.0 + kill_power_bonus, _kills)


## Charge indicator: one pip per reverse per turn above the figure, filled while a charge is left.
func draw_overlay(figure: Figure) -> void:
	var spacing := 22.0
	var start_x := -spacing * (reverses_per_turn - 1) / 2.0
	var y := -figure.radius - 18.0
	var color := Color(1.0, 0.55, 0.95)
	for i in reverses_per_turn:
		var center := Vector2(start_x + spacing * i, y)
		if i < reverses_per_turn - _used:
			figure.draw_circle(center, 8.0, color)
		else:
			figure.draw_arc(center, 7.0, 0.0, TAU, 16, Color(color, 0.5), 3.0, true)
