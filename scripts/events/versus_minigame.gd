class_name VersusMinigame
extends Minigame
## Shared rules of Bocce and Curling: you and an AI opponent take turns flicking Grunts (you first).
## When all are flicked and settled, whoever has the Grunt closest to the goal wins. A win pays money
## plus one random item (MinigameConfig); a loss makes the next fight harder (the minigame penalty).
## Subclasses give the goal point (`_goal()`), the table look and any setup.

@export_group("Match")
## Grunts each side flicks.
@export var stones_each := 3
@export var player_color := Color(0.3, 0.55, 1.0)
@export var opponent_color := Color(0.95, 0.5, 0.15)
## The opponent starts from the top edge (Bocce) instead of the bottom (Curling).
@export var opponent_from_top := false
## Distances are capped at this many px when scoring shots, so a shot that loses a stone is bad but finite.
@export var distance_cap := 3000.0

var ai := MinigameAI.new()
var stones: Array[Figure] = []
var _player_data: FigureData
var _opponent_data: FigureData
var _thrown := {Figure.Team.PLAYER: 0, Figure.Team.ENEMY: 0}  # flicks taken by each side
var _judged := false
var _closest_player := INF
var _closest_opponent := INF


## Override: a Banana Peel for Curling.
func _item() -> EquipmentData:
	return null


## Override: the point the stones are measured against (the jack, the target center).
func _goal() -> Vector2:
	return board_rect.get_center()


## Override: the goal after a predicted shot (`moved`: figure -> end point). Used by the opponent.
func _goal_after(_moved: Dictionary) -> Vector2:
	return _goal()


## Override (async): get the table ready before the first flick (Bocce tosses the jack).
func _setup_table() -> void:
	pass


## Override (async): runs after each flick has settled.
func _after_throw() -> void:
	pass


func _run() -> void:
	ai.name = "AI"
	add_child(ai)
	_player_data = colored_grunt(player_color)
	_opponent_data = colored_grunt(opponent_color)
	await _setup_table()
	for i in stones_each * 2:
		if i % 2 == 0:
			await _player_throw()
		else:
			await _opponent_throw()
		await wait_until_settled()
		await _after_throw()
	_judge()


func _left(team: Figure.Team) -> int:
	return stones_each - _thrown[team]


func _player_throw() -> void:
	var stone := spawn_figure(_player_data, Figure.Team.PLAYER, free_launch_point(), _item())
	stones.append(stone)
	_thrown[Figure.Team.PLAYER] += 1
	var left := _left(Figure.Team.PLAYER)
	await request_flick(stone, "Your flick: drag anywhere\n(you: %d more after this, opponent: %d)" % [left, _left(Figure.Team.ENEMY)])


func _opponent_throw() -> void:
	var stone := spawn_figure(_opponent_data, Figure.Team.ENEMY, free_launch_point(opponent_from_top), _item())
	stones.append(stone)
	_thrown[Figure.Team.ENEMY] += 1
	status_label.text = "Opponent's flick..."
	await get_tree().physics_frame  # let the physics server know the new body before casting shots
	await get_tree().physics_frame
	await get_tree().create_timer(config().ai_think_time).timeout
	var points: Array[Vector2] = [_goal()]
	for other in stones:
		if other != stone and alive(other):
			points.append(other.global_position)
	var impulse := ai.choose(stone, board_rect, full_force(stone), points, _score_outcome, config().ai_accuracy,
			config().ai_power_error)
	if impulse == Vector2.ZERO:
		impulse = (_goal() - stone.global_position).normalized() * full_force(stone) * 0.4
	stone.launch(impulse)


## How good a predicted outcome is for the opponent: how much closer its best Grunt is than yours.
func _score_outcome(moved: Dictionary) -> float:
	var goal := _goal_after(moved)
	if goal == Vector2.INF:
		return -10000.0
	var best_player := distance_cap
	var best_opponent := distance_cap
	for stone in stones:
		if not alive(stone):
			continue
		var point: Vector2 = moved.get(stone, stone.global_position)
		if point == Vector2.INF:
			continue
		var d := minf(point.distance_to(goal), distance_cap)
		if stone.team == Figure.Team.PLAYER:
			best_player = minf(best_player, d)
		else:
			best_opponent = minf(best_opponent, d)
	return best_player - best_opponent


func _nearest(team: Figure.Team) -> float:
	var best := INF
	for stone in stones:
		if alive(stone) and stone.team == team:
			best = minf(best, stone.global_position.distance_to(_goal()))
	return best


func _judge() -> void:
	_judged = true
	_closest_player = _nearest(Figure.Team.PLAYER)
	_closest_opponent = _nearest(Figure.Team.ENEMY)
	overlay.queue_redraw()
	var lines: Array[String] = ["Your closest: %s   Opponent's closest: %s" % [_dist_text(_closest_player), _dist_text(_closest_opponent)]]
	var outcome := 1 if _closest_player < _closest_opponent else (-1 if _closest_opponent < _closest_player else 0)
	conclude_contest(outcome, lines)


func _dist_text(distance: float) -> String:
	return "none left" if distance == INF else "%d" % roundi(distance)


## Final distance lines: from every Grunt still on the table to the goal; the winning one is gold.
func _draw_overlay() -> void:
	if not _judged:
		return
	var goal := _goal()
	var font := ThemeDB.fallback_font
	var best := minf(_closest_player, _closest_opponent)
	for stone in stones:
		if not alive(stone):
			continue
		var point := stone.global_position
		var distance := point.distance_to(goal)
		var winning := is_equal_approx(distance, best)
		var color := Color(1.0, 0.82, 0.25) if winning else (player_color if stone.team == Figure.Team.PLAYER else opponent_color)
		overlay.draw_line(goal, point, color, 10.0 if winning else 5.0, true)
		var middle := (goal + point) / 2.0
		var text := "%d" % roundi(distance)
		overlay.draw_string_outline(font, middle + Vector2(-30, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 8, Color(0, 0, 0, 0.9))
		overlay.draw_string(font, middle + Vector2(-30, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, color)
	overlay.draw_arc(goal, 20.0, 0.0, TAU, 32, Color(1.0, 0.82, 0.25), 6.0, true)
