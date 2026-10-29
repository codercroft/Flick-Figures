class_name GolfAI
extends Node
## The Mini-Golf opponent. It tries many strokes (direction x power) in a `GolfSim`, which follows the
## real walls, pins, floor patches and hole, so bank shots come out naturally. It keeps the stroke that
## sinks the ball (or ends nearest the hole), polishes it with a finer search around the best few, and
## then plays it with a bit of aim and power error (its accuracy).

@export_group("Search")
## Coarse pass: directions every this many degrees.
@export var angle_step_degrees := 6.0
## Coarse pass: power levels (fractions of a full-strength flick).
@export var power_levels: Array[float] = [0.2, 0.3, 0.4, 0.5, 0.62, 0.75, 0.88, 1.0]
## How many of the best coarse strokes get the fine search.
@export var refine_count := 4
## Fine search: direction offsets (degrees) and power offsets around each.
@export var fine_angles_degrees: Array[float] = [-3.0, -1.5, 1.5, 3.0]
@export var fine_powers: Array[float] = [-0.08, -0.04, 0.04, 0.08]
## Stop searching after this many milliseconds (slow phones), keeping the best stroke so far.
@export var think_budget_ms := 1800
@export_group("Accuracy")
## Aim error at accuracy 0 (the real error is (1 - accuracy) times this, either way).
@export var max_aim_error_degrees := 20.0


## Returns the impulse to flick `ball` with. `sim` knows the course; `max_force` is a full-strength flick.
func choose(ball: Figure, sim: GolfSim, max_force: float, accuracy: float, power_error: float) -> Vector2:
	var started := Time.get_ticks_msec()
	var from := ball.global_position
	var speed_for_full := max_force / ball.mass
	var tried: Array[Dictionary] = []  # {score, angle, power}
	var steps := int(round(360.0 / angle_step_degrees))
	for i in steps:
		# Spread the directions out (a prime stride) so a cut-off search still covers every side.
		var angle := deg_to_rad(float((i * 7) % steps) * angle_step_degrees)
		for power in power_levels:
			tried.append({"score": _score(sim, from, angle, power, speed_for_full), "angle": angle, "power": power})
		if i % 12 == 11:
			await get_tree().process_frame
		if Time.get_ticks_msec() - started > think_budget_ms:
			break
	tried.sort_custom(func(a, b): return a.score > b.score)
	var best := tried[0]
	for k in mini(refine_count, tried.size()):
		var seed_shot: Dictionary = tried[k]
		for da in fine_angles_degrees:
			for dp in fine_powers:
				var angle: float = seed_shot.angle + deg_to_rad(da)
				var power := clampf(seed_shot.power + dp, 0.05, 1.0)
				var score := _score(sim, from, angle, power, speed_for_full)
				if score > best.score:
					best = {"score": score, "angle": angle, "power": power}
		await get_tree().process_frame
	# Moderate accuracy: the stroke goes a little off.
	var error := deg_to_rad((1.0 - accuracy) * max_aim_error_degrees)
	var angle: float = best.angle + randf_range(-error, error)
	var power := clampf(best.power * (1.0 + randf_range(-power_error, power_error)), 0.05, 1.0)
	return Vector2.from_angle(angle) * power * max_force


## Higher is better: sinking beats everything (quicker is a touch better), otherwise nearer the hole.
func _score(sim: GolfSim, from: Vector2, angle: float, power: float, speed_for_full: float) -> float:
	var result := sim.roll(from, Vector2.from_angle(angle) * power * speed_for_full)
	if result.sunk:
		return 10000.0 - result.steps * 0.1
	return -result.end.distance_to(sim.hole)
