class_name LandMine
extends Node2D
## One landmine laid by a Land Miner. A small marker on the board: it collides with nothing and blocks nothing. An
## OPPOSING figure whose center comes within `trigger_radius` sets it off: it explodes (a normal blast through
## Figure.blast, so the friendly-explosion rule, Blast Cap and every explosion effect apply) and disappears.
## Explosions do not set mines off. Mines stay for the rest of the combat. Smart Bombs tier 3: with `homing_range` > 0 it
## drifts toward the nearest MOVING opposing figure in range (a gentle pull) and stays put otherwise.

var team := 0
var owner_figure: Figure
var trigger_radius := 70.0
var explosion_radius := 140.0
var explosion_force := 600.0
var homing_range := 0.0
var homing_speed := 220.0
var _done := false
var _age := 0.0


func _ready() -> void:
	add_to_group("mines")
	z_index = 0


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	var pull_target: Figure = null
	var pull_distance := INF
	for node in get_tree().get_nodes_in_group("figures"):
		var figure := node as Figure
		if figure == null or figure.knocked_off or figure.team == team:
			continue
		var distance := figure.global_position.distance_to(global_position)
		if distance <= trigger_radius:
			_explode()
			return
		if homing_range > 0.0 and distance <= homing_range and not figure.is_slow() and distance < pull_distance:
			pull_target = figure
			pull_distance = distance
	if pull_target != null:
		# Gravity-like: the closer the target, the stronger the drift.
		var strength := 1.0 - 0.5 * pull_distance / homing_range
		global_position += (pull_target.global_position - global_position).normalized() * homing_speed * strength * delta
	queue_redraw()


func _explode() -> void:
	_done = true
	var reach := explosion_radius * RunManager.relic_explosion_multiplier(team)  # Blast Cap
	Figure.blast(get_tree(), global_position, reach, explosion_force, null, null, team)
	var effect := BlastEffect.new()
	effect.position = position
	effect.z_index = 6
	get_parent().add_child(effect)
	effect.start(reach)
	remove_from_group("mines")
	queue_free()


func _draw() -> void:
	var tint := Color(0.85, 0.93, 1.0) if team == Figure.Team.PLAYER else Color(1.0, 0.35, 0.3)
	draw_circle(Vector2.ZERO, trigger_radius, Color(tint, 0.07))  # (how close a figure must come)
	draw_arc(Vector2.ZERO, trigger_radius, 0.0, TAU, 40, Color(tint, 0.22), 2.0, true)
	draw_circle(Vector2.ZERO, 19.0, Color(0.16, 0.17, 0.2))
	for i in 8:
		var spike := Vector2.from_angle(TAU * i / 8.0)
		draw_line(spike * 19.0, spike * 27.0, tint, 4.0)
	draw_arc(Vector2.ZERO, 19.0, 0.0, TAU, 24, tint, 4.0, true)
	var blink := 0.5 + 0.5 * sin(_age * 5.0)
	draw_circle(Vector2.ZERO, 6.0, Color(tint, 0.4 + 0.6 * blink))
