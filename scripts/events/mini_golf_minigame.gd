class_name MiniGolfMinigame
extends Minigame
## Mini-Golf: a random putt-putt course (an arena layout with walls, pins, ramps and slow patches). You
## and the AI each play your own ball from the tee, alternating strokes (you first); the balls can
## collide. A ball that rolls over the hole slowly enough drops in, and the first ball in wins. After
## `max_strokes` each, the ball nearest the hole wins. A win pays money plus a random item; a loss makes
## the next fight harder.

@export_group("Course")
## The courses to pick from at random (resources/golf/).
@export var courses: Array[GolfCourse] = []
@export var course_color := Color(0.22, 0.55, 0.3)
@export var max_strokes := 6

@export_group("Ball")
@export var ball_radius := 24.0
@export var ball_mass := 0.6
## Multiplies the flick strength: a full pull rolls about 1300 px.
@export var ball_power := 0.5
@export var player_color := Color(0.3, 0.55, 1.0)
@export var opponent_color := Color(0.95, 0.5, 0.15)

@export_group("Hole")
@export var hole_radius := 36.0
## A ball over the hole drops in if it is slower than this (px/s); faster balls roll across.
@export var capture_speed := 450.0

var arena := Arena.new()
var ai := GolfAI.new()
var sim := GolfSim.new()
var course: GolfCourse
var _player_ball: Figure
var _opponent_ball: Figure
var _strokes := {Figure.Team.PLAYER: 0, Figure.Team.ENEMY: 0}
var _last_rest := {}  # ball -> where it last came to rest (a ball that leaves the course goes back there)
var _over := false
var _no_sink_ending := false
var _hole_world := Vector2.ZERO
var _tee_world := Vector2.ZERO


func _init() -> void:
	board_color = Color(0.22, 0.55, 0.3)
	border_color = Color(0.2, 0.3, 0.2)


func _draw_table() -> void:
	if course == null:
		return
	# The tee, and the hole with a little flag.
	draw_circle(_tee_world, 46.0, Color(1, 1, 1, 0.18))
	draw_arc(_tee_world, 46.0, 0.0, TAU, 40, Color(1, 1, 1, 0.5), 4.0, true)
	draw_circle(_hole_world, hole_radius + 6.0, Color(0.1, 0.25, 0.15))
	draw_circle(_hole_world, hole_radius, Color(0.03, 0.03, 0.03))
	draw_line(_hole_world, _hole_world + Vector2(0, -90), Color.WHITE, 5.0)
	draw_colored_polygon(PackedVector2Array([_hole_world + Vector2(0, -90), _hole_world + Vector2(46, -74), _hole_world + Vector2(0, -58)]), Color(0.9, 0.2, 0.2))


func _run() -> void:
	if courses.is_empty():
		push_error("[golf] no courses set")
		show_result("No course", Color.WHITE, ["Nothing to play here."])
		return
	course = courses.pick_random()
	_tee_world = board_rect.position + course.tee
	_hole_world = board_rect.position + course.hole
	queue_redraw()
	add_child(arena)
	move_child(arena, figures_root.get_index())
	arena.build(course.layout, board_rect)
	ai.name = "AI"
	add_child(ai)
	sim.hole = _hole_world
	sim.hole_radius = hole_radius
	sim.capture_speed = capture_speed
	sim.ball_radius = ball_radius
	status_label.text = "%s: %s" % [course.display_name, course.description]
	_player_ball = _spawn_ball(player_color, Figure.Team.PLAYER, _tee_world + Vector2(-30, 0))
	_opponent_ball = _spawn_ball(opponent_color, Figure.Team.ENEMY, _tee_world + Vector2(30, 0))
	sim.setup(course.layout, board_rect.position, arena)
	sim.damping = _player_ball.linear_damp
	sim.stop_speed = stop_speed
	await get_tree().create_timer(1.5).timeout
	for stroke in max_strokes:
		await _player_stroke()
		if _over:
			return
		await _opponent_stroke()
		if _over:
			return
	_judge_by_distance()


func _spawn_ball(color: Color, team: Figure.Team, pos: Vector2) -> Figure:
	var data := make_data("Ball", "", color, ball_radius, ball_mass)
	data.flick_power_multiplier = ball_power
	var ball := spawn_figure(data, team, pos)
	_last_rest[ball] = pos
	return ball


func _status(text: String) -> void:
	status_label.text = "%s\n(strokes: you %d/%d, opponent %d/%d)" % [text, _strokes[Figure.Team.PLAYER], max_strokes,
			_strokes[Figure.Team.ENEMY], max_strokes]


func _player_stroke() -> void:
	_strokes[Figure.Team.PLAYER] += 1
	await request_flick(_player_ball, "Your stroke %d of %d: drag anywhere\n(opponent: %d)" % [_strokes[Figure.Team.PLAYER], max_strokes, _strokes[Figure.Team.ENEMY]])
	await _settle_stroke()


func _opponent_stroke() -> void:
	_strokes[Figure.Team.ENEMY] += 1
	_status("Opponent's stroke...")
	await get_tree().create_timer(config().ai_think_time).timeout
	sim.obstacles.clear()
	if alive(_player_ball):
		sim.obstacles.append({"center": _player_ball.global_position, "radius": _player_ball.radius})
	var impulse := await ai.choose(_opponent_ball, sim, full_force(_opponent_ball), config().golf_ai_accuracy,
			config().golf_ai_power_error)
	_opponent_ball.launch(impulse)
	await _settle_stroke()


func _settle_stroke() -> void:
	await wait_until_settled()
	for ball in [_player_ball, _opponent_ball]:
		if alive(ball):
			_last_rest[ball] = ball.global_position


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _over:
		return
	for ball in [_player_ball, _opponent_ball]:
		if alive(ball) and ball.global_position.distance_to(_hole_world) < hole_radius \
				and ball.linear_velocity.length() < capture_speed:
			_sink(ball)
			return


## A ball that leaves the course (it should not: the layouts have outer walls) goes back to where it last rested.
func on_fell(figure: Figure) -> void:
	figure.global_position = _last_rest.get(figure, _tee_world)
	figure.linear_velocity = Vector2.ZERO


func _sink(ball: Figure) -> void:
	_over = true
	ball.global_position = _hole_world
	ball.linear_velocity = Vector2.ZERO
	ball.knock_off(0.4, true)
	var mine := ball == _player_ball
	var lines: Array[String] = ["%s ball dropped in!" % ("Your" if mine else "The opponent's"),
			"Strokes: you %d, opponent %d" % [_strokes[Figure.Team.PLAYER], _strokes[Figure.Team.ENEMY]]]
	conclude_contest(1 if mine else -1, lines)


func _judge_by_distance() -> void:
	_over = true
	_no_sink_ending = true
	overlay.queue_redraw()
	var mine := _player_ball.global_position.distance_to(_hole_world)
	var theirs := _opponent_ball.global_position.distance_to(_hole_world)
	var lines: Array[String] = ["Out of strokes. Nearest the hole: you %d, opponent %d" % [roundi(mine), roundi(theirs)]]
	conclude_contest(1 if mine < theirs else (-1 if theirs < mine else 0), lines)


func _draw_overlay() -> void:
	if not _no_sink_ending:
		return
	var font := ThemeDB.fallback_font
	for ball in [_player_ball, _opponent_ball]:
		var color := player_color if ball == _player_ball else opponent_color
		var point: Vector2 = ball.global_position
		overlay.draw_line(_hole_world, point, color, 6.0, true)
		var middle := (_hole_world + point) / 2.0
		var text := "%d" % roundi(point.distance_to(_hole_world))
		overlay.draw_string_outline(font, middle + Vector2(-30, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 8, Color(0, 0, 0, 0.9))
		overlay.draw_string(font, middle + Vector2(-30, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, color)
