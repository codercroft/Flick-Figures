extends Node2D
## Game controller: spawns figures, reads touch input, runs the player/enemy turn loop.

enum State { PLAYER_TURN, AIMING, SETTLING, ENEMY_TURN, GAME_OVER }

const PLAYER_COLORS := [
	Color(0.25, 0.5, 0.9),
	Color(0.3, 0.75, 0.35),
	Color(0.95, 0.75, 0.2),
	Color(0.7, 0.4, 0.9),
]
const ENEMY_COLOR := Color(0.85, 0.15, 0.15)

@export var figure_scene: PackedScene

@export_group("Flick")
## Impulse of a full-strength flick. Launch speed = force / mass.
@export var max_flick_force := 2400.0
## Drag this far (px) for a full-strength flick.
@export var max_pull_distance := 300.0
## Drags shorter than this (px) are cancelled instead of flicking.
@export var min_pull_distance := 40.0
## Extra px around a figure that still counts as touching it.
@export var grab_padding := 30.0

@export_group("Figure physics")
@export var figure_count := 4
@export var figure_radius := 60.0
@export var figure_mass := 1.0
## How quickly figures slow down. Higher = stops sooner. Slide distance ~ speed / damping.
@export var figure_damping := 1.5
@export var figure_bounciness := 0.7
## Figures slower than this (px/s) stop dead.
@export var stop_speed := 15.0

@export_group("Enemy")
@export var enemy_count := 3
## Each enemy aims at the nearest player figure, off by up to this many degrees either way.
@export var enemy_angle_error := 8.0
## Enemies flick hard enough to travel this far (px) past their target.
@export var enemy_overshoot := 40.0
## Pause (seconds) before each enemy flicks.
@export var enemy_think_time := 0.6

@export_group("Turn")
## Wait this long (seconds) after a flick before checking that everything has stopped.
@export var settle_delay := 0.3
@export var knock_off_fade_time := 0.4
## Ignore taps this long (seconds) after the win/lose screen appears.
@export var restart_tap_delay := 0.5

var _state := State.PLAYER_TURN
var _players: Array[Figure] = []
var _enemies: Array[Figure] = []
var _aim_figure: Figure
var _touch_index := -1
var _touch_start := Vector2.ZERO
var _needs_reload := false  # player has nothing on deck: tap a board figure to reload it
var _can_restart := false

@onready var board := $Board
@onready var figures_root := $Figures
@onready var aim_line := $AimLine
@onready var ui := $UI


func _ready() -> void:
	_spawn_players()
	_spawn_enemies()
	_start_player_turn()


func _physics_process(_delta: float) -> void:
	_knock_off_fallen_figures()


# --- Input -------------------------------------------------------------------
# Written against touch events; "emulate touch from mouse" makes the mouse work too.

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var pos := _to_world(event.position)
		if event.pressed:
			_on_press(event.index, pos)
		elif event.index == _touch_index:
			if event.canceled:
				_cancel_aim()
			else:
				_release_aim(pos)
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_aim(_to_world(event.position))


func _to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos


func _on_press(index: int, pos: Vector2) -> void:
	match _state:
		State.PLAYER_TURN:
			if _needs_reload:
				_try_reload(pos)
			else:
				_begin_aim(index, pos)
		State.GAME_OVER:
			if _can_restart:
				get_tree().reload_current_scene()


# --- Player turn: reload, aim, flick -----------------------------------------

func _start_player_turn() -> void:
	_state = State.PLAYER_TURN
	_needs_reload = not _has_figure_on_deck()
	if _needs_reload:
		ui.show_your_turn("Your turn: tap a figure to reload")
	else:
		ui.show_your_turn()


func _try_reload(pos: Vector2) -> void:
	var figure := _player_figure_at(pos, false)
	if figure == null:
		return
	figure.return_to_deck()
	_needs_reload = false
	ui.show_your_turn()


func _begin_aim(index: int, pos: Vector2) -> void:
	var figure := _player_figure_at(pos, true)
	if figure == null:
		return
	_state = State.AIMING
	_touch_index = index
	_aim_figure = figure
	_touch_start = pos
	_update_aim(pos)


func _update_aim(pos: Vector2) -> void:
	if _state != State.AIMING:
		return
	var impulse := _flick_impulse(pos)
	if impulse == Vector2.ZERO:
		aim_line.clear()
		return
	# Roughly where the figure will come to rest (ignores bumping into things).
	var speed := impulse.length() / figure_mass
	var distance := maxf(speed - stop_speed, 0.0) / figure_damping
	var direction := impulse.normalized()
	aim_line.show_aim(_aim_figure.global_position + direction * figure_radius, direction, distance)


func _release_aim(pos: Vector2) -> void:
	if _state != State.AIMING:
		return
	var impulse := _flick_impulse(pos)
	if impulse == Vector2.ZERO:
		_cancel_aim()
		return
	aim_line.clear()
	_aim_figure.launch(impulse)
	_aim_figure = null
	_touch_index = -1
	_state = State.SETTLING
	_finish_player_turn()


func _cancel_aim() -> void:
	aim_line.clear()
	_aim_figure = null
	_touch_index = -1
	_state = State.PLAYER_TURN


## The flick is opposite the drag. Drag down = flick up. Zero means "no flick".
func _flick_impulse(pos: Vector2) -> Vector2:
	var drag := pos - _touch_start
	var pull := minf(drag.length(), max_pull_distance)
	if pull < min_pull_distance or drag.y <= 0.0:
		return Vector2.ZERO
	return -drag.normalized() * (pull / max_pull_distance) * max_flick_force


func _player_figure_at(pos: Vector2, on_deck: bool) -> Figure:
	var best: Figure = null
	var best_distance := INF
	for figure in _players:
		var distance := figure.global_position.distance_to(pos)
		if figure.on_deck == on_deck and distance <= figure.radius + grab_padding and distance < best_distance:
			best = figure
			best_distance = distance
	return best


func _has_figure_on_deck() -> bool:
	for figure in _players:
		if figure.on_deck:
			return true
	return false


# --- Turn loop ---------------------------------------------------------------

func _finish_player_turn() -> void:
	await _wait_until_settled()
	if _check_game_over():
		return
	await _run_enemy_turn()


func _run_enemy_turn() -> void:
	_state = State.ENEMY_TURN
	ui.show_enemy_turn()
	for enemy in _enemies.duplicate():
		await get_tree().create_timer(enemy_think_time).timeout
		if enemy.knocked_off:
			continue
		var target := _nearest_player_figure(enemy)
		if target == null:
			break
		enemy.launch(_enemy_impulse(enemy, target))
		await _wait_until_settled()
		if _check_game_over():
			return
	_start_player_turn()


## Enemy AI: flick at the nearest player figure (on deck or not), with some angle error.
func _enemy_impulse(enemy: Figure, target: Figure) -> Vector2:
	var to_target := target.global_position - enemy.global_position
	var error := deg_to_rad(randf_range(-enemy_angle_error, enemy_angle_error))
	var direction := to_target.normalized().rotated(error)
	# Same maths as the aim line: slide distance = (speed - stop_speed) / damping.
	var speed := (to_target.length() + enemy_overshoot) * figure_damping + stop_speed
	return direction * minf(speed * figure_mass, max_flick_force)


func _nearest_player_figure(from: Figure) -> Figure:
	var best: Figure = null
	var best_distance := INF
	for figure in _players:
		var distance := from.global_position.distance_to(figure.global_position)
		if distance < best_distance:
			best = figure
			best_distance = distance
	return best


func _wait_until_settled() -> void:
	await get_tree().create_timer(settle_delay).timeout
	while not _all_figures_resting():
		await get_tree().physics_frame


func _all_figures_resting() -> bool:
	for figure in _all_figures():
		if not figure.is_resting():
			return false
	return true


func _check_game_over() -> bool:
	if _enemies.is_empty():
		_end_game(true)
		return true
	if _players.is_empty():
		_end_game(false)
		return true
	return false


func _end_game(won: bool) -> void:
	_state = State.GAME_OVER
	ui.show_result(won)
	await get_tree().create_timer(restart_tap_delay).timeout
	_can_restart = true


# --- Figures -----------------------------------------------------------------

func _spawn_players() -> void:
	var deck: Rect2 = board.deck_rect
	var slot_width := deck.size.x / figure_count
	for i in figure_count:
		var pos := Vector2(deck.position.x + slot_width * (i + 0.5), deck.get_center().y)
		var figure := _spawn_figure(Figure.Team.PLAYER, PLAYER_COLORS[i % PLAYER_COLORS.size()], pos)
		figure.deck_position = pos
		_players.append(figure)


func _spawn_enemies() -> void:
	var rect: Rect2 = board.board_rect
	var slot_width := rect.size.x / enemy_count
	for i in enemy_count:
		# Stagger every other enemy so they are not in a straight line.
		var pos := Vector2(rect.position.x + slot_width * (i + 0.5), rect.position.y + 160.0 + 120.0 * (i % 2))
		_enemies.append(_spawn_figure(Figure.Team.ENEMY, ENEMY_COLOR, pos))


func _spawn_figure(team: Figure.Team, color: Color, pos: Vector2) -> Figure:
	var figure: Figure = figure_scene.instantiate()
	figure.team = team
	figure.on_deck = team == Figure.Team.PLAYER
	figure.radius = figure_radius
	figure.mass = figure_mass
	figure.linear_damp = figure_damping
	figure.bounciness = figure_bounciness
	figure.stop_speed = stop_speed
	figure.color = color
	figure.position = pos
	figures_root.add_child(figure)
	return figure


func _all_figures() -> Array[Figure]:
	var all: Array[Figure] = []
	all.append_array(_players)
	all.append_array(_enemies)
	return all


func _knock_off_fallen_figures() -> void:
	var table: Rect2 = board.get_table_rect()
	for figure in _all_figures():
		if not table.has_point(figure.global_position):
			_players.erase(figure)
			_enemies.erase(figure)
			figure.knock_off(knock_off_fade_time)
