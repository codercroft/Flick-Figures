class_name BummerAbility
extends FigureAbility
## Average figure with a very small aura (drawn faintly). When an OPPOSING figure is inside it at the moment
## its side goes to flick it, control is taken away ("Bummed out!") and the figure instead takes a shot
## chosen by the enemy AI with inverted goals: knock ITSELF off the table and hit its own teammates on the
## way (see EnemyAI.choose_takeover). The takeover counts as that figure's flick for the cycle.
## A figure counts as inside when its body touches the aura circle.

## Radius (px) of the aura from the Bummer's center (180: about 3x its own radius of 60).
@export var aura_radius := 180.0
## Gloom path: takeover shots deal this much more knockback (0.25 = +25%), and a taken-over figure stays bummed for
## this many more flicks after it leaves the aura.
@export var takeover_knockback_bonus := 0.0
@export var linger_flicks := 0
## Downer path: opposing figures in the aura flick with this share of power (0.8 = 20% weaker), moving ones are slowed
## (extra damping per second), and they take this much more knockback.
@export var enemy_flick_power := 1.0
@export var aura_slow := 0.0
@export var enemy_knockback_taken := 1.0


func get_bummer_stats(_figure: Figure) -> Dictionary:
	return {"radius": aura_radius, "knockback": takeover_knockback_bonus, "linger": linger_flicks}


func get_enemy_aura(_figure: Figure) -> Dictionary:
	if is_equal_approx(enemy_flick_power, 1.0) and is_equal_approx(enemy_knockback_taken, 1.0):
		return {}
	return {"radius": aura_radius, "flick": enemy_flick_power, "knockback": enemy_knockback_taken}


func on_physics_process(figure: Figure, _delta: float) -> void:
	if aura_slow <= 0.0 or figure.on_deck:
		return
	for node in figure.get_tree().get_nodes_in_group("figures"):
		var other := node as Figure
		if other == null or other.knocked_off or other.team == figure.team or other.is_slow():
			continue
		if other.global_position.distance_to(figure.global_position) <= aura_radius + other.radius:
			other.apply_central_force(-other.linear_velocity * aura_slow * other.mass)
