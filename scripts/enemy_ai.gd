class_name EnemyAI
extends Node2D
## Enemy brain. For each enemy it tries many candidate shots (targets x angles x power levels),
## shape-casts each one to find the first figure it would hit, scores them, and picks the best.
## If nothing scores well it makes a small safe repositioning flick instead.

@export_group("Candidate shots")
## Angles (degrees) tried either side of the straight line to each player figure.
@export var angle_offsets_degrees: Array[float] = [-10.0, -5.0, 0.0, 5.0, 10.0]
## Flick powers tried, as a fraction of the enemy's top speed. Higher = enemies hit harder and
## knock more of your figures off (at full power they can wipe out your deck).
@export var power_levels: Array[float] = [0.3, 0.45, 0.6]
## The speed (px/s) that a power level of 1.0 means for a figure with flick power 1. A figure with
## flick power 2 (like the snipers' 1.6) gets that multiple, up to what it physically can flick.
@export var reference_speed := 2400.0

@export_group("Scoring")
## Score for a first hit on a player figure.
@export var hit_player_bonus := 100.0
## Extra score (up to this) when the hit figure is near the table edge in the push direction.
@export var edge_bonus := 60.0
## A target this close (px) to the edge, along the shot, gets the full edge bonus.
@export var edge_reach := 450.0
## Extra score (up to this) for hitting hard.
@export var hit_speed_bonus := 10.0
## Penalty for hitting another enemy first.
@export var ally_hit_penalty := 150.0
## Hitting an ally that is lined up with a player figure behind it scores this fraction of a normal hit.
@export var ally_strategic_factor := 0.5
## How far off line (degrees) an ally can be and still count as "lined up" with a player figure.
@export var ally_align_degrees := 8.0
## Penalty if the shooter would probably slide off the table.
@export var shooter_off_penalty := 120.0
## Attacks scoring below this are skipped in favor of repositioning.
@export var min_attack_score := 40.0

@export_group("Repositioning")
## How far (px) a repositioning flick slides.
@export var reposition_distance := 180.0
## Repositioning flicks must end at least this far (px) inside the table edge.
@export var reposition_edge_margin := 150.0

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


## Returns the impulse for `enemy` to flick, or Vector2.ZERO to skip its turn.
## Call from a physics-safe moment (it uses the physics space for shape casts).
func choose_shot(enemy: Figure, players: Array[Figure], table: Rect2, max_force: float) -> Vector2:
	var shape := CircleShape2D.new()
	shape.radius = enemy.radius
	var max_speed := max_force * enemy.data.flick_power_multiplier / enemy.mass
	var top_speed := minf(max_speed, reference_speed * enemy.data.flick_power_multiplier)

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
					best = shot

	if best.is_empty() or best.score < min_attack_score:
		var move := _choose_reposition(enemy, shape, players, table)
		if not move.is_empty():
			best = move
		elif best.is_empty() or best.score <= 0.0:
			best = {"kind": "pass", "score": 0.0}

	if best.kind == "pass":
		_record_debug(enemy, best, enemy.global_position)
		return Vector2.ZERO

	# Small random aim error: worse accuracy = bigger error.
	var error := deg_to_rad((1.0 - enemy.data.accuracy) * max_aim_error_degrees)
	var direction: Vector2 = best.direction.rotated(randf_range(-error, error))
	_record_debug(enemy, best, enemy.global_position + direction * best.distance)
	return direction * best.speed * enemy.mass


# --- Attacks -----------------------------------------------------------------

func _score_attack(enemy: Figure, shape: CircleShape2D, direction: Vector2, speed: float,
		max_speed: float, players: Array[Figure], table: Rect2) -> Dictionary:
	var travel := _travel_distance(enemy, speed)
	if travel < 1.0:
		return {}
	var hit := _first_hit(enemy, shape, direction, travel)
	if hit.is_empty():
		return {}  # would not reach anything
	var other: Figure = hit.collider
	var hit_distance: float = hit.distance
	# Speed falls linearly with distance traveled under linear damping: v = v0 - damp * x.
	var hit_speed := maxf(speed - enemy.linear_damp * hit_distance, 0.0)

	var score := 0.0
	var kind := "attack"
	if other.team == Figure.Team.PLAYER:
		score = hit_player_bonus \
				+ edge_bonus * _edge_factor(other.global_position, direction, table) \
				+ hit_speed_bonus * hit_speed / max_speed
	else:
		var behind := _player_behind_ally(enemy, other, direction, players)
		if behind:
			kind = "ally"
			score = ally_strategic_factor * (hit_player_bonus \
					+ edge_bonus * _edge_factor(behind.global_position, direction, table))
		else:
			score = -ally_hit_penalty

	# Would the shooter itself slide off? Guess an elastic hit: it keeps (m1 - m2) / (m1 + m2) of
	# its speed, so a light shooter hitting a heavy target bounces back (negative).
	var carry := (enemy.mass - other.mass) / (enemy.mass + other.mass)
	var contact := enemy.global_position + direction * hit_distance
	var slide := absf(hit_speed * carry) / enemy.linear_damp
	var slide_direction := direction if carry >= 0.0 else -direction
	if slide >= _distance_to_edge(contact, slide_direction, table):
		score -= shooter_off_penalty

	return {"kind": kind, "score": score, "direction": direction, "speed": speed, "distance": hit_distance}


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


# --- Repositioning -----------------------------------------------------------

func _choose_reposition(enemy: Figure, shape: CircleShape2D, players: Array[Figure], table: Rect2) -> Dictionary:
	var best := {}
	var best_score := -INF
	var safe_area := table.grow(-reposition_edge_margin)
	for i in 8:
		var direction := Vector2.from_angle(TAU * i / 8.0)
		var end := enemy.global_position + direction * reposition_distance
		if not safe_area.has_point(end):
			continue
		# A little extra length so we don't end up nearly touching something.
		if not _first_hit(enemy, shape, direction, reposition_distance + 30.0).is_empty():
			continue
		# Prefer ending up closer to the nearest player figure.
		var score := -_nearest_distance(end, players)
		if score > best_score:
			best_score = score
			best = {"kind": "reposition", "score": score, "direction": direction,
					"speed": reposition_distance * enemy.linear_damp + enemy.stop_speed,
					"distance": reposition_distance}
	return best


# --- Prediction helpers ------------------------------------------------------

## How far a figure launched at `speed` slides before stopping.
func _travel_distance(figure: Figure, speed: float) -> float:
	return maxf(speed - figure.stop_speed, 0.0) / figure.linear_damp


## Sweeps the shooter's circle along `direction` for `length` px. Returns the first figure it
## would touch and how far the shooter travels to do so, or {} if the path is clear.
func _first_hit(shooter: Figure, shape: CircleShape2D, direction: Vector2, length: float) -> Dictionary:
	var space := shooter.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, shooter.global_position)
	query.motion = direction * length
	query.collision_mask = shooter.collision_mask
	query.exclude = [shooter.get_rid()]
	var fractions := space.cast_motion(query)  # [safe, unsafe]; unsafe = 1 means nothing hit
	if fractions.size() < 2 or fractions[1] >= 1.0:
		return {}
	# Ask what is overlapping the shape where it first touches something.
	query.transform = Transform2D(0.0, shooter.global_position + direction * length * fractions[1])
	query.motion = Vector2.ZERO
	var best: Figure = null
	var best_distance := INF
	for result in space.intersect_shape(query, 8):
		var figure := result.collider as Figure
		if figure == null:
			continue
		var distance := shooter.global_position.distance_to(figure.global_position)
		if distance < best_distance:
			best = figure
			best_distance = distance
	if best == null:
		return {}
	return {"collider": best, "distance": length * fractions[0]}


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
