extends Node2D
## Game controller: spawns figures, reads touch input, runs the player/enemy turn loop.

enum State { PLAYER_TURN, AIMING, SETTLING, ENEMY_TURN, GAME_OVER }

const REWARD_SCENE := "res://scenes/reward.tscn"
const MAP_SCENE := "res://scenes/map.tscn"

@export var figure_scene: PackedScene

@export_group("Flick")
## Impulse of a full-strength flick. Launch speed = force * figure's power multiplier / mass.
@export var max_flick_force := 2400.0
## Drag this far, as a fraction of the screen width, for a full-strength flick.
@export_range(0.1, 0.6) var max_pull_fraction := 0.3
## Drags shorter than this (px) are cancelled instead of flicking.
@export var min_pull_distance := 40.0
## Extra px around a figure that still counts as touching it.
@export var grab_padding := 30.0

@export_group("Figures")
## (Which figures fight comes from the RunManager autoload: your deck and this combat's enemies.)
## Base damping for all figures; each FigureData multiplies it. Higher = stops sooner.
## Slide distance ~ speed / damping.
@export var figure_damping := 1.5
## Figures slower than this (px/s) count as slow...
@export var stop_speed := 15.0
## ...and stop dead after being slow for this many physics frames in a row.
@export var settle_frames := 5

@export_group("Enemy")
## Pause (seconds) before each enemy flicks.
@export var enemy_think_time := 0.6

@export_group("Turn")
## Wait this long (seconds) after a flick before checking that everything has stopped.
@export var settle_delay := 0.3
## Safety net: if figures still move this long (seconds) after a flick, stop them all.
@export var max_settle_time := 6.0
## After this long (seconds) of waiting, show (and print) which figures are still moving.
@export var settle_debug_after := 5.0
@export var settle_debug := true
## Last resort: if a whole turn takes this long (seconds), hand control back to the player.
@export var turn_timeout := 90.0
@export var knock_off_fade_time := 0.4
## Ignore taps this long (seconds) after the run-over screen appears.
@export var restart_tap_delay := 0.5
## Pause (seconds) after the last enemy falls before the reward screen.
@export var reward_delay := 1.2

var _state := State.PLAYER_TURN
var _players: Array[Figure] = []
var _enemies: Array[Figure] = []
var _aim_figure: Figure
var _selected: Figure  # the figure chosen for aiming (highlighted)
var _turn_serial := 0  # bumped by the watchdog so a stuck turn's coroutines stop
var _busy_time := 0.0  # seconds spent settling or in the enemy turn
var _touch_index := -1
var _touch_start := Vector2.ZERO
var _needs_reload := false  # player has nothing on deck: tap a board figure to reload it
var _can_restart := false

@onready var board := $Board
@onready var arena: Arena = $Arena
@onready var figures_root := $Figures
@onready var aim_line := $AimLine
@onready var ui := $UI
@onready var game_feel := $GameFeel
@onready var ai: EnemyAI = $EnemyAI


func _ready() -> void:
	ui.show_progress(RunManager.progress_text())
	arena.build(RunManager.arena, board.board_rect)
	if RunManager.arena != null:
		ui.show_arena_name(RunManager.arena.display_name)
	_spawn_players()
	_spawn_enemies()
	board.show_deck_line = _has_creeper()
	_start_player_turn()


func _physics_process(_delta: float) -> void:
	_knock_off_fallen_figures()


## Watchdog: the turn loop should always finish, but if it ever gets stuck, recover.
func _process(delta: float) -> void:
	if _state != State.SETTLING and _state != State.ENEMY_TURN:
		return
	_busy_time += delta
	if _busy_time > turn_timeout:
		push_error("[turn] stuck for %.0fs in state %d; handing control back to the player" % [_busy_time, _state])
		_turn_serial += 1
		_force_settle()
		_start_player_turn()


# --- Input -------------------------------------------------------------------
# Written against touch events; "emulate touch from mouse" makes the mouse work too.

func _input(event: InputEvent) -> void:
	# Only the player's turn (and the run-over screen) takes touches. Everything else is ignored.
	if _state != State.PLAYER_TURN and _state != State.AIMING and _state != State.GAME_OVER:
		return
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
				RunManager.start_new_run()
				get_tree().change_scene_to_file(MAP_SCENE)


# --- Player turn: reload, aim, flick -----------------------------------------

func _start_player_turn() -> void:
	_state = State.PLAYER_TURN
	_busy_time = 0.0
	_touch_index = -1
	_aim_figure = null
	aim_line.clear()
	_deselect()
	ui.show_debug("")
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


## Press on a figure: it is selected and aimed in one motion. Press anywhere else: aims the
## already selected figure. The drag is measured from where this touch started.
func _begin_aim(index: int, pos: Vector2) -> void:
	var figure := _player_figure_at(pos, true)
	if figure != null:
		_select(figure)
	elif _selected == null:
		return  # nothing selected yet: tap a figure first
	_state = State.AIMING
	_touch_index = index
	_aim_figure = _selected
	_touch_start = pos
	_update_aim(pos)


func _select(figure: Figure) -> void:
	_deselect()
	_selected = figure
	_selected.selected = true
	ui.show_your_turn("Drag anywhere to flick")


func _deselect() -> void:
	if is_instance_valid(_selected):
		_selected.selected = false
	_selected = null


func _update_aim(pos: Vector2) -> void:
	if _state != State.AIMING:
		return
	var impulse := _flick_impulse(pos)
	if impulse == Vector2.ZERO:
		aim_line.clear()
		return
	# Roughly where the figure will come to rest (ignores bumping into things).
	var speed := impulse.length() / _aim_figure.mass
	var distance := maxf(speed - stop_speed, 0.0) / _aim_figure.linear_damp
	var direction := impulse.normalized()
	aim_line.show_aim(_aim_figure.global_position + direction * _aim_figure.radius, direction, distance)


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
	_deselect()
	_touch_index = -1
	_state = State.SETTLING
	_finish_player_turn()


## Gives up this drag. The figure stays selected, so you can drag again.
func _cancel_aim() -> void:
	aim_line.clear()
	_aim_figure = null
	_touch_index = -1
	if _state == State.AIMING:
		_state = State.PLAYER_TURN


## The flick is opposite the drag, in any direction: drag down = flick up, drag up = flick down.
## Zero means "no flick".
func _flick_impulse(pos: Vector2) -> Vector2:
	var drag := pos - _touch_start
	var max_pull := get_viewport_rect().size.x * max_pull_fraction
	var pull := minf(drag.length(), max_pull)
	if pull < min_pull_distance:
		return Vector2.ZERO
	var full_force := max_flick_force * _aim_figure.data.flick_power_multiplier
	return -drag.normalized() * (pull / max_pull) * full_force


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
	var serial := _turn_serial
	await _wait_until_settled()
	if serial != _turn_serial:
		return
	if _check_game_over():
		return
	await _run_enemy_turn()


## A figure can be knocked off and freed while we wait, so always check before using one.
func _is_alive(figure) -> bool:  # untyped on purpose: a freed Figure can't be passed as a Figure
	return is_instance_valid(figure) and not figure.knocked_off


func _run_enemy_turn() -> void:
	var serial := _turn_serial
	_state = State.ENEMY_TURN
	ui.show_enemy_turn()
	ai.clear_debug()
	for enemy in _enemies.duplicate():
		if not _is_alive(enemy) or not enemy.data.can_flick:
			continue
		await get_tree().physics_frame  # the AI shape-casts in the physics space
		if serial != _turn_serial:
			return
		if not _is_alive(enemy):
			continue
		var impulse := ai.choose_shot(enemy, _players, board.get_table_rect(), max_flick_force)
		await get_tree().create_timer(enemy_think_time).timeout
		if serial != _turn_serial:
			return
		if impulse == Vector2.ZERO or not _is_alive(enemy):
			continue  # nothing good and nothing safe: the enemy passes
		enemy.launch(impulse)
		await _wait_until_settled()
		if serial != _turn_serial:
			return
		if _check_game_over():
			return
	# Creepers (like Big Bad) slide toward your deck at the end of every enemy turn.
	for enemy in _enemies.duplicate():
		if not _is_alive(enemy) or enemy.data.creep_distance <= 0.0:
			continue
		await get_tree().create_timer(enemy_think_time).timeout
		if serial != _turn_serial:
			return
		if not _is_alive(enemy):
			continue
		_creep(enemy)
		await _wait_until_settled()
		if serial != _turn_serial:
			return
		if _check_game_over():
			return
	_start_player_turn()


## Slides the figure straight toward the deck by its creep_distance (same maths as the aim line:
## slide distance = (speed - stop_speed) / damping).
func _creep(enemy: Figure) -> void:
	var speed := enemy.data.creep_distance * enemy.linear_damp + enemy.stop_speed
	enemy.launch(Vector2.DOWN * speed * enemy.mass)


func _has_creeper() -> bool:
	for enemy in _enemies:
		if enemy.data.creep_distance > 0.0:
			return true
	return false


## A creeper has reached the deck line when its front edge touches the top of the deck.
func _deck_line_breached() -> bool:
	var line: float = board.deck_rect.position.y
	for enemy in _enemies:
		if enemy.data.creep_distance > 0.0 and enemy.global_position.y + enemy.radius >= line:
			return true
	return false


## Waits until every figure has stopped. Gives up after max_settle_time and stops them all.
func _wait_until_settled() -> void:
	await get_tree().create_timer(settle_delay).timeout
	var waited := settle_delay
	var next_print := settle_debug_after
	while not _all_figures_resting():
		if waited >= max_settle_time:
			var report := _moving_report()
			push_warning("[settle] forced after %.1fs, still moving: %s" % [waited, report])
			print("[settle] forced after %.1fs, still moving: %s" % [waited, report])
			_force_settle()
			break
		if settle_debug and waited >= settle_debug_after:
			var report := _moving_report()
			ui.show_debug("Waiting %.1fs for: %s" % [waited, report])
			if waited >= next_print:
				print("[settle] waiting %.1fs, still moving: %s" % [waited, report])
				next_print += 1.0
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	ui.show_debug("")


func _force_settle() -> void:
	for figure in _all_figures():
		figure.force_settle()


## "Magnet 12px/s, Roller 40px/s" for the figures that have not settled.
func _moving_report() -> String:
	var parts: PackedStringArray = []
	for figure in _all_figures():
		if not figure.is_resting():
			parts.append(figure.describe_motion())
	return ", ".join(parts)


func _all_figures_resting() -> bool:
	for figure in _all_figures():
		if not figure.is_resting():
			return false
	return true


func _check_game_over() -> bool:
	if _enemies.is_empty():
		_end_game(true)
		return true
	if _players.is_empty() or _deck_line_breached():
		_end_game(false)
		return true
	return false


func _end_game(won: bool) -> void:
	_state = State.GAME_OVER
	if won:
		var run_complete := RunManager.combat_won()
		if not run_complete:
			ui.show_your_turn("Combat cleared!")
			await get_tree().create_timer(reward_delay).timeout
			get_tree().change_scene_to_file(REWARD_SCENE)
			return
	ui.show_result(RunManager.run_over_text(won))
	await get_tree().create_timer(restart_tap_delay).timeout
	_can_restart = true


# --- Figures -----------------------------------------------------------------

func _spawn_players() -> void:
	var deck: Rect2 = board.deck_rect
	var slot_width := deck.size.x / RunManager.deck.size()
	for i in RunManager.deck.size():
		var pos := Vector2(deck.position.x + slot_width * (i + 0.5), deck.get_center().y)
		var figure := _spawn_figure(Figure.Team.PLAYER, RunManager.deck[i], pos)
		figure.deck_position = pos
		_players.append(figure)


func _spawn_enemies() -> void:
	var rect: Rect2 = board.board_rect
	var slot_width := rect.size.x / RunManager.enemies.size()
	for i in RunManager.enemies.size():
		# Stagger every other enemy so they are not in a straight line.
		# Big figures start a bit lower so they don't overlap the arena's top wall.
		var top_margin := maxf(160.0, RunManager.enemies[i].radius + 45.0)
		var pos := Vector2(rect.position.x + slot_width * (i + 0.5), rect.position.y + top_margin + 120.0 * (i % 2))
		_enemies.append(_spawn_figure(Figure.Team.ENEMY, RunManager.enemies[i], pos))


func _spawn_figure(team: Figure.Team, data: FigureData, pos: Vector2) -> Figure:
	var figure: Figure = figure_scene.instantiate()
	figure.setup(data, team, figure_damping, stop_speed, settle_frames)
	figure.flicked.connect(game_feel.on_flicked)
	figure.impacted.connect(game_feel.on_impact)
	figure.fell_off.connect(game_feel.on_fell_off)
	figure.on_deck = team == Figure.Team.PLAYER
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
