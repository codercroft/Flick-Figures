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
## Pause (seconds) after "Bummed out!" before a figure inside a Bummer's aura flicks itself.
@export var takeover_delay := 0.9
## The same enemy can't flick twice in a row (unless it is the only one that can flick).
@export var no_repeat_enemy := true
## Slime and Skull-o-tron fights: the enemy side flicks once per turn for each of its units on the table
## (every slime piece; the core and each Skull Ball), but never more than this many.
@export var max_enemy_flicks := 4

@export_group("Turn")
## Old rule: once every figure has been flicked, the player taps one on the board to reload it
## to the deck. Off (default): all remaining figures simply become flickable again where they
## are. Either way every figure must be flicked before the same one can go again.
@export var reload_enabled := false
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
var _last_player_flicker: Figure
var _bonus_figure: Figure  # Speedo: the figure that may take its extra flick right now
var _enemy_flicks := 1  # flicks the enemy side takes per turn (from RunManager; per-unit bosses: see _enemy_flicks_now)
var _last_flicker: Figure  # the enemy that flicked last (for no_repeat_enemy)
var _enemy_cycle := {}  # enemies that have flicked since the enemy side's flicks last reset (instance ids)
var _aim_figure: Figure
var _selected: Figure  # the figure chosen for aiming (highlighted)
var _turn_serial := 0  # bumped by the watchdog so a stuck turn's coroutines stop
var _busy_time := 0.0  # seconds spent settling or in the enemy turn
var _press_was_empty := false  # the current touch started on empty board (a tap there can place a pin)
var _touch_index := -1
var _touch_start := Vector2.ZERO
var _needs_reload := false  # reload mode only: nothing flickable, tap a board figure to reload it
var _can_restart := false
var _flicker: Figure  # the figure whose flick is in progress (Bloodluster counts the kills it causes)
var _flick_kills := 0  # opposing figures knocked off since that flick started
## Whose turn it is (a Figure.Team), or -1 when nobody's: turrets fire only on the OPPOSING side's turn, and a
## Ghost only wraps on its own side's.
var turret_side := -1

var _top_bar := TopBar.new()

# Relics read these.
## Flicks the player has taken this combat (Opening Act: the first one is boosted).
var player_flicks := 0
## Second Wind: set once it has brought a figure back this combat.
var second_wind_used := false
var _figures_lost := 0  # player figures knocked off for good (Clean Sheet)

# Powers (see "Powers API" below).
## Multiplies the next flick's force (Super Flick sets it to 3; it resets after a flick).
var flick_boost := 1.0
## Extra flicks owed to the player (Extra Turn): taken right after the next flick settles.
var extra_turns := 0
var _power_slot := -1  # the power waiting for a target (-1 = none)
var _power_targets: Array = []
var _snapshot := {}  # every figure as it was before the player's last flick (for Rewind)

@onready var board := $Board
@onready var arena: Arena = $Arena
@onready var figures_root := $Figures
@onready var aim_line := $AimLine
@onready var ui := $UI
@onready var game_feel := $GameFeel
@onready var ai: EnemyAI = $EnemyAI


## Height (px) reserved at the bottom for the turn label, status line and power buttons.
const BOTTOM_UI_HEIGHT := 250.0


func _ready() -> void:
	RunManager.combat = self
	add_child(_top_bar)
	var insets := SafeArea.insets()
	ui.apply_bottom_inset(insets.bottom)
	ui.power_pressed.connect(_on_power_slot_pressed)
	ui.set_powers(RunManager.powers)
	_update_status()
	var boss_wall := RunManager.node != null and RunManager.node.type == MapNode.Type.BOSS \
			and RunManager.boss != null and RunManager.boss.back_wall
	arena.build(RunManager.arena, board.board_rect, boss_wall)
	var banner: Array[String] = []
	if RunManager.encounter_name != "":
		banner.append(RunManager.encounter_name)
	if RunManager.arena != null:
		banner.append(RunManager.arena.display_name)
	if RunManager.penalty_text != "":
		banner.append(RunManager.penalty_text)
	if not banner.is_empty():
		ui.show_banner(banner, Color(1.0, 0.82, 0.25) if RunManager.encounter_name != "" else Color.WHITE)
	_fit_world(TopBar.height(), BOTTOM_UI_HEIGHT + insets.bottom)
	_spawn_players()
	_spawn_enemies()
	_enemy_flicks = maxi(RunManager.enemy_flicks_per_turn, 1)
	board.show_deck_line = _has_creeper()
	_start_player_turn()


func _exit_tree() -> void:
	if RunManager.combat == self:
		RunManager.combat = null


func _physics_process(_delta: float) -> void:
	_knock_off_fallen_figures()


## Watchdog: the turn loop should always finish, but if it ever gets stuck, recover.
func _process(delta: float) -> void:
	ui.set_powers_enabled(_state == State.PLAYER_TURN)
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
	# The run info overlay is open: the game behind it ignores touches.
	if RunInfo.is_open:
		return
	# Taps on the power buttons and the status bar are for them, not for aiming.
	if event is InputEventScreenTouch and event.pressed and (ui.is_over_power_bar(event.position) or _top_bar.is_over(event.position)):
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


## Places the board and deck between the status bar and the bottom controls, centered, and shrinks
## them if the screen is short. Done with the camera, so every position in the game stays the same.
func _fit_world(top_px: float, bottom_px: float) -> void:
	var view := get_viewport_rect().size
	var margin := 24.0
	var board_rect: Rect2 = board.board_rect
	var block := Rect2(board_rect.position.x - margin, board_rect.position.y - margin,
			board_rect.size.x + margin * 2.0, board.deck_rect.end.y - board_rect.position.y + margin * 2.0)
	var available := view.y - top_px - bottom_px
	var zoom := minf(1.0, minf(available / block.size.y, view.x / block.size.x))
	var screen_center := Vector2(view.x / 2.0, top_px + available / 2.0)
	game_feel.camera.zoom = Vector2(zoom, zoom)
	game_feel.camera.position = block.get_center() - screen_center / zoom


func _to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos


func _on_press(index: int, pos: Vector2) -> void:
	match _state:
		State.PLAYER_TURN:
			if _power_slot >= 0:
				_try_power_target(pos)
			elif _needs_reload:
				_try_reload(pos)
			else:
				_begin_aim(index, pos)
		State.GAME_OVER:
			if _can_restart:
				get_tree().change_scene_to_file(NodeScenes.MENU_SCENE)


# --- Player turn: reload, aim, flick -----------------------------------------

## `new_round` is false for an Extra Turn flick: the round (and the powers that last a round)
## doesn't advance.
func _start_player_turn(new_round := true) -> void:
	_cancel_power()
	if new_round:
		for figure in _all_figures():
			if _is_alive(figure):
				figure.tick_round()
		arena.tick_round()
	for figure in _players:
		if _is_alive(figure):
			figure.turn_flicks = 0
			figure.bonus_flicks_used = 0
	_bonus_figure = null
	arena.prune_temp_pins()
	arena.prune_turrets()
	turret_side = Figure.Team.PLAYER
	_state = State.PLAYER_TURN
	_busy_time = 0.0
	_touch_index = -1
	_aim_figure = null
	aim_line.clear()
	_deselect()
	ui.show_debug("")
	_needs_reload = false
	if not _has_flickable_figure():
		if reload_enabled or RunManager.relic_enables_reload():
			_needs_reload = true
		else:
			_make_all_flickable()
	if _needs_reload:
		ui.show_your_turn("Your turn: tap a figure to reload")
	else:
		ui.show_your_turn()


## Everyone has gone: the whole squad can be flicked again from where they stand.
func _make_all_flickable() -> void:
	arena.remove_team_pins(Figure.Team.PLAYER)  # the player side's flick cycle reset: its Pinhead pins go
	for figure in _players:
		if _is_alive(figure):
			figure.flickable = true


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
	var figure := _player_figure_at(pos, true) if _bonus_figure == null else null
	if figure != null:
		_select(figure)
	elif _selected == null:
		return  # nothing selected yet: tap a figure first
	if not _selected.bummer_effect().is_empty():
		_takeover_player_flick(_selected)  # an enemy Bummer's aura: control is taken away
		return
	# A press on ANY of your figures (even one that already went) is not "empty board": it never places or fires.
	_press_was_empty = figure == null and _player_figure_at(pos, false) == null
	_state = State.AIMING
	_touch_index = index
	_aim_figure = _selected
	_touch_start = pos
	_update_aim(pos)


func _select(figure: Figure) -> void:
	if figure == _selected:
		return  # pressing the selected figure again keeps everything (e.g. its Pinhead pin)
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
	var origin := _aim_figure.global_position + direction * _aim_figure.radius
	var bounce := {}
	if RunManager.relic_shows_aim_bounce():
		bounce = _predict_bounce(_aim_figure, _aim_figure.global_position, direction, distance + _aim_figure.radius)
	aim_line.show_aim(origin, direction, distance, bounce)


func _release_aim(pos: Vector2) -> void:
	if _state != State.AIMING:
		return
	var impulse := _flick_impulse(pos)
	if impulse == Vector2.ZERO:
		if _bonus_figure != null:
			_skip_bonus_flick()  # a tap: no extra flick
		else:
			_cancel_aim()
			if _press_was_empty:
				_tap_empty_board(pos)
		return
	aim_line.clear()
	_bonus_figure = null
	var flicked_figure := _aim_figure
	_take_snapshot()
	player_flicks += 1
	flick_boost = 1.0
	_update_status()
	_aim_figure.launch(impulse)
	_aim_figure = null
	_last_player_flicker = flicked_figure
	_deselect()
	_touch_index = -1
	_state = State.SETTLING
	_finish_player_turn()


## A player figure touching an enemy Bummer's aura when you go to flick it: "Bummed out!", then it flicks
## itself with an AI-chosen shot that tries to knock itself off and hit your other figures. It counts as
## that figure's flick (and as a player flick for relics and Rewind).
func _takeover_player_flick(figure: Figure) -> void:
	var serial := _turn_serial
	_state = State.SETTLING  # input is off while it happens
	_touch_index = -1
	_aim_figure = null
	aim_line.clear()
	ui.show_your_turn("Bummed out!")
	figure.show_popup("Bummed out!", Color(0.8, 0.5, 1.0))
	await get_tree().create_timer(takeover_delay).timeout
	if serial != _turn_serial:
		return
	if not _is_alive(figure):
		_start_player_turn()
		return
	await get_tree().physics_frame  # the AI shape-casts in the physics space
	if serial != _turn_serial:
		return
	if not _is_alive(figure):
		_start_player_turn()
		return
	var allies: Array[Figure] = []
	for other in _players:
		if other != figure and _is_alive(other):
			allies.append(other)
	var shot := ai.choose_takeover(figure, allies, board.get_table_rect(), max_flick_force)
	var impulse: Vector2 = shot.impulse if not shot.is_empty() else Vector2.from_angle(randf() * TAU) * figure.mass * 900.0
	_bonus_figure = null
	_take_snapshot()
	player_flicks += 1
	flick_boost = 1.0
	_update_status()
	figure.launch(impulse)
	_last_player_flicker = figure
	_deselect()
	_state = State.SETTLING
	_finish_player_turn()


## Speedo: after its flick settles, the player may flick it again (or tap to skip).
func _offer_bonus_flick(figure: Figure) -> void:
	_bonus_figure = figure
	var bloodlust := _bloodlust_ready(figure)
	if bloodlust:
		figure.bonus_flicks_used += 1
		figure.show_popup("Bloodlust!", Color(1.0, 0.25, 0.3))
	_state = State.PLAYER_TURN
	_busy_time = 0.0
	_touch_index = -1
	_aim_figure = null
	aim_line.clear()
	_select(figure)
	ui.show_your_turn(("Bloodlust! " if bloodlust else "") + "%s: flick again, or tap to skip" % figure.data.display_name)


func _skip_bonus_flick() -> void:
	var figure := _bonus_figure
	_bonus_figure = null
	aim_line.clear()
	_aim_figure = null
	_touch_index = -1
	_deselect()
	_flick_kills = 0  # (a skipped Bloodlust bonus is not offered again)
	if is_instance_valid(figure):
		figure.turn_flicks = figure.ability.get_flicks_per_turn(figure)
	_state = State.SETTLING
	_finish_player_turn()


## True if this figure still has a flick left this turn.
## A bonus flick: a Speedo-style extra flick, or a Bloodluster whose flick just knocked an opposing figure off.
func _bonus_available(figure) -> bool:
	return _has_flick_left(figure) or _bloodlust_ready(figure)


func _bloodlust_ready(figure) -> bool:
	if not _is_alive(figure) or not figure.data.can_flick or figure != _flicker:
		return false
	var cap: int = figure.ability.get_bloodlust_cap(figure)
	return cap > 0 and _flick_kills > 0 and figure.bonus_flicks_used < cap


func _has_flick_left(figure) -> bool:
	return _is_alive(figure) and figure.data.can_flick \
			and figure.turn_flicks < figure.ability.get_flicks_per_turn(figure)


## Gives up this drag. The figure stays selected, so you can drag again.
## Alchemist placed its zone: that was its whole action. It counts as its flick for the cycle (greyed out), but
## it does not flick, and the player's turn ends (the enemy goes next).
func _use_up_turn_placing(figure: Figure, text := "Zone placed!") -> void:
	_take_snapshot()
	figure.flickable = false
	figure.turn_flicks = figure.ability.get_flicks_per_turn(figure)
	figure.show_popup(text, Color(0.75, 0.85, 0.95))
	_last_player_flicker = figure
	_bonus_figure = null
	_cancel_aim()
	_deselect()
	_state = State.SETTLING
	_finish_player_turn()


## Blastoid fires at the tapped spot instead of moving. Like a flick, that is its action for the cycle.
func _fire_shot(figure: Figure, pos: Vector2) -> void:
	_take_snapshot()
	player_flicks += 1
	flick_boost = 1.0
	_update_status()
	figure.shoot_at(pos)
	_on_any_flick(figure, Vector2.ZERO)
	_last_player_flicker = figure
	_bonus_figure = null
	_deselect()
	_state = State.SETTLING
	_finish_player_turn()


## A tap on empty board with a figure selected: Pinhead places (or takes back) its temporary pin.
func _tap_empty_board(pos: Vector2) -> void:
	if not _is_alive(_selected) or not _selected.flickable:
		return
	var turret := _selected.ability.get_turret_stats(_selected)
	if not turret.is_empty():  # Engineer
		match arena.toggle_turret(_selected, pos, turret, board.board_rect):
			"placed":
				ui.show_your_turn("Turret placed. Drag anywhere to flick")
			"removed":
				ui.show_your_turn("Turret removed. Drag anywhere to flick")
			_:
				ui.show_your_turn("Can't place a turret there")
		return
	if not _selected.ability.get_shot_stats(_selected).is_empty():  # Blastoid: tap = fire at that spot
		_fire_shot(_selected, pos)
		return
	var zone := _selected.ability.get_zone_stats(_selected)
	if not zone.is_empty():  # Alchemist: placing the zone is its whole action
		if arena.place_zone(_selected, pos, zone, board.board_rect):
			_use_up_turn_placing(_selected, "Zone placed!")
		else:
			ui.show_your_turn("Can't place a zone there")
		return
	var radius := _selected.ability.get_pin_radius(_selected)  # Pinhead: placing the pin does NOT use its flick
	if radius <= 0.0:
		return
	match arena.toggle_temp_pin(_selected, pos, radius, board.board_rect):
		"placed":
			ui.show_your_turn("Pin placed. Drag anywhere to flick")
		"removed":
			ui.show_your_turn("Pin removed. Drag anywhere to flick")
		_:
			ui.show_your_turn("Can't place a pin there")


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
	var full_force := max_flick_force * _aim_figure.data.flick_power_multiplier * flick_boost \
			* _aim_figure.ability.get_flick_power_multiplier(_aim_figure) * _aim_figure.aura_flick_multiplier() \
			* RunManager.relic_flick_multiplier(self, _aim_figure)
	return -drag.normalized() * (pull / max_pull) * full_force


func _player_figure_at(pos: Vector2, flickable: bool) -> Figure:
	var best: Figure = null
	var best_distance := INF
	for figure in _players:
		var distance := figure.global_position.distance_to(pos)
		if figure.flickable == flickable and distance <= figure.radius + grab_padding and distance < best_distance:
			best = figure
			best_distance = distance
	return best


func _has_flickable_figure() -> bool:
	for figure in _players:
		if figure.flickable:
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
	if _bonus_available(_last_player_flicker) and _last_player_flicker.team == Figure.Team.PLAYER:
		_offer_bonus_flick(_last_player_flicker)
		return
	if extra_turns > 0:
		extra_turns -= 1
		_update_status()
		_start_player_turn(false)
		return
	await _run_enemy_turn()


## A figure can be knocked off and freed while we wait, so always check before using one.
func _is_alive(figure) -> bool:  # untyped on purpose: a freed Figure can't be passed as a Figure
	return is_instance_valid(figure) and not figure.knocked_off


func _run_enemy_turn() -> void:
	var serial := _turn_serial
	_state = State.ENEMY_TURN
	turret_side = Figure.Team.ENEMY
	ui.show_enemy_turn()
	ai.clear_debug()
	for enemy in _enemies:
		if _is_alive(enemy):
			enemy.turn_flicks = 0
			enemy.bonus_flicks_used = 0
	await get_tree().physics_frame  # turret spots are checked in the physics space
	if serial != _turn_serial:
		return
	_place_enemy_turrets()
	# The enemy side takes _enemy_flicks flicks. Each one is the best shot of ANY enemy figure.
	# The total is read every round: in the per-unit boss fights it changes as pieces appear or fall off.
	var flicks_taken := 0
	while flicks_taken < _enemy_flicks_now():
		flicks_taken += 1
		var total := _enemy_flicks_now()
		if total > 1:
			ui.show_enemy_turn("Enemy flicks: %d/%d" % [flicks_taken, total])
		_refresh_enemy_cycle()
		await get_tree().physics_frame  # the AI shape-casts in the physics space
		if serial != _turn_serial:
			return
		var choice := ai.choose_flick(_flick_candidates(), _players, board.get_table_rect(), max_flick_force)
		await get_tree().create_timer(enemy_think_time).timeout
		if serial != _turn_serial:
			return
		if choice.is_empty() or not _is_alive(choice.enemy):
			break  # nothing good and nothing safe: the enemy side passes
		_last_flicker = choice.enemy
		_enemy_cycle[choice.enemy.get_instance_id()] = true
		choice = await _takeover_choice(choice, serial)  # a Bummer's aura replaces the shot
		if serial != _turn_serial or not _is_alive(choice.enemy):
			return
		if choice.has("zone_only"):
			# An enemy Alchemist's whole action is placing its debuff zone.
			arena.place_zone(choice.enemy, choice.zone, choice.zone_stats, board.board_rect)
			choice.enemy.show_popup("Zone!", Color(0.8, 0.6, 1.0))
			choice.enemy.turn_flicks = choice.enemy.ability.get_flicks_per_turn(choice.enemy)
			await _wait_until_settled()
			if serial != _turn_serial:
				return
			continue
		if choice.has("pin_only"):
			# An enemy Pinhead's whole action is placing a pin (for an ally's bank shot): no flick this time.
			arena.place_temp_pin(choice.enemy, choice.pin, choice.pin_radius, board.board_rect)
			choice.enemy.show_popup("Pin!", Color(0.75, 0.85, 0.95))
			choice.enemy.turn_flicks = choice.enemy.ability.get_flicks_per_turn(choice.enemy)
			await _wait_until_settled()
			if serial != _turn_serial:
				return
			continue
		if choice.has("shot_point"):  # an enemy Blastoid fires instead of moving
			choice.enemy.shoot_at(choice.shot_point)
			_on_any_flick(choice.enemy, Vector2.ZERO)
		else:
			choice.enemy.launch(choice.impulse)
		await _wait_until_settled()
		if serial != _turn_serial:
			return
		if _check_game_over():
			return
		# Speedo-style extra flicks: only taken when the shot scores well.
		var shooter = choice.enemy  # untyped on purpose: it may have split or fallen off and been freed
		while _bonus_available(shooter):
			await get_tree().physics_frame
			if serial != _turn_serial:
				return
			if not _is_alive(shooter):
				break
			var bloodlust := _bloodlust_ready(shooter)
			var extra := ai.choose_flick([shooter], _players, board.get_table_rect(), max_flick_force, ai.bonus_flick_min_score)
			await get_tree().create_timer(enemy_think_time).timeout
			if serial != _turn_serial:
				return
			if extra.is_empty() or extra.has("pin_only") or extra.has("zone_only") or extra.has("shot_point") or not _is_alive(shooter):
				break
			if bloodlust:
				shooter.bonus_flicks_used += 1
				shooter.show_popup("Bloodlust!", Color(1.0, 0.25, 0.3))
			extra = await _takeover_choice(extra, serial)
			if serial != _turn_serial:
				return
			if not _is_alive(shooter):
				break
			shooter.launch(extra.impulse)
			await _wait_until_settled()
			if serial != _turn_serial:
				return
			if _check_game_over():
				return
	# Creepers (like The Wall's pieces) all slide toward your deck TOGETHER at the end of every
	# enemy turn, each by the same distance from wherever it is now.
	var creepers: Array[Figure] = []
	for enemy in _enemies:
		if _is_alive(enemy) and enemy.data.creep_distance > 0.0 and not enemy.is_frozen():
			creepers.append(enemy)
	if not creepers.is_empty():
		await get_tree().create_timer(enemy_think_time).timeout
		if serial != _turn_serial:
			return
		for enemy in creepers:
			if _is_alive(enemy):
				_creep(enemy)
		await _wait_until_settled()
		if serial != _turn_serial:
			return
		if _check_game_over():
			return
	_start_player_turn()


## How many flicks the enemy side takes this turn: the fight's fixed number, or (Slime, Skull-o-tron) one per
## enemy unit currently on the table, capped at `max_enemy_flicks`.
func _enemy_flicks_now() -> int:
	if not RunManager.enemy_flick_per_unit:
		return _enemy_flicks
	var units := 0
	for enemy in _enemies:
		if _is_alive(enemy):
			units += 1
	return clampi(units, 1, max_enemy_flicks)


## An enemy figure touching a player Bummer's aura is taken over when the AI goes to flick it: "Bummed out!",
## then a shot that tries to knock itself off and hit its own teammates replaces the planned one.
func _takeover_choice(choice: Dictionary, serial: int) -> Dictionary:
	var enemy = choice.enemy  # untyped: it may fall off and be freed while we wait
	if choice.has("pin_only") or choice.has("zone_only") or not _is_alive(enemy) or enemy.bummer_effect().is_empty():
		return choice
	enemy.show_popup("Bummed out!", Color(0.8, 0.5, 1.0))
	await get_tree().create_timer(takeover_delay).timeout
	if serial != _turn_serial or not _is_alive(enemy):
		return choice
	var allies: Array[Figure] = []
	for other in _enemies:
		if other != enemy and _is_alive(other):
			allies.append(other)
	var shot := ai.choose_takeover(enemy, allies, board.get_table_rect(), max_flick_force)
	if shot.is_empty():
		return choice
	return {"enemy": enemy, "impulse": shot.impulse}


## Enemy Engineers put their turret where it covers the player's flick lanes (before the flicks).
func _place_enemy_turrets() -> void:
	for enemy in _enemies:
		if not _is_alive(enemy):
			continue
		var stats := enemy.ability.get_turret_stats(enemy)
		if stats.is_empty():
			continue
		var spot := ai.choose_turret_spot(enemy, _players, _enemies, stats, arena, board.board_rect, board.get_table_rect())
		if spot != Vector2.INF:
			arena.place_turret(enemy, spot, stats, board.board_rect)


## When every enemy that can flick has flicked, the enemy side's cycle resets (they could all flick again):
## their Pinhead pins go away. (The player side does the same in _make_all_flickable.)
func _refresh_enemy_cycle() -> void:
	arena.prune_temp_pins()
	for enemy in _enemies:
		if _is_alive(enemy) and enemy.data.can_flick and not enemy.is_frozen() \
				and not _enemy_cycle.has(enemy.get_instance_id()):
			return
	_enemy_cycle.clear()
	arena.remove_team_pins(Figure.Team.ENEMY)


## The enemies allowed to flick right now: alive, able to flick, and not the one that flicked
## last (unless it is the only one).
func _flick_candidates() -> Array:
	var able: Array = []
	for enemy in _enemies:
		if _is_alive(enemy) and enemy.data.can_flick and not enemy.is_frozen():
			able.append(enemy)
	if no_repeat_enemy and able.size() > 1 and _is_alive(_last_flicker):
		able.erase(_last_flicker)
	return able


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


## "Magnet 12px/s, Pusher 40px/s" for the figures that have not settled.
func _moving_report() -> String:
	var parts: PackedStringArray = []
	for figure in _all_figures():
		if not figure.is_resting():
			parts.append(figure.describe_motion())
	return ", ".join(parts)


func _all_figures_resting() -> bool:
	if not get_tree().get_nodes_in_group("projectiles").is_empty():
		return false  # a Blastoid shot is still flying
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
	turret_side = -1
	if won:
		AudioManager.play_fanfare()
		# Money for every win (elites and bosses pay a bonus on top: see RewardConfig).
		var on_table: Array[FigureData] = []
		var equipment_bonus := 0
		for figure in _players:
			if figure.data.pays_income:
				on_table.append(figure.data)
			if figure.equipment != null:
				equipment_bonus += figure.equipment.income_bonus
		RunManager.award_income(on_table, equipment_bonus)
		RunManager.notify_combat_won({"figures_lost": _figures_lost})
		var income: int = RunManager.last_income.total
		var run_complete := RunManager.combat_won()
		if not run_complete:
			ui.show_your_turn("Combat cleared! +$%d" % income)
			await get_tree().create_timer(reward_delay).timeout
			get_tree().change_scene_to_file(REWARD_SCENE)
			return
	RunManager.end_run(won)  # the run is over: it goes into the history and its save is deleted
	ui.show_result(RunManager.run_over_text(won))
	await get_tree().create_timer(restart_tap_delay).timeout
	_can_restart = true


# --- Figures -----------------------------------------------------------------

func _spawn_players() -> void:
	var deck: Rect2 = board.deck_rect
	var slot_width := deck.size.x / RunManager.deck.size()
	for i in RunManager.deck.size():
		var pos := Vector2(deck.position.x + slot_width * (i + 0.5), deck.get_center().y)
		var figure := _spawn_figure(Figure.Team.PLAYER, RunManager.deck[i], pos, RunManager.deck_equipment[i],
				RunManager.deck_finish[i], RunManager.deck_upgrade[i])
		figure.deck_position = pos
		_players.append(figure)


func _spawn_enemies() -> void:
	var rect: Rect2 = board.board_rect
	var slot_width := rect.size.x / RunManager.enemies.size()
	for i in RunManager.enemies.size():
		# Stagger every other enemy so they are not in a straight line.
		# Big figures start a bit lower so they don't overlap the arena's top wall.
		var top_margin := maxf(160.0, RunManager.enemies[i].radius + 45.0)
		if RunManager.enemies[i].spawn_margin > 0.0:
			top_margin = RunManager.enemies[i].spawn_margin
		var stagger := 0.0 if RunManager.enemies_in_row else 120.0 * (i % 2)
		var pos := Vector2(rect.position.x + slot_width * (i + 0.5), rect.position.y + top_margin + stagger)
		if i < RunManager.enemy_positions.size() and RunManager.enemy_positions[i] != Vector2.INF:
			pos = rect.position + RunManager.enemy_positions[i]  # a hand-made encounter's spot
		var gear: Dictionary = RunManager.enemy_gear[i]
		_enemies.append(_spawn_figure(Figure.Team.ENEMY, RunManager.enemies[i], pos, gear.equipment, gear.finish,
				gear.upgrade, RunManager.enemy_scale(i), RunManager.enemy_elite[i]))


func _spawn_figure(team: Figure.Team, data: FigureData, pos: Vector2, item: EquipmentData = null,
		finish: FinishData = null, upgrade: UpgradeData = null, scale := {}, elite := false) -> Figure:
	var figure: Figure = figure_scene.instantiate()
	var damping := figure_damping * (RunManager.relic_player_damping() if team == Figure.Team.PLAYER else 1.0)
	figure.setup(data, team, damping, stop_speed, settle_frames, item, finish, upgrade, scale, elite)
	figure.flicked.connect(game_feel.on_flicked)
	figure.flicked.connect(_on_any_flick)
	figure.impacted.connect(game_feel.on_impact)
	figure.fell_off.connect(game_feel.on_fell_off)
	figure.split_requested.connect(_on_split_requested)
	figure.shed_requested.connect(_on_shed_requested)
	figure.on_deck = team == Figure.Team.PLAYER
	figure.position = pos
	figures_root.add_child(figure)
	return figure


## A figure sheds pieces but stays (Skull-o-tron loses an arm): the pieces join its team as new figures.
func _on_shed_requested(parent: Figure, pieces: Array, grants_flicks: bool) -> void:
	if not _is_alive(parent):
		return
	for piece in pieces:
		var spawned := _spawn_figure(parent.team, piece.data, piece.position, null, null, null, parent.scale_factors)
		spawned.apply_central_impulse(piece.velocity * spawned.mass)
		if parent.team == Figure.Team.ENEMY:
			_enemies.append(spawned)
		else:
			spawned.on_deck = false
			spawned.flickable = false
			spawned.deck_position = parent.deck_position
			_players.append(spawned)


## A figure (a Slime) splits: spawn its pieces on its team, then remove it. The pieces are new
## enemies, so they take their own turns from the next enemy turn on.
func _on_split_requested(parent: Figure, pieces: Array, grants_flicks: bool) -> void:
	if not _is_alive(parent):
		return
	for piece in pieces:
		var spawned := _spawn_figure(parent.team, piece.data, piece.position, null, null, null, parent.scale_factors)
		spawned.apply_central_impulse(piece.velocity * spawned.mass)
		if parent.team == Figure.Team.ENEMY:
			_enemies.append(spawned)
		else:
			# Born out on the board: not on deck, but fresh and unflicked: it can be flicked this same round.
			spawned.on_deck = false
			spawned.flickable = true
			spawned.deck_position = parent.deck_position
			_players.append(spawned)
	_players.erase(parent)
	_enemies.erase(parent)
	parent.knock_off(knock_off_fade_time, true)


func _all_figures() -> Array[Figure]:
	var all: Array[Figure] = []
	all.append_array(_players)
	all.append_array(_enemies)
	return all


func _knock_off_fallen_figures() -> void:
	var table: Rect2 = board.get_table_rect()
	var fallen_enemies: Array[Figure] = []
	for figure in _all_figures():
		if not table.has_point(figure.global_position):
			if figure.bubble_rounds > 0:
				_stop_at_edge(figure, table)  # Bubble Shield
				continue
			if figure.ability.on_left_table(figure, table):
				continue  # saved (e.g. Ghost wrapped around)
			if figure.team == Figure.Team.PLAYER and RunManager.relic_saves_figure(self, figure):
				continue  # saved by a relic (Second Wind)
			if figure.team == Figure.Team.PLAYER:
				_figures_lost += 1
			_count_kill(figure)
			_players.erase(figure)
			_enemies.erase(figure)
			figure.knock_off(knock_off_fade_time)
			if figure.team == Figure.Team.ENEMY:
				fallen_enemies.append(figure)
	# Cha-ching and friends: your surviving figures react to each enemy that fell.
	for victim in fallen_enemies:
		for player in _players:
			if _is_alive(player):
				player.ability.on_opponent_knocked_off(player, victim)


## A flick started (any figure): Bloodluster counts the opposing figures knocked off from now on.
func _on_any_flick(figure: Figure, _impulse: Vector2) -> void:
	_flicker = figure
	_flick_kills = 0


func _count_kill(fallen: Figure) -> void:
	if is_instance_valid(_flicker) and fallen.team != _flicker.team:
		_flick_kills += 1


## Eater: removes a figure outright, with the same bookkeeping as falling off the table (it counts as knocked off).
func force_knock_off(figure: Figure) -> void:
	if not _is_alive(figure):
		return
	if figure.team == Figure.Team.PLAYER:
		_figures_lost += 1
	_count_kill(figure)
	_players.erase(figure)
	_enemies.erase(figure)
	figure.knock_off(knock_off_fade_time)
	if figure.team == Figure.Team.ENEMY:
		for player in _players:
			if _is_alive(player):
				player.ability.on_opponent_knocked_off(player, figure)


## Energizer: the figure can be flicked again this cycle.
func recharge_figure(figure: Figure) -> void:
	if not _is_alive(figure):
		return
	figure.turn_flicks = 0
	if figure.team == Figure.Team.PLAYER:
		figure.flickable = true
	else:
		_enemy_cycle.erase(figure.get_instance_id())


## Bubble Shield: the figure stops right at the table edge instead of falling off.
func _stop_at_edge(figure: Figure, table: Rect2) -> void:
	var inner := table.grow(-figure.radius)
	var pos := figure.global_position
	figure.global_position = Vector2(clampf(pos.x, inner.position.x, inner.end.x), clampf(pos.y, inner.position.y, inner.end.y))
	figure.linear_velocity = Vector2.ZERO


# --- Powers API --------------------------------------------------------------
# Powers (PowerData + PowerEffect) are used on the player's turn and don't use up the flick.
# Effects call these functions on the Main node.

## Every figure still in the game.
func get_all_figures() -> Array[Figure]:
	var alive: Array[Figure] = []
	for figure in _all_figures():
		if _is_alive(figure):
			alive.append(figure)
	return alive


## A short message in the turn label (until the next one replaces it).
func notice(text: String) -> void:
	ui.show_your_turn(text)


## Explosion at a point (Bomb Drop).
func explode_at(point: Vector2, radius: float, force: float) -> void:
	radius *= RunManager.relic_explosion_multiplier()  # Blast Cap
	var picture := BlastEffect.new()
	picture.position = point
	add_child(picture)
	picture.start(radius)
	Figure.blast(get_tree(), point, radius, force)


## Swaps two figures' positions (Swap).
func swap_figures(a: Figure, b: Figure) -> void:
	var pos_a := a.global_position
	a.global_position = b.global_position
	b.global_position = pos_a
	for figure in [a, b]:
		figure.linear_velocity = Vector2.ZERO
		if figure.team == Figure.Team.PLAYER:
			figure.on_deck = board.deck_rect.has_point(figure.global_position)


func can_rewind() -> bool:
	return not _snapshot.is_empty()


## Remembers every figure before the player's flick (called right before each flick).
func _take_snapshot() -> void:
	var list: Array[Dictionary] = []
	for figure in get_all_figures():
		list.append({
			"data": figure.base_data, "team": figure.team, "position": figure.global_position,
			"on_deck": figure.on_deck, "flickable": figure.flickable, "turn_flicks": figure.turn_flicks,
			"deck_position": figure.deck_position, "radius": figure.radius, "mass": figure.mass,
			"shrunk": figure.shrunk, "frozen": figure.frozen_rounds, "bubble": figure.bubble_rounds,
			"equipment": figure.equipment, "finish": figure.finish, "upgrade": figure.upgrade,
			"scale": figure.scale_factors, "elite": figure.elite,
		})
	_snapshot = {"player_flicks": player_flicks, "figures": list, "boost": flick_boost, "extra": extra_turns, "enemy_flicks": _enemy_flicks}


## Rewind: replaces every figure with a fresh copy from before the last flick (so knocked-off
## figures come back). Per-figure ability state starts over.
func rewind() -> bool:
	if _snapshot.is_empty():
		return false
	_deselect()
	_selected = null
	_aim_figure = null
	for child in figures_root.get_children():
		if child is Figure:
			child.remove_from_group("figures")
			child.knocked_off = true
			child.collision_layer = 0
			child.collision_mask = 0
		child.hide()
		child.queue_free()
	_players.clear()
	_enemies.clear()
	for entry in _snapshot.figures:
		var figure := _spawn_figure(entry.team, entry.data, entry.position, entry.equipment, entry.finish, entry.upgrade,
				entry.scale, entry.elite)
		figure.set_size(entry.radius, entry.mass)
		figure.shrunk = entry.shrunk
		figure.deck_position = entry.deck_position
		figure.turn_flicks = entry.turn_flicks
		if entry.team == Figure.Team.PLAYER:
			figure.on_deck = entry.on_deck
			figure.flickable = entry.flickable
			_players.append(figure)
		else:
			_enemies.append(figure)
		if entry.frozen > 0:
			figure.freeze_for(entry.frozen)
		if entry.bubble > 0:
			figure.set_bubble(entry.bubble)
	player_flicks = _snapshot.player_flicks
	flick_boost = _snapshot.boost
	extra_turns = _snapshot.extra
	_enemy_flicks = _snapshot.enemy_flicks
	_last_flicker = null
	_last_player_flicker = null
	_bonus_figure = null
	for figure in _players:
		if figure.turn_flicks > 0 and _has_flick_left(figure):
			_bonus_figure = figure  # it was Speedo's extra flick: offer it again
	_snapshot = {}
	_update_status()
	return true


func _on_power_slot_pressed(slot: int) -> void:
	if _state != State.PLAYER_TURN:
		return
	if slot == _power_slot:
		_cancel_power()
		_resume_player_turn()
		return
	var power: PowerData = RunManager.powers[slot] if slot < RunManager.powers.size() else null
	if power == null or power.effect == null:
		return
	_cancel_power()
	var reason := power.effect.can_use(self)
	if reason != "":
		notice(reason)
		return
	if power.effect.target_mode == PowerEffect.Target.NONE:
		_activate_power(slot, [])
		return
	_power_slot = slot
	ui.set_powers(RunManager.powers, slot)
	notice(power.effect.prompt if power.effect.prompt != "" else "Tap a target")


## Gives up choosing a target (the power is not used up).
func _cancel_power() -> void:
	for target in _power_targets:
		if target is Figure and is_instance_valid(target):
			target.selected = false
	_power_targets.clear()
	if _power_slot >= 0:
		_power_slot = -1
		ui.set_powers(RunManager.powers)


## A tap while a power waits for its target.
func _try_power_target(pos: Vector2) -> void:
	var effect: PowerEffect = RunManager.powers[_power_slot].effect
	match effect.target_mode:
		PowerEffect.Target.ENEMY:
			var enemy := _figure_at(pos, Figure.Team.ENEMY)
			if enemy != null:
				_activate_power(_power_slot, [enemy])
		PowerEffect.Target.OWN_FIGURE:
			var own := _figure_at(pos, Figure.Team.PLAYER)
			if own != null:
				_activate_power(_power_slot, [own])
		PowerEffect.Target.TWO_FIGURES:
			var figure := _figure_at(pos, -1)
			if figure == null or _power_targets.has(figure):
				return
			_power_targets.append(figure)
			figure.selected = true
			if _power_targets.size() == 2:
				_activate_power(_power_slot, _power_targets.duplicate())
			else:
				notice("Tap the second figure")
		PowerEffect.Target.POINT:
			if board.board_rect.has_point(pos):
				_activate_power(_power_slot, [pos])


## The figure nearest to a tap (of one team, or -1 for either), or null.
func _figure_at(pos: Vector2, team: int) -> Figure:
	var best: Figure = null
	var best_distance := INF
	for figure in get_all_figures():
		if team != -1 and figure.team != team:
			continue
		var distance := figure.global_position.distance_to(pos)
		if distance <= figure.radius + grab_padding and distance < best_distance:
			best = figure
			best_distance = distance
	return best


func _activate_power(slot: int, targets: Array) -> void:
	var serial := _turn_serial
	var power: PowerData = RunManager.powers[slot]
	_cancel_power()
	if not power.effect.apply(self, targets):
		return  # it could not be done: the power is kept
	RunManager.use_power(slot)
	ui.set_powers(RunManager.powers)
	_update_status()
	if power.effect.settle_after:
		_state = State.SETTLING
		_busy_time = 0.0
		await _wait_until_settled()
		if serial != _turn_serial:
			return
		if _check_game_over():
			return
	_resume_player_turn()


## Back to waiting for the player after a power (without starting a new turn).
func _resume_player_turn() -> void:
	_state = State.PLAYER_TURN
	_busy_time = 0.0
	if not _is_alive(_selected):
		_selected = null
	if _bonus_figure != null and _is_alive(_bonus_figure):
		_select(_bonus_figure)
		ui.show_your_turn("%s: flick again, or tap to skip" % _bonus_figure.data.display_name)
	elif _needs_reload:
		ui.show_your_turn("Your turn: tap a figure to reload")
	else:
		ui.show_your_turn()


## The small line under the turn label: which combat, plus any power waiting to take effect.
func _update_status() -> void:
	var text := RunManager.progress_text()
	if flick_boost > 1.0:
		text += "  |  Super Flick ready"
	if extra_turns > 0:
		text += "  |  Extra flick x%d" % extra_turns
	ui.show_progress(text)


## Relics read these.
func get_player_count() -> int:
	return _players.size()


func get_enemy_count() -> int:
	return _enemies.size()


## Aim Assist: where the shot from `start` along `direction` (up to `distance`) first hits something,
## and where it bounces to. Returns {} if it hits nothing, else {point, direction, length}.
func _predict_bounce(figure: Figure, start: Vector2, direction: Vector2, distance: float) -> Dictionary:
	var space := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = figure.radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, start)
	query.motion = direction * distance
	query.collision_mask = Figure.LAYER_FLICKED | Figure.LAYER_ENEMY | Figure.LAYER_ARENA
	query.exclude = [figure.get_rid()]
	var fractions := space.cast_motion(query)
	if fractions.size() < 2 or fractions[1] >= 1.0:
		return {}
	var contact := start + direction * distance * fractions[1]
	query.transform = Transform2D(0.0, contact)
	query.motion = Vector2.ZERO
	var rest := space.get_rest_info(query)
	if rest.is_empty():
		return {}
	var normal: Vector2 = rest.normal
	if normal.dot(direction) > 0.0:
		normal = -normal
	var travelled := distance * fractions[1]
	return {"point": contact, "direction": direction.bounce(normal), "length": (distance - travelled) * 0.6,
			"travelled": travelled}
