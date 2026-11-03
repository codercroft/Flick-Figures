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


func on_physics_process(figure: Figure, _delta: float) -> void:
	if figure.on_deck:
		return
	for node in figure.get_tree().get_nodes_in_group("figures"):
		var other := node as Figure
		# `other == figure`: a magnet is never moved by its own pull.
		if other == figure or other.knocked_off or other.is_slow() or other.team == figure.team:
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


func on_knocked_off(figure: Figure) -> void:
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
