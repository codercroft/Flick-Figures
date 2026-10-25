class_name MagnetAbility
extends FigureAbility
## While on the board, gently pulls moving figures toward it (friends and enemies alike).

@export var pull_radius := 450.0
## Pull (px/s per second) right next to the magnet; fades to zero at pull_radius.
@export var pull_acceleration := 600.0


func on_physics_process(figure: Figure, _delta: float) -> void:
	if figure.on_deck:
		return
	for node in figure.get_tree().get_nodes_in_group("figures"):
		var other := node as Figure
		if other == figure or other.knocked_off or other.is_resting():
			continue
		var offset := figure.global_position - other.global_position
		var distance := offset.length()
		if distance >= pull_radius or distance <= figure.radius + other.radius:
			continue  # too far, or already touching
		# Force = mass * acceleration, so heavy figures are pulled as hard as light ones.
		var pull := pull_acceleration * (1.0 - distance / pull_radius)
		other.apply_central_force(offset.normalized() * pull * other.mass)
