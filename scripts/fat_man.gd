class_name FatMan
extends Node2D
## The Fat Man boss (act 3): a huge fixed stomach at the top with a hand on each side (see FatStomach, FatHand). The player wins by
## hitting the stomach `hits_needed` times. His turns alternate between GRAB (a hand reaches out for the most valuable or most
## exposed player figure in reach and carries it home, where it is held: it cannot be flicked or hit, but still counts as
## alive) and THROW (that hand throws the held figure hard at the spot that knocks the most figures off). The player can break
## the hold by hitting a hand that holds a figure hard enough (it drops it there). main.gd calls take_turn() as the whole
## enemy action and waits for the board to settle afterwards.

## The stomach: radius, and how far its centre is below the top of the board (px).
@export var stomach_radius := 290.0
@export var stomach_center_y := 30.0
## The hands: size, and where they rest (px sideways from the middle, px below the top of the board). They are solid there.
@export var hand_radius := 62.0
@export var hand_home_dx := 260.0
@export var hand_home_y := 410.0
## A grab only goes for a figure this close (px) to the hand's resting spot.
@export var grab_reach := 1500.0
## The throw speed (px/s; a full-power flick is about 2400).
@export var throw_speed := 2200.0
@export var reach_seconds := 0.45
@export var return_seconds := 0.45
@export var windup_seconds := 0.3
## Grab choice: points per rarity level, points for being near the table edge (within `exposure_range` px), and for being on the
## board rather than still on the deck.
@export var rarity_weight := 40.0
@export var exposure_weight := 120.0
@export var exposure_range := 250.0
@export var board_bonus := 0.0
## Throw choice: how much one figure knocked off is worth (the thrown one included).
@export var knock_off_value := 100.0

var stomach: FatStomach
var hands: Array[FatHand] = []
var _thrown: Figure


func build(board_rect: Rect2, hits_needed: int) -> void:
	var center_x := board_rect.position.x + board_rect.size.x / 2.0
	stomach = FatStomach.new()
	add_child(stomach)
	stomach.setup(stomach_radius, hits_needed)
	stomach.global_position = Vector2(center_x, board_rect.position.y + stomach_center_y)
	for side in [-1.0, 1.0]:
		var hand := FatHand.new()
		add_child(hand)
		hand.setup(hand_radius, Vector2(center_x + side * hand_home_dx, board_rect.position.y + hand_home_y))
		hand.dropped.connect(_on_dropped)
		hands.append(hand)


func defeated() -> bool:
	return stomach != null and stomach.defeated()


func held_figures() -> Array[Figure]:
	var list: Array[Figure] = []
	for hand in hands:
		if hand.is_holding():
			list.append(hand.held)
	return list


func _holder() -> FatHand:
	for hand in hands:
		if hand.is_holding():
			return hand
	return null


## The enemy's whole action this turn. Returns a short message for the turn label.
func take_turn(players: Array[Figure], table: Rect2, ai: EnemyAI) -> String:
	var holder := _holder()
	if holder != null:
		return await _throw(holder, players, table, ai)
	return await _grab(players, table)


# --- Grab ---------------------------------------------------------------------

func _grab(players: Array[Figure], table: Rect2) -> String:
	var best: Figure = null
	var best_hand: FatHand = null
	var best_score := -INF
	for figure in players:
		if not is_instance_valid(figure) or figure.knocked_off or figure.held:
			continue
		var hand := _nearest_hand(figure.global_position)
		if hand == null or hand.home.distance_to(figure.global_position) > grab_reach:
			continue
		var score := grab_score(figure, table)
		if score > best_score:
			best_score = score
			best = figure
			best_hand = hand
	if best == null:
		return "Fat Man has nothing in reach"
	best_hand.set_solid(false)
	var tween := create_tween()
	tween.tween_property(best_hand, "global_position", best.global_position, reach_seconds).set_trans(Tween.TRANS_QUAD)
	await tween.finished
	if not is_instance_valid(best) or best.knocked_off:
		await _return_home(best_hand)
		return "Fat Man grabs at thin air"
	_hold(best, best_hand)
	best.show_popup("Grabbed!", Color(1.0, 0.6, 0.5))
	await _return_home(best_hand)
	return "Fat Man grabs %s!" % best.data.display_name


## How tempting a figure is to grab: its rarity, how close it sits to the table edge, and being on the board.
func grab_score(figure: Figure, table: Rect2) -> float:
	var margin := minf(minf(figure.global_position.x - table.position.x, table.end.x - figure.global_position.x),
			minf(figure.global_position.y - table.position.y, table.end.y - figure.global_position.y))
	var exposure := clampf(1.0 - margin / exposure_range, 0.0, 1.0)
	var score := rarity_weight * figure.data.rarity + exposure_weight * exposure
	if not figure.on_deck:
		score += board_bonus
	if figure.equipment != null:
		score += 10.0
	score += 10.0 * maxi(figure.upgrade_state.y, 0)
	return score


func _nearest_hand(point: Vector2) -> FatHand:
	var best: FatHand = null
	var best_distance := INF
	for hand in hands:
		if hand.is_holding():
			continue
		var distance := hand.home.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = hand
	return best


func _hold(figure: Figure, hand: FatHand) -> void:
	figure.set_meta("fat_flickable", figure.flickable)
	figure.held = true
	figure.force_settle()
	figure.linear_velocity = Vector2.ZERO
	figure.collision_layer = 0
	figure.collision_mask = 0
	figure.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	figure.freeze = true
	figure.z_index = 2
	hand.held = figure


func _return_home(hand: FatHand) -> void:
	var tween := create_tween()
	tween.tween_property(hand, "global_position", hand.home, return_seconds).set_trans(Tween.TRANS_QUAD)
	await tween.finished
	hand.set_solid(true)


## Puts a held figure back among the normal ones (collision from its on_deck state).
func _release(figure: Figure) -> void:
	figure.held = false
	figure.freeze = false
	figure.z_index = 0
	figure._update_collision()


# --- Throw --------------------------------------------------------------------

func _throw(hand: FatHand, players: Array[Figure], table: Rect2, ai: EnemyAI) -> String:
	var figure: Figure = hand.held
	var choice := choose_throw(figure, hand.global_position, players, table, ai)
	var direction: Vector2 = choice.direction
	hand.set_solid(false)
	var windup := create_tween()
	windup.tween_property(hand, "global_position", hand.home - direction * 45.0, windup_seconds)
	await windup.finished
	if not is_instance_valid(figure) or not figure.held:
		await _return_home(hand)
		return "Fat Man fumbles"
	hand.held = null
	figure.teleport_to(hand.global_position)
	_release(figure)
	figure.on_deck = false
	figure.launch(direction * throw_speed * figure.mass)
	# The throw also hits and shoves figures still on the deck. Godot collisions are one-way unless both masks match, so for the
	# flight the thrown figure sits on the enemy layer with an enemy's mask (deck figures see it, and it sees them).
	figure.collision_layer = Figure.LAYER_ENEMY
	figure.collision_mask = Figure.LAYER_ENEMY | Figure.LAYER_FLICKED | Figure.LAYER_ON_DECK | Figure.LAYER_ARENA
	figure.show_popup("Thrown!", Color(1.0, 0.6, 0.5))
	_thrown = figure
	_return_home(hand)  # (not awaited: the hand goes home while the figure flies)
	return "Fat Man throws %s!" % figure.data.display_name


## After the thrown figure has stopped: it collides like any flicked figure again.
func finish_throw() -> void:
	if is_instance_valid(_thrown) and not _thrown.knocked_off:
		_thrown._update_collision()
	_thrown = null


## The best throw for `figure` from `from`: {direction, score}. Candidates: straight at every other player figure plus 16
## compass directions (covers a lone figure: it is thrown toward the nearest edge). A throw scores `knock_off_value` per figure
## it is expected to knock off, the thrown one included.
func choose_throw(figure: Figure, from: Vector2, players: Array[Figure], table: Rect2, ai: EnemyAI) -> Dictionary:
	var others: Array[Figure] = []
	for other in players:
		if is_instance_valid(other) and not other.knocked_off and other != figure and not other.held:
			others.append(other)
	var directions: Array[Vector2] = []
	for other in others:
		directions.append((other.global_position - from).normalized())
	for i in 16:
		directions.append(Vector2.from_angle(TAU * i / 16.0))
	var best := {"direction": Vector2.DOWN, "score": -INF}
	for direction in directions:
		var score := _throw_score(figure, from, direction, others, table, ai)
		if score > best.score:
			best = {"direction": direction, "score": score}
	return best


func _throw_score(figure: Figure, from: Vector2, direction: Vector2, others: Array[Figure], table: Rect2, ai: EnemyAI) -> float:
	# the first figure the thrown one would run into
	var hit: Figure = null
	var hit_along := INF
	for other in others:
		var offset := other.global_position - from
		var along := offset.dot(direction)
		if along <= 0.0:
			continue
		if absf(offset.cross(direction)) <= figure.radius + other.radius and along < hit_along:
			hit_along = along
			hit = other
	var speed := throw_speed
	var score := 0.0
	var flight_end := from + direction * (maxf(speed - figure.stop_speed, 0.0) / maxf(figure.linear_damp, 0.01))
	if hit == null:
		if not table.has_point(flight_end):
			score += knock_off_value * 0.99  # it flies off by itself
		return score + 0.01 * _edge_pull(from, direction, table)
	speed = maxf(speed - figure.linear_damp * hit_along, 0.0)
	var restitution := clampf(figure.data.bounce + hit.data.bounce, 0.0, 1.0)
	var mass_ratio := figure.mass / (figure.mass + hit.mass)
	var hit_velocity := direction * speed * (1.0 + restitution) * mass_ratio * hit.data.knockback_taken_multiplier
	var thrown_velocity := direction * speed * (figure.mass - restitution * hit.mass) / (figure.mass + hit.mass)
	var contact := from + direction * hit_along
	score += knock_off_value * ai._leave_chance(hit, hit.global_position, hit_velocity, table)
	score += knock_off_value * ai._leave_chance(figure, contact, thrown_velocity, table)
	return score


## Tie-break: how soon the direction reaches the table edge (a lone figure goes to the nearest edge).
func _edge_pull(from: Vector2, direction: Vector2, table: Rect2) -> float:
	var distance := INF
	if direction.x > 0.01:
		distance = minf(distance, (table.end.x - from.x) / direction.x)
	elif direction.x < -0.01:
		distance = minf(distance, (table.position.x - from.x) / direction.x)
	if direction.y > 0.01:
		distance = minf(distance, (table.end.y - from.y) / direction.y)
	elif direction.y < -0.01:
		distance = minf(distance, (table.position.y - from.y) / direction.y)
	return -distance if distance != INF else 0.0


# --- Counterplay --------------------------------------------------------------

## A player figure hit a hand hard enough: the hand drops what it holds, right there.
func _on_dropped(hand: FatHand) -> void:
	if not hand.is_holding():
		return
	var figure: Figure = hand.held
	hand.held = null
	var side := signf(hand.home.x - stomach.global_position.x)
	figure.teleport_to(hand.global_position + Vector2(side * (hand.radius + figure.radius + 8.0), 0.0))
	figure.on_deck = false
	_release(figure)
	figure.flickable = bool(figure.get_meta("fat_flickable", true))
	figure.show_popup("Dropped!", Color(0.6, 1.0, 0.6))
