class_name EnemyAI
extends Node2D

## Figures this close (px) to the shooter's edge count as already touching it.
const TOUCH_MARGIN := 4.0

## Enemy brain. For each enemy it tries many candidate shots (targets x angles x power levels),
## shape-casts each one to find the first figure it would hit, scores them, and picks the best.
## If nothing scores well it makes a small safe repositioning flick instead.

@export_group("Candidate shots")
## Angles (degrees) tried either side of the straight line to each player figure.
@export var angle_offsets_degrees: Array[float] = [-10.0, -5.0, 0.0, 5.0, 10.0]
## Flick powers tried, as a fraction of the enemy's top speed. Higher = enemies hit harder and
## knock more of your figures off (at full power they can wipe out your deck).
@export var power_levels: Array[float] = [0.2, 0.3, 0.4, 0.5, 0.6]
## The speed (px/s) that a power level of 1.0 means for a figure with flick power 1. A figure with
## flick power 2 (like the snipers' 1.6) gets that multiple, up to what it physically can flick.
@export var reference_speed := 2400.0

@export_group("Scoring")
## Score for a first hit on a player figure.
@export var hit_player_bonus := 100.0
## Extra score (up to this) for pushing the target toward the table edge. Full when it is pushed
## all the way to the edge.
@export var edge_bonus := 60.0
## Extra score when the target is predicted to be knocked off the table (scaled by how likely).
@export var kill_bonus := 100.0
## Score taken off for power, so of two shots that do the same job the gentler one wins: the
## AI uses the lowest power that still knocks the target off. Scaled by power (0 to 1).
@export var overpower_penalty := 20.0
## A target this close (px) to the edge, along the shot, gets the full "via ally" edge bonus.
@export var edge_reach := 450.0
## Penalty for hitting another enemy first.
@export var ally_hit_penalty := 150.0
## Hitting an ally that is lined up with a player figure behind it scores this fraction of a normal hit.
@export var ally_strategic_factor := 0.5
## How far off line (degrees) an ally can be and still count as "lined up" with a player figure.
@export var ally_align_degrees := 8.0
## Penalty if the shooter itself is predicted to slide off the table after the hit (scaled by how
## likely). Keep it above kill_bonus + hit_player_bonus + edge_bonus and a self-knockoff always
## outweighs the kill it comes with.
@export var self_knock_off_penalty := 300.0
## Attacks scoring below this are skipped in favor of repositioning.
@export var min_attack_score := 40.0
## An EXTRA flick (Speedo's second shot) is only taken if the attack scores at least this much.
@export var bonus_flick_min_score := 120.0

@export_group("Repositioning")
## How far (px) a repositioning flick slides.
@export var reposition_distance := 180.0
## Repositioning flicks must end at least this far (px) inside the table edge.
@export var reposition_edge_margin := 150.0

@export_group("Pinhead bank shots")
## An enemy Pinhead may place a temporary pin and bounce its flick off it into a player figure.
## Spacing (px) of the grid of pin spots it tries.
@export var bank_grid_spacing := 110.0
## How much harder a bank shot is than a direct one (it can miss more): subtracted from its score.
@export var bank_shot_penalty := 30.0
## The speed multiplier the AI expects from a pin's kick (the Arena's pin_kick).
@export var bank_pin_kick := 1.3
## The shot must still arrive at the target at least this fast (px/s).
@export var bank_min_hit_speed := 400.0

@export_group("Accuracy")
## Aim error (degrees, either way) for an enemy whose FigureData accuracy is 0. At 1 it is perfect.
@export var max_aim_error_degrees := 20.0

@export_group("Debug")
## Draw each enemy's chosen shot (red = attack, orange = via ally, yellow = reposition).
@export var debug_draw_shots := false:
	set(value):
		debug_draw_shots = value
		queue_redraw()

var _debug_shots: Array[Dictionary] = []


func clear_debug() -> void:
	_debug_shots.clear()
	queue_redraw()


## Looks at every candidate enemy figure and returns the single best shot overall as
## {"enemy": Figure, "impulse": Vector2}, or {} if nobody has anything worth doing (pass).
## Real attacks beat repositioning, which beats passing; within a kind the higher score wins.
## Call from a physics-safe moment (it uses the physics space for shape casts).
## With `min_score` set (extra flicks), only attacks scoring at least that are considered.
func choose_flick(candidates: Array, players: Array[Figure], table: Rect2, max_force: float,
		min_score := -INF) -> Dictionary:
	var best := {}
	var best_enemy: Figure = null
	for enemy in candidates:
		var shot := _best_shot_for(enemy, players, table, max_force)
		if shot.kind == "pass":
			continue
		if min_score > -INF and (shot.kind == "reposition" or shot.score < min_score):
			continue
		if best.is_empty() or _shot_rank(shot) > _shot_rank(best):
			best = shot
			best_enemy = enemy
	if best.is_empty():
		return {}
	# Small random aim error: worse accuracy = bigger error.
	var error := _aim_error(best_enemy)
	var target = best.get("target")
	if is_instance_valid(target):
		error += deg_to_rad(target.ability.get_incoming_aim_error_degrees(target))
	var direction: Vector2 = best.direction.rotated(randf_range(-error, error))
	_record_debug(best_enemy, best, best_enemy.global_position + direction * best.distance)
	var result := {"enemy": best_enemy, "impulse": direction * best.speed * best_enemy.mass}
	if best.has("pin"):  # a bank shot: the caller places this pin before the flick
		result["pin"] = best.pin
		result["pin_radius"] = best.pin_radius
	return result


## Attacks (and ally shots) always outrank repositioning; the score breaks ties inside a kind.
func _shot_rank(shot: Dictionary) -> float:
	var tier := 0.0 if shot.kind == "reposition" else 1.0
	return tier * 1000000.0 + shot.score


## The best shot one enemy has: an attack if one scores above min_attack_score, otherwise a
## small safe reposition, otherwise a pass.
func _best_shot_for(enemy: Figure, players: Array[Figure], table: Rect2, max_force: float) -> Dictionary:
	var shape := CircleShape2D.new()
	shape.radius = enemy.radius
	var power := enemy.data.flick_power_multiplier * enemy.aura_flick_multiplier()
	var max_speed := max_force * power / enemy.mass
	var top_speed := minf(max_speed, reference_speed * power)

	var best := {}
	for target in players:
		var to_target := target.global_position - enemy.global_position
		if to_target.is_zero_approx():
			continue
		for offset in angle_offsets_degrees:
			var direction := to_target.normalized().rotated(deg_to_rad(offset))
			for level in power_levels:
				var shot := _score_attack(enemy, shape, direction, level * top_speed, top_speed, players, table)
				if not shot.is_empty() and (best.is_empty() or shot.score > best.score):
					shot["target"] = target  # who it is aimed at (Lucky Charm adds aim error)
					best = shot

	# Pinhead: a pin that sets up a bank shot may beat every direct shot (or there may be none).
	if enemy.ability.get_pin_radius(enemy) > 0.0:
		var bank := _best_bank_shot(enemy, shape, players, table, top_speed)
		if not bank.is_empty() and bank.score >= min_attack_score and (best.is_empty() or bank.score > best.score):
			best = bank

	if best.is_empty() or best.score < min_attack_score:
		var move := _choose_reposition(enemy, shape, players, table)
		if not move.is_empty():
			best = move
		elif best.is_empty() or best.score <= 0.0:
			best = {"kind": "pass", "score": 0.0}
	return best


# --- Attacks -----------------------------------------------------------------

func _score_attack(enemy: Figure, shape: CircleShape2D, direction: Vector2, speed: float,
		max_speed: float, players: Array[Figure], table: Rect2) -> Dictionary:
	var travel := _travel_distance(enemy, speed)
	if travel < 1.0:
		return {}
	var hit := _first_hit(enemy, shape, direction, travel)
	if hit.is_empty() or hit.collider == null:
		return {}  # would not reach anything (or a wall or pin is in the way)
	var other: Figure = hit.collider
	var hit_distance: float = hit.distance
	# Speed falls linearly with distance traveled under linear damping: v = v0 - damp * x.
	var hit_speed := maxf(speed - enemy.linear_damp * hit_distance, 0.0)

	# Predict the collision (masses, bounce, power) to see where both figures end up.
	var contact := enemy.global_position + direction * hit_distance
	var outcome := _predict_collision(enemy, other, direction * hit_speed, contact)
	var target_velocity: Vector2 = outcome.target
	var shooter_velocity: Vector2 = outcome.shooter

	var score := 0.0
	var kind := "attack"
	if other.team == Figure.Team.PLAYER:
		var knocked_off := _leave_chance(other, other.global_position, target_velocity, table)
		var pushed_toward_edge := _push_progress(other, other.global_position, target_velocity, table)
		score = hit_player_bonus + kill_bonus * knocked_off + edge_bonus * pushed_toward_edge
	else:
		var behind := _player_behind_ally(enemy, other, direction, players)
		if behind:
			kind = "ally"
			score = ally_strategic_factor * (hit_player_bonus \
					+ edge_bonus * _edge_factor(behind.global_position, direction, table))
		else:
			score = -ally_hit_penalty

	# Would the shooter itself slide off after the hit? (Light shooters bounce back off heavy targets.)
	score -= self_knock_off_penalty * _leave_chance(enemy, contact, shooter_velocity, table)
	# Aim error can make the shot miss, and a shooter that misses just keeps sliding. Count that risk.
	var to_other := other.global_position - enemy.global_position
	var miss_chance := 1.0 - _hit_chance(direction.angle_to(to_other), _aim_error(enemy),
			asin(clampf((enemy.radius + other.radius) / to_other.length(), 0.0, 1.0)))
	if miss_chance > 0.0:
		score -= self_knock_off_penalty * miss_chance * _flight_leave_chance(enemy, enemy.global_position, direction * speed, table)
	# Prefer the lowest power that gets the job done.
	score -= overpower_penalty * speed / max_speed

	return {"kind": kind, "score": score, "direction": direction, "speed": speed, "distance": hit_distance}


## The enemy's aim error in radians (either way), from its accuracy.
func _aim_error(enemy: Figure) -> float:
	return deg_to_rad((1.0 - enemy.data.accuracy) * max_aim_error_degrees)


## Chance (0 to 1) that a shot aimed `angle_off` radians away from the target's center still hits,
## given a random aim error of up to `error` either way and a target that is hit within
## `half_width` radians of its center.
func _hit_chance(angle_off: float, error: float, half_width: float) -> float:
	if error <= 0.0:
		return 1.0 if absf(angle_off) <= half_width else 0.0
	var overlap := minf(angle_off + error, half_width) - maxf(angle_off - error, -half_width)
	return clampf(overlap / (2.0 * error), 0.0, 1.0)


## Predicts a collision between the moving `shooter` (velocity `velocity` at `contact`, the
## position of its center when it touches) and a resting `target`. Elastic-collision maths along
## the line between the centers, with Godot's combined bounce and the figures' knockback
## multipliers. Returns the velocities both figures have right after: {shooter, target}.
func _predict_collision(shooter: Figure, target: Figure, velocity: Vector2, contact: Vector2) -> Dictionary:
	var normal := (target.global_position - contact).normalized()
	var closing := maxf(velocity.dot(normal), 0.0)
	var bounce := clampf(shooter.data.bounce + target.data.bounce, 0.0, 1.0)
	var total_mass := shooter.mass + target.mass
	var shooter_change := -(1.0 + bounce) * target.mass / total_mass * closing * normal
	var target_change := (1.0 + bounce) * shooter.mass / total_mass * closing * normal
	shooter_change *= shooter.data.knockback_taken_multiplier * shooter.ability.get_knockback_multiplier(shooter, target) \
			* shooter.aura_knockback_multiplier()
	target_change *= target.data.knockback_taken_multiplier * target.ability.get_knockback_multiplier(target, shooter) \
			* target.aura_knockback_multiplier()
	return {"shooter": velocity + shooter_change, "target": target_change}


## How far a figure at `from` moving at `velocity` slides, compared with the distance to the table
## edge in that direction (1 = just reaches it). Returns -1 if it is not moving.
func _slide_ratio(figure: Figure, from: Vector2, velocity: Vector2, table: Rect2) -> float:
	var speed := velocity.length()
	if speed <= figure.stop_speed:
		return -1.0
	var slide := (speed - figure.stop_speed) / figure.linear_damp
	var edge := _distance_to_edge(from, velocity / speed, table)
	if edge <= 0.0:
		return INF
	# A wall or pin in the way stops it going off the table (at least in this simple guess).
	if _blocked_by_arena(figure, from, velocity / speed, minf(slide, edge)):
		return minf(slide / edge, 0.5)
	return slide / edge


## 0 to 1: how likely the figure is to leave the table. Ramps up from sliding 70% of the way to
## the edge to sliding 120% of the way, since the prediction is only a guess.
func _leave_chance(figure: Figure, from: Vector2, velocity: Vector2, table: Rect2) -> float:
	return clampf((_slide_ratio(figure, from, velocity, table) - 0.7) / 0.5, 0.0, 1.0)


## Like _leave_chance, for a FREE flight (nothing is hit on the way). A figure that wraps around the
## table edge (Ghost, Wings) doesn't fall off the first time it crosses: it comes back in on the
## opposite side and keeps sliding, so only the last leg can knock it off.
func _flight_leave_chance(figure: Figure, from: Vector2, velocity: Vector2, table: Rect2) -> float:
	var flight := _simulate_wraps(figure, from, velocity, table)
	return _leave_chance(figure, flight.position, flight.velocity, table)


## Where a free flight ends up, counting wraps (the straight line if the figure can't wrap).
func _flight_end(figure: Figure, from: Vector2, velocity: Vector2, table: Rect2) -> Vector2:
	var flight := _simulate_wraps(figure, from, velocity, table)
	var speed: float = flight.velocity.length()
	if speed <= figure.stop_speed:
		return flight.position
	return flight.position + flight.velocity / speed * ((speed - figure.stop_speed) / figure.linear_damp)


## Follows a straight free flight; each time it would cross the table edge and the figure has a wrap
## left, it re-enters on the opposite side. Returns the start of the last leg: {position, velocity}.
func _simulate_wraps(figure: Figure, from: Vector2, velocity: Vector2, table: Rect2) -> Dictionary:
	var pos := from
	var vel := velocity
	for i in figure.ability.get_wrap_count(figure):
		var speed := vel.length()
		if speed <= figure.stop_speed:
			break
		var direction := vel / speed
		var slide := (speed - figure.stop_speed) / figure.linear_damp
		var edge := _distance_to_edge(pos, direction, table)
		if slide < edge:
			break  # stops before the edge: nothing to wrap
		var exit_point := pos + direction * (edge + 1.0)  # just past the edge
		pos = Vector2(table.position.x + fposmod(exit_point.x - table.position.x, table.size.x),
				table.position.y + fposmod(exit_point.y - table.position.y, table.size.y))
		vel = direction * maxf(speed - figure.linear_damp * edge, 0.0)
	return {"position": pos, "velocity": vel}


## 0 to 1: how far toward the edge the figure ends up.
func _push_progress(figure: Figure, from: Vector2, velocity: Vector2, table: Rect2) -> float:
	return clampf(_slide_ratio(figure, from, velocity, table), 0.0, 1.0)


## An ally is a strategic target if it sits between the shooter and a player figure and is
## roughly lined up with it, so pushing the ally should shove it into that player figure.
func _player_behind_ally(shooter: Figure, ally: Figure, direction: Vector2, players: Array[Figure]) -> Figure:
	var tolerance := deg_to_rad(ally_align_degrees)
	var to_ally := ally.global_position - shooter.global_position
	for player in players:
		var to_player := player.global_position - shooter.global_position
		if to_player.length() <= to_ally.length():
			continue  # not behind the ally
		var ally_to_player := player.global_position - ally.global_position
		if absf(to_ally.angle_to(to_player)) <= tolerance and absf(direction.angle_to(ally_to_player)) <= tolerance:
			return player
	return null


# --- Pinhead bank shots -------------------------------------------------------

## The best "place a pin, then bounce off it into a player figure" shot for a Pinhead, or {}. For every
## pin spot on a grid and every player figure it works out where the flick must hit the pin so that
## it bounces (like light off a mirror) toward the figure, checks both legs are clear, and scores the
## hit like a normal attack minus bank_shot_penalty.
func _best_bank_shot(enemy: Figure, shape: CircleShape2D, players: Array[Figure], table: Rect2,
		top_speed: float) -> Dictionary:
	var pin_radius := enemy.ability.get_pin_radius(enemy)
	var start := enemy.global_position
	var bounce_radius := pin_radius + enemy.radius  # the shooter's center bounces at this distance
	var area := table.grow(-(pin_radius + 40.0))
	var space := enemy.get_world_2d().direct_space_state
	var everyone := enemy.get_tree().get_nodes_in_group("figures")
	var best := {}
	var x := area.position.x
	while x <= area.end.x:
		var y := area.position.y
		while y <= area.end.y:
			var pin := Vector2(x, y)
			y += bank_grid_spacing
			if not _pin_spot_clear(pin, pin_radius, everyone):
				continue
			for target in players:
				var shot := _bank_shot_via(enemy, shape, pin, pin_radius, bounce_radius, target, table, top_speed)
				if not shot.is_empty() and (best.is_empty() or shot.score > best.score):
					best = shot
		x += bank_grid_spacing
	# The spot must really be free of walls and other pins too (checked once, for the winner).
	if not best.is_empty() and not Arena.is_spot_free(space, table, best.pin, pin_radius):
		return {}
	return best


func _pin_spot_clear(pin: Vector2, pin_radius: float, everyone: Array) -> bool:
	for node in everyone:
		var figure := node as Figure
		if not figure.knocked_off and figure.global_position.distance_to(pin) < figure.radius + pin_radius + 12.0:
			return false
	return true


func _bank_shot_via(enemy: Figure, shape: CircleShape2D, pin: Vector2, pin_radius: float, bounce_radius: float,
		target: Figure, table: Rect2, top_speed: float) -> Dictionary:
	var start := enemy.global_position
	var goal := target.global_position
	# Contact normal n (from the pin toward the shooter at the bounce): it bisects "back to the
	# shooter" and "on to the target". A few rounds of refinement since the contact point depends on n.
	var normal := ((start - pin).normalized() + (goal - pin).normalized())
	if normal.length() < 0.2:
		return {}
	normal = normal.normalized()
	for i in 4:
		var contact_center := pin + normal * bounce_radius
		var bisector := (start - contact_center).normalized() + (goal - contact_center).normalized()
		if bisector.length() < 0.2:
			return {}
		normal = bisector.normalized()
	var bounce_at := pin + normal * bounce_radius
	var leg1 := start.distance_to(bounce_at)
	if leg1 < enemy.radius + 20.0:
		return {}
	var direction := (bounce_at - start) / leg1
	if direction.dot(normal) > -0.1:
		return {}  # would not arrive at the pin from outside
	var rebound := direction - 2.0 * direction.dot(normal) * normal  # mirror bounce
	var leg2 := bounce_at.distance_to(goal)
	if rebound.dot((goal - bounce_at) / leg2) < cos(deg_to_rad(4.0)):
		return {}
	# The lowest power that still arrives at the target with enough speed.
	var speed := 0.0
	var speed_after_pin := 0.0
	for level in power_levels:
		var v0 := level * top_speed
		var v1 := v0 - enemy.linear_damp * leg1
		if v1 <= enemy.stop_speed:
			continue
		var v2 := v1 * bank_pin_kick
		if v2 - enemy.linear_damp * leg2 >= bank_min_hit_speed:
			speed = v0
			speed_after_pin = v2
			break
	if speed == 0.0:
		return {}
	if not _first_hit(enemy, shape, direction, leg1).is_empty():
		return {}  # something is in the way of the first leg
	var reach := minf((speed_after_pin - enemy.stop_speed) / enemy.linear_damp, leg2 + target.radius * 2.0)
	var hit := _first_hit(enemy, shape, rebound, reach, bounce_at)
	if hit.is_empty() or hit.collider == null or hit.collider.team != Figure.Team.PLAYER:
		return {}
	var other: Figure = hit.collider
	var hit_distance: float = hit.distance
	var hit_speed := maxf(speed_after_pin - enemy.linear_damp * hit_distance, 0.0)
	var contact := bounce_at + rebound * hit_distance
	var outcome := _predict_collision(enemy, other, rebound * hit_speed, contact)
	var knocked_off := _leave_chance(other, other.global_position, outcome.target, table)
	var pushed := _push_progress(other, other.global_position, outcome.target, table)
	var score := hit_player_bonus + kill_bonus * knocked_off + edge_bonus * pushed
	score -= self_knock_off_penalty * _leave_chance(enemy, contact, outcome.shooter, table)
	score -= bank_shot_penalty + overpower_penalty * speed / top_speed
	return {"kind": "attack", "score": score, "direction": direction, "speed": speed, "distance": leg1,
			"pin": pin, "pin_radius": pin_radius, "target": other}


# --- Repositioning -----------------------------------------------------------

func _choose_reposition(enemy: Figure, shape: CircleShape2D, players: Array[Figure], table: Rect2) -> Dictionary:
	var best := {}
	var best_score := -INF
	var safe_area := table.grow(-reposition_edge_margin)
	var inside := table.grow(-enemy.radius)
	# An enemy already close to the edge can't end up inside the safe area with a short flick, so
	# for it any shot that gets clearly farther from the edge counts (it still must not fall off).
	var start_margin := _edge_margin(enemy.global_position, table)
	var near_edge := start_margin < reposition_edge_margin
	var speed := reposition_distance * enemy.linear_damp + enemy.stop_speed
	for i in 16:
		var direction := Vector2.from_angle(TAU * i / 16.0)
		var end := _flight_end(enemy, enemy.global_position, direction * speed, table)
		var end_margin := _edge_margin(end, table)
		if near_edge:
			if not inside.has_point(end) or end_margin < start_margin + 40.0:
				continue
		elif not safe_area.has_point(end):
			continue
		# A little extra length so we don't end up nearly touching something.
		if not _first_hit(enemy, shape, direction, reposition_distance + 30.0).is_empty():
			continue
		# Prefer ending up closer to the nearest player figure (and, near the edge, farther from it).
		var score := -_nearest_distance(end, players)
		if near_edge:
			score += 2.0 * minf(end_margin, reposition_edge_margin)
		if score > best_score:
			best_score = score
			best = {"kind": "reposition", "score": score, "direction": direction,
					"speed": speed, "distance": reposition_distance}
	if best.is_empty() and near_edge:
		# Boxed in: a gentle flick straight toward the middle of the table is better than passing.
		var inward := (table.get_center() - enemy.global_position).normalized()
		best = {"kind": "reposition", "score": 0.0, "direction": inward,
				"speed": speed * 0.6, "distance": reposition_distance * 0.6}
	return best


## Distance from a point to the nearest table edge (negative outside the table).
func _edge_margin(pos: Vector2, table: Rect2) -> float:
	return minf(minf(pos.x - table.position.x, table.end.x - pos.x),
			minf(pos.y - table.position.y, table.end.y - pos.y))


# --- Prediction helpers ------------------------------------------------------

## How far a figure launched at `speed` slides before stopping.
func _travel_distance(figure: Figure, speed: float) -> float:
	return maxf(speed - figure.stop_speed, 0.0) / figure.linear_damp


## Sweeps the shooter's circle along `direction` for `length` px. Returns the first figure it
## would touch and how far the shooter travels to do so, or {} if the path is clear.
func _first_hit(shooter: Figure, shape: CircleShape2D, direction: Vector2, length: float,
		from := Vector2.INF) -> Dictionary:
	if from == Vector2.INF:
		from = shooter.global_position  # (a bank shot's second leg starts at the pin)
	var space := shooter.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, from)
	query.motion = direction * length
	query.collision_mask = shooter.collision_mask
	query.exclude = [shooter.get_rid()]
	# A sweep misses figures that are already touching the shooter, so check those first: if the
	# shot pushes into one, it is hit right away.
	var touch_shape := CircleShape2D.new()
	touch_shape.radius = shooter.radius + TOUCH_MARGIN
	var touch_query := PhysicsShapeQueryParameters2D.new()
	touch_query.shape = touch_shape
	touch_query.transform = query.transform
	touch_query.collision_mask = query.collision_mask
	touch_query.exclude = query.exclude
	for result in space.intersect_shape(touch_query, 8):
		var touching := result.collider as Figure
		if touching != null and direction.dot((touching.global_position - from).normalized()) > 0.05:
			return {"collider": touching, "distance": 0.0}
	var fractions := space.cast_motion(query)  # [safe, unsafe]; unsafe = 1 means nothing hit
	if fractions.size() < 2 or fractions[1] >= 1.0:
		return {}
	# Ask what is overlapping the shape where it first touches something.
	query.transform = Transform2D(0.0, from + direction * length * fractions[1])
	query.motion = Vector2.ZERO
	var best: Figure = null
	var best_distance := INF
	for result in space.intersect_shape(query, 8):
		var figure := result.collider as Figure
		if figure == null:
			continue
		var distance := from.distance_to(figure.global_position)
		if distance < best_distance:
			best = figure
			best_distance = distance
	# Nothing but a wall or pin there: report an obstacle (collider null) so callers can avoid it.
	return {"collider": best, "distance": length * fractions[0]}


## True if a wall or pin is in the way when `figure` slides `distance` px from `from`.
func _blocked_by_arena(figure: Figure, from: Vector2, direction: Vector2, distance: float) -> bool:
	if distance <= 0.0:
		return false
	var circle := CircleShape2D.new()
	circle.radius = figure.radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, from)
	query.motion = direction * distance
	query.collision_mask = Figure.LAYER_ARENA
	var fractions := figure.get_world_2d().direct_space_state.cast_motion(query)
	return fractions.size() >= 2 and fractions[1] < 1.0


## Distance from `pos` to the table edge along `direction`.
func _distance_to_edge(pos: Vector2, direction: Vector2, table: Rect2) -> float:
	var tx := INF
	var ty := INF
	if direction.x > 0.0:
		tx = (table.end.x - pos.x) / direction.x
	elif direction.x < 0.0:
		tx = (table.position.x - pos.x) / direction.x
	if direction.y > 0.0:
		ty = (table.end.y - pos.y) / direction.y
	elif direction.y < 0.0:
		ty = (table.position.y - pos.y) / direction.y
	return maxf(minf(tx, ty), 0.0)


## 0 to 1: how close to the table edge a figure pushed along `direction` is.
func _edge_factor(pos: Vector2, direction: Vector2, table: Rect2) -> float:
	return clampf(1.0 - _distance_to_edge(pos, direction, table) / edge_reach, 0.0, 1.0)


func _nearest_distance(pos: Vector2, figures: Array[Figure]) -> float:
	var best := INF
	for figure in figures:
		best = minf(best, pos.distance_to(figure.global_position))
	return best


# --- Debug drawing -----------------------------------------------------------

func _record_debug(enemy: Figure, shot: Dictionary, end: Vector2) -> void:
	_debug_shots.append({"from": enemy.global_position, "to": end, "kind": shot.kind, "score": shot.score})
	queue_redraw()


func _draw() -> void:
	if not debug_draw_shots:
		return
	var colors := {
		"attack": Color(1.0, 0.2, 0.2), "ally": Color(1.0, 0.6, 0.1),
		"reposition": Color(1.0, 0.9, 0.2), "pass": Color(0.7, 0.7, 0.7),
	}
	for shot in _debug_shots:
		var color: Color = colors[shot.kind]
		draw_line(shot.from, shot.to, color, 6.0, true)
		draw_circle(shot.to, 14.0, color)
		draw_string(ThemeDB.fallback_font, shot.to + Vector2(20.0, -20.0), "%s %.0f" % [shot.kind, shot.score],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 32, color)
