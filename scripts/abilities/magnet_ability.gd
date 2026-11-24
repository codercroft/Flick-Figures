class_name MagnetAbility
extends FigureAbility
## While on the board, bends the path of moving OPPOSING figures that pass near it (never its own
## team's shots): a disruptor. The pull is weak near the magnet and strongest at the edge
## of its range, so a shot is caught as it passes by, not dragged straight in. The magnet never
## pulls resting figures and is never moved by its own pull.

## How far (px from the magnet's center) the pull reaches.
@export var pull_radius := 500.0
## Inside this distance (px) there is no pull at all.
@export var inner_radius := 150.0
## Pull (px/s per second) at pull_radius. It fades linearly to zero at inner_radius.
@export var pull_acceleration := 1600.0
## Figures slower than this (px/s) are left alone, so resting figures are never dragged in.
@export var min_pull_speed := 60.0
@export_group("Implosion")
## When the Magnet is knocked off it implodes like Short Fuse: it pulls nearby figures toward the spot where it left.
@export var implosion_radius := 300.0
@export var implosion_strength := 1800.0
@export var implosion_seconds := 0.4
## If the Magnet wears Short Fuse the implosion is stronger instead of happening twice.
@export var fused_implosion_radius := 440.0
@export var fused_implosion_strength := 2700.0
@export_group("Upgrades")
## Field path (Repel Pulse): after the Magnet is flicked, while it is still moving, a tap ANYWHERE on the screen pushes
## the opposing figures near it away (the shove is strongest close to the Magnet). Once per combat, or once per turn
## with `push_once_per_turn`. The Magnet shows a ring while the pulse is available (bright while it is moving).
@export var push_enabled := false
@export var push_once_per_turn := false
@export var push_speed := 650.0
## The Magnet must be moving faster than this (px/s) for the pulse to work.
@export var pulse_min_speed := 80.0
## Collapse path: tap the Magnet (uses its action; it stays) to implode on command, once per combat. Black Hole: after
## it is knocked off it leaves a pull for this long that never moves its own team.
@export var implode_on_command := false
@export var black_hole_seconds := 0.0

var _push_used := false
var _implode_used := false
var _pulse_ms := -100000


func on_physics_process(figure: Figure, _delta: float) -> void:
	if not figure.flick_motion():
		return
	for node in figure.get_tree().get_nodes_in_group("figures"):
		var other := node as Figure
		# `other == figure`: a magnet is never moved by its own pull.
		if other == figure or other.knocked_off or other.is_slow() or other.team == figure.team or other.field_immune():
			continue
		if other.linear_velocity.length() < min_pull_speed:
			continue
		var offset := figure.global_position - other.global_position
		var distance := offset.length()
		if distance < inner_radius or distance > pull_radius:
			continue
		var strength := (distance - inner_radius) / (pull_radius - inner_radius)
		# Force = mass * acceleration, so heavy figures are pulled as hard as light ones.
		other.apply_central_force(offset.normalized() * pull_acceleration * RunManager.relic_pull_multiplier() * strength * other.mass)


func on_turn_ended(_figure: Figure) -> void:
	if push_once_per_turn:
		_push_used = false


func get_tap_ability(figure: Figure) -> Dictionary:
	if figure.knocked_off or figure.on_deck:
		return {}
	if implode_on_command:
		return {"kind": "self", "ready": figure.can_act_now() and not _implode_used, "uses_action": true, "hint": "Implode!"}
	if push_enabled:  # a tap anywhere while it moves (Main.try_reverse_tap; the enemy AI uses it in _enemy_wikka_step)
		return {"kind": "moving", "ready": pulse_ready(figure), "uses_action": false, "hint": "Repel!"}
	return {}


## The pulse can fire now: charge left, the Magnet is on the board, moving, and it is its own side's turn.
func pulse_ready(figure: Figure) -> bool:
	if not push_enabled or _push_used or figure.knocked_off or not figure.flick_motion():
		return false
	var combat = RunManager.combat
	if combat == null or combat.turret_side != figure.team:
		return false
	return figure.linear_velocity.length() >= pulse_min_speed


func on_flicked(figure: Figure, _impulse: Vector2) -> void:
	if push_enabled and not _push_used:
		figure.show_popup("Tap to repel!", Color(0.6, 0.85, 1.0))


func use_tap_ability(figure: Figure, _point: Vector2) -> bool:
	if implode_on_command and not _implode_used and figure.can_act_now():
		_implode_used = true
		_spawn_implosion(figure, implosion_seconds, false)
		figure.show_popup("Implode!", Color(0.75, 0.45, 1.0))
		return true
	if push_enabled and pulse_ready(figure):
		_push_used = true
		_pulse_ms = Time.get_ticks_msec()
		for node in figure.get_tree().get_nodes_in_group("figures"):
			var other := node as Figure
			if other == null or other == figure or other.knocked_off or other.team == figure.team or other.on_deck or other.field_immune():
				continue
			var offset := other.global_position - figure.global_position
			var distance := offset.length()
			if distance > pull_radius or distance < 1.0:
				continue
			other.nudge(offset / distance * push_speed * (1.0 - 0.5 * distance / pull_radius))
		figure.show_popup("Push!", Color(0.6, 0.85, 1.0))
		return true
	return false


## The pulse indicator: a ring around the Magnet while a pulse is left (bright and pulsing while it can fire), and an
## expanding ring when it fires.
func draw_overlay(figure: Figure) -> void:
	if not push_enabled or not figure.flick_motion():
		return
	var age := (Time.get_ticks_msec() - _pulse_ms) / 1000.0
	if age < 0.5:
		var t := age / 0.5
		figure.draw_arc(Vector2.ZERO, lerpf(figure.radius, pull_radius, t), 0.0, TAU, 64, Color(0.6, 0.85, 1.0, 1.0 - t), 8.0, true)
	if _push_used:
		return
	var ready := pulse_ready(figure)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0) if ready else 0.0
	var color := Color(0.6, 0.9, 1.0, 0.95 if ready else 0.35)
	figure.draw_arc(Vector2.ZERO, figure.radius + 10.0 + 6.0 * pulse, 0.0, TAU, 40, color, 5.0, true)
	if ready:
		var font := ThemeDB.fallback_font
		figure.draw_string(font, Vector2(-30.0, -figure.radius - 24.0), "TAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.6, 0.9, 1.0))


func _spawn_implosion(figure: Figure, seconds: float, friendly_safe: bool) -> void:
	var parent := figure.get_parent()
	if parent == null:
		return
	var fused := figure.equipment != null and figure.equipment.effect is ShortFuseEffect
	var pull := Implosion.new()
	pull.center = figure.global_position
	pull.radius = fused_implosion_radius if fused else implosion_radius
	pull.strength = fused_implosion_strength if fused else implosion_strength
	pull.seconds = seconds
	pull.source = figure
	pull.friendly_safe = friendly_safe
	pull.position = figure.global_position
	pull.z_index = 5
	parent.add_child.call_deferred(pull)


func on_knocked_off(figure: Figure) -> void:
	if black_hole_seconds > 0.0:
		_spawn_implosion(figure, black_hole_seconds, true)
		return
	var parent := figure.get_parent()
	if parent == null:
		return
	var fused := figure.equipment != null and figure.equipment.effect is ShortFuseEffect
	var pull := Implosion.new()
	pull.center = figure.global_position
	pull.radius = fused_implosion_radius if fused else implosion_radius
	pull.strength = fused_implosion_strength if fused else implosion_strength
	pull.seconds = implosion_seconds
	pull.source = figure
	pull.position = figure.global_position
	pull.z_index = 5
	parent.add_child.call_deferred(pull)


func has_path_pull(figure: Figure) -> bool:
	return not figure.on_deck


## What the pull does to a moving figure at `point` (the enemy AI uses it to follow curved shots).
func get_path_pull(figure: Figure, point: Vector2, mover_team := -1) -> Vector2:
	if figure.on_deck or mover_team == figure.team:
		return Vector2.ZERO
	var offset := figure.global_position - point
	var distance := offset.length()
	if distance < inner_radius or distance > pull_radius:
		return Vector2.ZERO
	var strength := (distance - inner_radius) / (pull_radius - inner_radius)
	return offset.normalized() * pull_acceleration * RunManager.relic_pull_multiplier() * strength


## Enemy AI: implode when two or more of the player's figures are inside the pull; push when one is in range and
## close to an edge, or two or more are in range.
func ai_wants_tap(figure: Figure, opponents: Array) -> bool:
	var in_range := 0
	var near_edge := false
	var table: Rect2 = RunManager.combat.board.get_table_rect() if RunManager.combat != null else Rect2()
	var reach := implosion_radius if implode_on_command else pull_radius
	for other in opponents:
		if is_instance_valid(other) and not other.knocked_off and other.global_position.distance_to(figure.global_position) <= reach:
			in_range += 1
			if table.size != Vector2.ZERO and not table.grow(-200.0).has_point(other.global_position):
				near_edge = true
	return in_range >= 2 or (near_edge and not implode_on_command)
