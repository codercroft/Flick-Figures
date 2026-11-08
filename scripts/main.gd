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
## Spitter: hold still this long (seconds, within min_pull_distance) to start spraying instead of flicking.
@export var spray_hold_seconds := 0.25
## Enemy Spitter: how long its AI sprays (seconds, at most its water).
@export var enemy_spray_seconds := 1.6
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
var _lingering_cover := {}  # team -> {reduction, rounds}
var _bonus_queue: Array = []  # player figures that get a flick right after the current one settles
var _press_on_selected := false  # the current press landed on the figure that was already selected
var _hold_pending := false  # Spitter: this touch may turn into a spray if it is held still
var _hold_time := 0.0
var _spraying := false
var _last_touch := Vector2.ZERO
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
## Turrets (Engineer) fire during BOTH sides' turns, but only while a turn's movement is in progress: between a
## flick and the moment the board settles, and only while some figure that was not merely nudged by a pellet is still
## moving (`turret_may_fire`, updated every physics frame). Pellets in flight never hold up the settle check.
var turret_may_fire := false
var _settling := false

var _top_bar := TopBar.new()

# Relics read these.
## Flicks the player has taken this combat (Opening Act: the first one is boosted).
var player_flicks := 0
## Second Wind: set once it has brought a figure back this combat.
var second_wind_used := false
var enemy_flicks_made := 0  # enemy flicks this combat (the Opening Act enemy relic doubles the first)
var _enemy_turns_taken := 0  # enemy turns started this combat (relics act on the first)
var _figures_lost := 0  # player figures knocked off for good (Clean Sheet)

# Powers (see "Powers API" below).
## Multiplies the next flick's force (Super Flick sets it to 3; it resets after a flick).
var flick_boost := 1.0
## Extra flicks owed to the player (Extra Turn): taken right after the next flick settles.
var extra_turns := 0
var _power_slot := -1  # the power waiting for a target (-1 = none)
var _power_targets: Array = []
var _snapshot := {}  # every figure as it was before the player's last flick (for Rewind)

var _creator_box: CreatorBox  # the Mad Creator's box (only in that boss fight)

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
	RunInfo.powers_changed.connect(_on_powers_discarded)
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
	if not RunManager.enemy_relics.is_empty():
		var relic_names: Array[String] = []
		for relic in RunManager.enemy_relics:
			relic_names.append("%s: %s" % [relic.display_name, relic.description])
		banner.append("Enemy relic - " + ", ".join(relic_names))
		ui.show_enemy_relics("Enemy relic: " + ", ".join(RunManager.enemy_relics.map(func(r): return r.display_name)), TopBar.height() + 8.0)
	if not banner.is_empty():
		ui.show_banner(banner, Color(1.0, 0.82, 0.25) if RunManager.encounter_name != "" else Color.WHITE)
	_fit_world(TopBar.height(), BOTTOM_UI_HEIGHT + insets.bottom)
	_spawn_players()
	_spawn_enemies()
	if RunManager.node != null and RunManager.node.type == MapNode.Type.BOSS and RunManager.boss != null \
			and RunManager.boss.creator_box and not _enemies.is_empty():
		_creator_box = CreatorBox.new()
		arena.add_child(_creator_box)
		_creator_box.build(board.board_rect, RunManager.boss, _enemies[0])
	_enemy_flicks = maxi(RunManager.enemy_flicks_per_turn, 1)
	board.show_deck_line = _has_creeper()
	_start_player_turn()
	_place_opening_turrets()


## Enemy Engineers (Siege) have their turret up from the very start of the combat, before the player's first flick.
func _place_opening_turrets() -> void:
	await get_tree().physics_frame  # the spots are checked in the physics space
	if not is_inside_tree() or _state == State.GAME_OVER:
		return
	_place_enemy_turrets()


func _exit_tree() -> void:
	if RunInfo.powers_changed.is_connected(_on_powers_discarded):
		RunInfo.powers_changed.disconnect(_on_powers_discarded)
	if RunManager.combat == self:
		RunManager.combat = null


func _physics_process(_delta: float) -> void:
	_knock_off_fallen_figures()
	_update_blast_shields()
	turret_may_fire = _settling and _state != State.GAME_OVER and _real_motion()


## Figures of a team with a Firecracker on the table get the faint "explosion shield" ring.
func _update_blast_shields() -> void:
	var player_shield := Figure.team_has_firecracker(get_tree(), Figure.Team.PLAYER)
	var enemy_shield := Figure.team_has_firecracker(get_tree(), Figure.Team.ENEMY)
	for figure in _all_figures():
		if _is_alive(figure):
			figure.blast_shield = player_shield if figure.team == Figure.Team.PLAYER else enemy_shield


## Watchdog: the turn loop should always finish, but if it ever gets stuck, recover.
func _process(delta: float) -> void:
	ui.set_powers_enabled(_state == State.PLAYER_TURN)
	if _hold_pending and _state == State.AIMING:
		_hold_time += delta
		if _hold_time >= spray_hold_seconds:
			_start_spray()
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
	_end_turn_for_all()  # (the enemy's turn is over)
	_clear_temp_buffs(Figure.Team.PLAYER)
	arena.remove_starter_walls()  # Starter Walls: they only last through the enemy turn
	_cancel_power()
	if new_round:
		for figure in _all_figures():
			if _is_alive(figure):
				figure.tick_round()
		arena.tick_round()
		for team in _lingering_cover.keys():
			_lingering_cover[team].rounds -= 1
			if _lingering_cover[team].rounds <= 0:
				_lingering_cover.erase(team)
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
	_hold_pending = false
	_spraying = false
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
			figure.flickable = figure.stunned_rounds == 0
			figure.ability.on_became_flickable(figure)


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
	var previous := _selected
	var figure := _player_figure_at(pos, true) if _bonus_figure == null else null
	if figure == null and _bonus_figure == null:
		# A figure that already went can still be selected for a "tap again" ability (Magnet's push, Absorber's spit).
		var tapped := _any_player_figure_at(pos)
		if tapped != null and _tap_ability_ready(tapped, "self"):
			figure = tapped
	_press_on_selected = figure != null and figure == previous
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
	_spraying = false
	_hold_time = 0.0
	var spray := _selected.ability.get_spray_stats(_selected)
	_hold_pending = not spray.is_empty() and spray.water > 0.0 and _selected.flickable and _bonus_figure == null
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
	_last_touch = pos
	if not _aim_figure.flickable:
		return
	if _spraying:  # Spitter: the stream follows the finger
		_aim_figure.ability.set_spray(_aim_figure, true, pos)
		return
	if _hold_pending and (pos - _touch_start).length() >= min_pull_distance:
		_hold_pending = false  # moved: it is a flick drag
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
	_hold_pending = false
	if _spraying:
		_end_spray()
		return
	var impulse := _flick_impulse(pos)
	if impulse == Vector2.ZERO:
		if _bonus_figure != null:
			_skip_bonus_flick()  # a tap: no extra flick
		else:
			var tapped := _aim_figure
			_cancel_aim()
			if _press_was_empty:
				_tap_empty_board(pos)
			elif is_instance_valid(tapped) and _tap_ability_ready(tapped, "self") and (_press_on_selected or not tapped.flickable):
				_try_self_tap(tapped)
		return
	if not _aim_figure.flickable:  # (selected only for a tap ability: dragging does not flick it)
		_cancel_aim()
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
	_on_takeover(figure)
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
		figure.ability.on_bloodlust_bonus(figure)  # its damping stacks up
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


func _any_player_figure_at(pos: Vector2) -> Figure:
	var best: Figure = null
	var best_distance := INF
	for figure in _players:
		var distance := figure.global_position.distance_to(pos)
		if _is_alive(figure) and distance <= figure.radius + grab_padding and distance < best_distance:
			best = figure
			best_distance = distance
	return best


func _tap_ability_ready(figure: Figure, kind: String) -> bool:
	var tap := figure.ability.get_tap_ability(figure)
	return not tap.is_empty() and tap.kind == kind and tap.ready


## Magnet's push, Absorber's spit, ...: tapping the selected figure again uses its ability.
func _try_self_tap(figure: Figure) -> void:
	var tap := figure.ability.get_tap_ability(figure)
	if figure.ability.use_tap_ability(figure, figure.global_position):
		_after_tap_ability(figure, tap)


## After a tap ability ran: if it uses the action the turn goes on like after a flick, otherwise nothing is used up.
func _after_tap_ability(figure: Figure, tap: Dictionary) -> void:
	if tap.get("uses_action", false):
		_take_snapshot()
		figure.flickable = false
		figure.turn_flicks = figure.ability.get_flicks_per_turn(figure)
		_on_any_flick(figure, Vector2.ZERO)
		_last_player_flicker = figure
		_bonus_figure = null
		_cancel_aim()
		_deselect()
		_state = State.SETTLING
		_finish_player_turn()
	else:
		_cancel_aim()
		ui.show_your_turn(tap.get("hint", "Done. Drag anywhere to flick"))


## Spitter: the touch was held still: start spraying toward the finger (instead of flicking).
func _start_spray() -> void:
	_hold_pending = false
	if not is_instance_valid(_aim_figure):
		return
	_spraying = true
	aim_line.clear()
	_aim_figure.ability.set_spray(_aim_figure, true, _last_touch)
	ui.show_your_turn("Spraying: release to stop")


## Spitter: the finger lifted. Spraying does NOT use up its action: it can spray again, flick, or you can pick another figure.
func _end_spray() -> void:
	var figure := _aim_figure
	_spraying = false
	if is_instance_valid(figure):
		figure.ability.set_spray(figure, false)
	_cancel_aim()
	ui.show_your_turn("Drag to flick, or hold to spray again")


## Enemy Spitter: sprays toward `point` for a while (before its flick, which it still takes).
func _enemy_spray(enemy: Figure, point: Vector2, seconds: float) -> void:
	enemy.show_popup("Spray!", Color(0.5, 0.75, 1.0))
	enemy.ability.set_spray(enemy, true, point)
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(enemy):
		enemy.ability.set_spray(enemy, false)


## Alchemist: placing its zone is its whole action this cycle (like a flick, without launching it).
func _use_up_turn_placing(figure: Figure) -> void:
	_take_snapshot()
	figure.flickable = false
	figure.turn_flicks = figure.ability.get_flicks_per_turn(figure)
	figure.show_popup("Zone placed!", Color(0.8, 0.6, 1.0))
	_last_player_flicker = figure
	_bonus_figure = null
	_cancel_aim()
	_deselect()
	_state = State.SETTLING
	_finish_player_turn()


## A tap on empty board with a figure selected: Pinhead places (or takes back) its temporary pin.
func _tap_empty_board(pos: Vector2) -> void:
	if not _is_alive(_selected) or not _selected.flickable:
		return
	var turret := _selected.ability.get_turret_stats(_selected)
	var pin_options := _selected.ability.get_pin_options(_selected)
	var places := not turret.is_empty() or not _selected.ability.get_zone_stats(_selected).is_empty() \
			or _selected.ability.get_pin_radius(_selected) > 0.0
	if places and _selected.placed_this_turn:  # one placement per turn, and it can't be moved again
		ui.show_your_turn("Already placed this turn. Drag anywhere to flick")
		return
	if not turret.is_empty():  # Engineer
		match arena.toggle_turret(_selected, pos, turret, board.board_rect):
			"placed":
				_selected.placed_count += 1
				if _selected.placed_count >= int(turret.get("max_turrets", 1)):
					_selected.placed_this_turn = true
				ui.show_your_turn("Turret placed. Drag anywhere to flick")
			"removed":
				ui.show_your_turn("Turret removed. Drag anywhere to flick")
			_:
				ui.show_your_turn("Can't place a turret there")
		return
	var tap := _selected.ability.get_tap_ability(_selected)
	if not tap.is_empty() and tap.kind == "point":  # Ghost's teleport...
		if tap.ready and _selected.ability.use_tap_ability(_selected, pos):
			_after_tap_ability(_selected, tap)
		else:
			ui.show_your_turn("Not ready")
		return
	var toss := _selected.ability.get_toss_stats(_selected)
	if not toss.is_empty():  # Cluster: tap = toss a clustling toward that spot (instead of flicking)
		if toss.can and toss.get("keeps_action", false):
			_selected.ability.fire_shot_at(_selected, pos)  # Rebound: tossing does not use up the flick
			ui.show_your_turn("Tossed. Drag anywhere to flick")
		elif toss.can:
			_fire_shot(_selected, pos)
		else:
			ui.show_your_turn("Can't toss its last clustling")
		return
	if not _selected.ability.get_shot_stats(_selected).is_empty():  # Blastoid: tap = fire at that spot
		_fire_shot(_selected, pos)
		return
	var zone := _selected.ability.get_zone_stats(_selected)
	if not zone.is_empty():  # Alchemist: placing a zone is its action (it cannot also flick); one per turn
		if arena.place_zone(_selected, pos, zone, board.board_rect):
			_selected.placed_this_turn = true
			if zone.get("keeps_action", false):  # Quick Mix: place a zone and still flick
				ui.show_your_turn("Zone placed. Drag anywhere to flick")
			else:
				_use_up_turn_placing(_selected)
		else:
			ui.show_your_turn("Can't place a zone there")
		return
	var radius := _selected.ability.get_pin_radius(_selected)  # Pinhead: placing the pin does NOT use its flick
	if radius <= 0.0:
		return
	match arena.toggle_temp_pin(_selected, pos, radius, board.board_rect, pin_options):
		"placed":
			_selected.placed_count += 1
			if _selected.placed_count >= int(pin_options.get("per_turn", 1)):
				_selected.placed_this_turn = true
			ui.show_your_turn("Pin placed. Drag anywhere to flick")
		"removed":
			ui.show_your_turn("Pin removed. Drag anywhere to flick")
		_:
			ui.show_your_turn("Can't place a pin there")


func _cancel_aim() -> void:
	_hold_pending = false
	if _spraying and is_instance_valid(_aim_figure):
		_aim_figure.ability.set_spray(_aim_figure, false)
		_spraying = false
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
	while not _bonus_queue.is_empty():  # figures granted a flick right now (Energizer's Instant Recharge...)
		var queued = _bonus_queue.pop_front()
		if _is_alive(queued) and queued.team == Figure.Team.PLAYER:
			queued.turn_flicks = 0
			queued.flickable = true
			_offer_bonus_flick(queued)
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


## A turn ended (the player's or the enemy's): per-turn counters (Aggro-bom) reset.
func _clear_temp_buffs(team: int) -> void:
	for figure in _all_figures():
		if _is_alive(figure) and figure.temp_taken_team == team:
			figure.temp_dealt = 0.0
			figure.temp_taken = 1.0
			figure.temp_taken_team = -1


func _end_turn_for_all() -> void:
	for figure in _all_figures():
		if _is_alive(figure):
			figure.ability.on_turn_ended(figure)
			figure.placed_this_turn = false  # pins, zones and turrets can be placed again next turn
			figure.placed_count = 0


func _run_enemy_turn() -> void:
	_end_turn_for_all()  # (the player's turn is over)
	_clear_temp_buffs(Figure.Team.ENEMY)
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
	_place_enemy_zones()
	_enemy_tap_abilities()
	if _enemy_turns_taken == 0:
		var wait := RunManager.relic_first_enemy_turn(self)  # Starter Walls: walls pop up before the first shot
		if wait > 0.0:
			await get_tree().create_timer(wait).timeout
			if serial != _turn_serial:
				return
	_enemy_turns_taken += 1
	# The enemy side takes _enemy_flicks flicks. Each one is the best shot of ANY enemy figure.
	# The total is read every round: in the per-unit boss fights it changes as pieces appear or fall off.
	var flicks_taken := 0
	while flicks_taken < _enemy_flicks_now():
		flicks_taken += 1
		var total := _enemy_flicks_now()
		if total > 1:
			ui.show_enemy_turn("Enemy flicks: %d/%d" % [flicks_taken, total])
		_refresh_enemy_cycle()
		if _creator_box != null and flicks_taken == 1 and _creator_box.creator_inside():
			if await _creator_turn(serial):  # the Mad Creator's summon flick is the first flick of the turn
				return
			continue
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
		if choice.has("pin_only"):
			# An enemy Pinhead's whole action is placing a pin (for an ally's bank shot): no flick this time.
			arena.place_temp_pin(choice.enemy, choice.pin, choice.pin_radius, board.board_rect, choice.enemy.ability.get_pin_options(choice.enemy))
			choice.enemy.placed_this_turn = true
			choice.enemy.show_popup("Pin!", Color(0.75, 0.85, 0.95))
			choice.enemy.turn_flicks = choice.enemy.ability.get_flicks_per_turn(choice.enemy)
			await _wait_until_settled()
			if serial != _turn_serial:
				return
			continue
		if choice.has("spray_point") and (choice.has("impulse") or choice.has("shot_point")):
			# an enemy Spitter sprays first and then still flicks
			await _enemy_spray(choice.enemy, choice.spray_point, choice.spray_seconds)
			if serial != _turn_serial or not _is_alive(choice.enemy):
				return
		if choice.has("pass"):  # a taken-over boss with no safe shot: the flick is wasted
			choice.enemy.turn_flicks = choice.enemy.ability.get_flicks_per_turn(choice.enemy)
		elif choice.has("spray_point") and not choice.has("impulse") and not choice.has("shot_point"):
			# an enemy Spitter with nothing to flick: spray only (that counts as its turn)
			await _enemy_spray(choice.enemy, choice.spray_point, choice.spray_seconds)
			if serial != _turn_serial:
				return
			choice.enemy.turn_flicks = choice.enemy.ability.get_flicks_per_turn(choice.enemy)
			_on_any_flick(choice.enemy, Vector2.ZERO)
		elif choice.has("shot_point"):  # an enemy Blastoid fires (or a Cluster tosses) instead of moving
			choice.enemy.shoot_at(choice.shot_point)
			_on_any_flick(choice.enemy, Vector2.ZERO)
		else:
			choice.enemy.launch(choice.impulse)
		enemy_flicks_made += 1
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
			if bloodlust:
				shooter.ability.on_bloodlust_bonus(shooter)  # stack first: the AI then plans with the longer slide
			var extra := ai.choose_flick([shooter], _players, board.get_table_rect(), max_flick_force, ai.bonus_flick_min_score)
			await get_tree().create_timer(enemy_think_time).timeout
			if serial != _turn_serial:
				return
			if extra.is_empty() or extra.has("pin_only") or extra.has("shot_point") or extra.has("spray_point") or not _is_alive(shooter):
				break
			if bloodlust:
				shooter.bonus_flicks_used += 1
				shooter.show_popup("Bloodlust!", Color(1.0, 0.25, 0.3))
			extra = await _takeover_choice(extra, serial)
			if serial != _turn_serial:
				return
			if not _is_alive(shooter) or extra.has("pass"):
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


## The Mad Creator's flick: it flicks itself around inside its box (random direction and distance), and the floor
## space it comes to rest on summons that figure in front of the box (if fewer than the cap are on the table).
## Returns true if the turn (or the fight) is over and the caller should stop.
func _creator_turn(serial: int) -> bool:
	var creator: Figure = _creator_box.creator
	await get_tree().create_timer(enemy_think_time).timeout
	if serial != _turn_serial:
		return true
	if not _is_alive(creator):
		return _check_game_over()
	_last_flicker = creator
	var distance := randf_range(_creator_box.min_travel, _creator_box.max_travel)
	var speed := distance * creator.linear_damp + creator.stop_speed
	creator.launch(Vector2.from_angle(randf() * TAU) * speed * creator.mass)
	await _wait_until_settled()
	if serial != _turn_serial:
		return true
	if _check_game_over():
		return true
	if not _is_alive(creator) or not _creator_box.creator_inside():
		return false  # it got out of the box: no floor under it, no summon
	var summoned: FigureData = _creator_box.summon_for(creator.global_position)
	if summoned == null:
		return false
	var count := 0
	for enemy in _enemies:
		if _is_alive(enemy) and enemy != creator:
			count += 1
	if count >= RunManager.boss.max_summons:
		creator.show_popup("Too many!", Color(0.8, 0.8, 0.9))
		return false
	var spot := _creator_box.free_spot_in_front(board.board_rect, summoned.radius, _all_figures())
	if spot == Vector2.INF:
		return false
	creator.show_popup("Summon: %s!" % summoned.display_name, Color(0.85, 0.6, 1.0))
	_enemies.append(_spawn_figure(Figure.Team.ENEMY, summoned, spot, null, null, RunManager.NO_UPGRADE, RunManager.enemy_scale(0)))
	await get_tree().create_timer(enemy_think_time).timeout
	return serial != _turn_serial


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


## A taken-over flick starts: Gloom's bonuses (more knockback, staying bummed one more flick).
func _on_takeover(figure: Figure) -> void:
	var in_aura := not figure.bummer_effect_at(figure.global_position).is_empty()
	var stats := figure.bummer_effect()
	if in_aura:
		figure.bummed_extra = stats.get("linger", 0)
		figure.bummed_stats = stats
	elif figure.bummed_extra > 0:
		figure.bummed_extra -= 1
	var bonus: float = stats.get("knockback", 0.0)
	if bonus > 0.0:
		figure.temp_dealt = maxf(figure.temp_dealt, bonus)
		figure.temp_taken_team = figure.team


## An enemy figure touching a player Bummer's aura is taken over when the AI goes to flick it: "Bummed out!",
## then a shot that tries to knock itself off and hit its own teammates replaces the planned one.
func _takeover_choice(choice: Dictionary, serial: int) -> Dictionary:
	var enemy = choice.enemy  # untyped: it may fall off and be freed while we wait
	if choice.has("pin_only") or not _is_alive(enemy) or enemy.bummer_effect().is_empty():
		return choice
	enemy.show_popup("Bummed out!", Color(0.8, 0.5, 1.0))
	await get_tree().create_timer(takeover_delay).timeout
	if serial != _turn_serial or not _is_alive(enemy):
		return choice
	var allies: Array[Figure] = []
	for other in _enemies:
		if other != enemy and _is_alive(other):
			allies.append(other)
	_on_takeover(enemy)
	var shot := ai.choose_takeover(enemy, allies, board.get_table_rect(), max_flick_force)
	if shot.is_empty():
		return choice
	if shot.get("pass", false):  # a boss body with no safe shot: the takeover just wastes the flick
		enemy.show_popup("Passes", Color(0.8, 0.5, 1.0))
		return {"enemy": enemy, "pass": true}
	return {"enemy": enemy, "impulse": shot.impulse}


## Enemy figures with a tap ability (Magnet's push / implode, Absorber's spit, Ghost's teleport) use it at the start of
## their turn when the AI thinks it pays (the abilities' `ai_wants_tap` / `ai_tap_point`).
func _enemy_tap_abilities() -> void:
	var opponents: Array = []
	for player in _players:
		if _is_alive(player):
			opponents.append(player)
	for enemy in _enemies:
		if not _is_alive(enemy):
			continue
		var tap: Dictionary = enemy.ability.get_tap_ability(enemy)
		if tap.is_empty() or not tap.ready:
			continue
		var used := false
		if tap.kind == "self" and enemy.ability.ai_wants_tap(enemy, opponents):
			used = enemy.ability.use_tap_ability(enemy, enemy.global_position)
		elif tap.kind == "point":
			var point: Vector2 = enemy.ability.ai_tap_point(enemy, opponents)
			if point != Vector2.INF:
				used = enemy.ability.use_tap_ability(enemy, point)
		if used and tap.get("uses_action", false):
			_enemy_cycle[enemy.get_instance_id()] = true
			enemy.turn_flicks = enemy.ability.get_flicks_per_turn(enemy)
	_refresh_enemy_cycle()


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
			if arena.place_turret(enemy, spot, stats, board.board_rect):
				enemy.placed_this_turn = true


## Enemy Alchemists put their debuff zone where it catches the most player figures: at the start of the enemy turn,
## at most once per turn, and it does not cost a flick (like the player's).
func _place_enemy_zones() -> void:
	for enemy in _enemies:
		if not _is_alive(enemy) or enemy.placed_this_turn or _enemy_cycle.has(enemy.get_instance_id()):
			continue
		var stats := enemy.ability.get_zone_stats(enemy)
		if stats.is_empty():
			continue
		var spot := ai.choose_zone_spot(enemy, _players)
		if spot != Vector2.INF and arena.place_zone(enemy, spot, stats, board.board_rect):
			enemy.placed_this_turn = true
			if not stats.get("keeps_action", false):
				_enemy_cycle[enemy.get_instance_id()] = true  # placing is its action this cycle (it does not flick too)
			enemy.show_popup("Zone!", Color(0.8, 0.6, 1.0))
			_refresh_enemy_cycle()


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
	for enemy in _enemies:
		if _is_alive(enemy):
			enemy.ability.on_became_flickable(enemy)


## The enemies allowed to flick right now: alive, able to flick, and not the one that flicked
## last (unless it is the only one).
func _flick_candidates() -> Array:
	var able: Array = []
	for enemy in _enemies:
		if _is_alive(enemy) and enemy.data.can_flick and not enemy.is_frozen() and enemy.stunned_rounds == 0:
			if _creator_box != null and enemy == _creator_box.creator and _creator_box.creator_inside():
				continue  # the Creator in its box only makes its own summon flick (_creator_turn)
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
	_settling = true
	await _wait_until_settled_inner()
	_settling = false


## True while something other than pellet nudges is moving (a flick, a slide, a projectile in flight).
func _real_motion() -> bool:
	if not get_tree().get_nodes_in_group("projectiles").is_empty():
		return true
	for figure in _all_figures():
		if _is_alive(figure) and not figure.is_resting() and not figure.is_pellet_driven():
			return true
	return false


func _wait_until_settled_inner() -> void:
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
	if _creator_box != null and not _is_alive(_creator_box.creator):
		# The Mad Creator is off the table: everything it summoned vanishes.
		for enemy in _enemies:
			if _is_alive(enemy):
				enemy.knock_off(knock_off_fade_time, true)
		_enemies.clear()
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
		RunManager.pending_choice_bonus = 0
		for figure in _players:  # Cha-ching's Extra Option: extra figure choices for surviving
			if _is_alive(figure):
				RunManager.pending_choice_bonus += figure.ability.get_reward_choice_bonus(figure)
		RunManager.award_income(on_table, equipment_bonus)
		RunManager.notify_combat_won({"figures_lost": _figures_lost})
		var income: int = RunManager.last_income.total
		var run_complete := RunManager.combat_won()
		if not run_complete and RunManager.in_second_boss and RunManager.node.type == MapNode.Type.BOSS and RunManager.is_last_act() \
				and RunManager.reward_steps.is_empty():
			# Ascension 10: the other act 3 boss comes straight after (no rewards in between).
			ui.show_your_turn("Boss beaten! Now: %s" % RunManager.boss.display_name)
			await get_tree().create_timer(reward_delay).timeout
			get_tree().reload_current_scene()
			return
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
		figure.deck_slot = i
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
		finish: FinishData = null, upgrade_state := Vector2i(-1, 0), scale := {}, elite := false) -> Figure:
	var figure: Figure = figure_scene.instantiate()
	var damping := figure_damping * (RunManager.relic_player_damping() if team == Figure.Team.PLAYER else RunManager.enemy_relic_damping())
	figure.setup(data, team, damping, stop_speed, settle_frames, item, finish, RunManager.owned_upgrades(data, upgrade_state), scale, elite)
	figure.upgrade_state = upgrade_state
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
		var spawned := _spawn_figure(parent.team, piece.data, piece.position, null, null, RunManager.NO_UPGRADE, parent.scale_factors)
		spawned.apply_central_impulse(piece.velocity * spawned.mass)
		if parent.team == Figure.Team.ENEMY:
			_enemies.append(spawned)
		else:
			spawned.on_deck = false
			spawned.flickable = piece.get("flickable", false)  # (a tossed clustling is fresh and flickable)
			spawned.deck_position = parent.deck_position
			_players.append(spawned)
		if piece.has("on_spawn"):
			piece.on_spawn.call(spawned)


## A figure (a Slime) splits: spawn its pieces on its team, then remove it. The pieces are new
## enemies, so they take their own turns from the next enemy turn on.
func _on_split_requested(parent: Figure, pieces: Array, grants_flicks: bool) -> void:
	if not _is_alive(parent):
		return
	for piece in pieces:
		var spawned := _spawn_figure(parent.team, piece.data, piece.position, null, null, RunManager.NO_UPGRADE, parent.scale_factors)
		spawned.apply_central_impulse(piece.velocity * spawned.mass)
		if parent.team == Figure.Team.ENEMY:
			_enemies.append(spawned)
		else:
			# Born out on the board: not on deck, but fresh and unflicked: it can be flicked this same round.
			spawned.on_deck = false
			spawned.flickable = true
			spawned.deck_position = parent.deck_position
			_players.append(spawned)
		if piece.has("on_spawn"):
			piece.on_spawn.call(spawned)
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
	var fallen_players: Array[Figure] = []
	for figure in _all_figures():
		if not table.has_point(figure.global_position):
			if figure.bubble_rounds > 0:
				_stop_at_edge(figure, table)  # Bubble Shield
				continue
			if figure.has_meta("ghost_wrap"):  # an ally a Ghost passed through (Wrap Gift): one wrap
				figure.remove_meta("ghost_wrap")
				var wrapped := figure.global_position
				wrapped.x = table.position.x + fposmod(wrapped.x - table.position.x, table.size.x)
				wrapped.y = table.position.y + fposmod(wrapped.y - table.position.y, table.size.y)
				figure.global_position = wrapped
				figure.show_popup("Boo!", Color(0.85, 0.9, 1.0))
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
			else:
				fallen_players.append(figure)
	for victim in fallen_players:  # (enemy figures react too, e.g. a Speedo's Kill Rush)
		for enemy in _enemies:
			if _is_alive(enemy):
				enemy.ability.on_opponent_knocked_off(enemy, victim)
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
## Costume Change: true on the player's own turn while nothing moves and no flick is half done.
func can_swap_equipment() -> bool:
	return _state == State.PLAYER_TURN and _bonus_figure == null


## Costume Change: puts the deck slot's current equipment on its figure on the board (or on deck).
func refresh_equipment(slot: int) -> void:
	for figure in _players:
		if figure.deck_slot == slot and _is_alive(figure):
			figure.set_equipment(RunManager.deck_equipment[slot])


## Firecracker's Safety Officer: its team keeps the explosion cover for `rounds` rounds after it is knocked off.
func add_lingering_cover(team: int, reduction: float, rounds: int) -> void:
	_lingering_cover[team] = {"reduction": reduction, "rounds": rounds}


func lingering_cover_for(team: int) -> float:
	return _lingering_cover[team].reduction if _lingering_cover.has(team) else 0.0


## The player's figure gets a flick right after the current flick settles (like Speedo's second flick).
func grant_bonus_flick(figure: Figure) -> void:
	if figure.team == Figure.Team.PLAYER and not _bonus_queue.has(figure):
		_bonus_queue.append(figure)


## A figure leaves play without counting as knocked off (a clustling rejoining its cluster).
func retire_figure(figure: Figure) -> void:
	if not _is_alive(figure):
		return
	_players.erase(figure)
	_enemies.erase(figure)
	figure.knock_off(knock_off_fade_time, true)


## Absorber: `figure` is held inside it. It leaves play at once (win/loss ignore it) but is kept, hidden and
## frozen, until it is freed or fully shrunk.
func absorb_figure(figure: Figure) -> void:
	if not _is_alive(figure):
		return
	_players.erase(figure)
	_enemies.erase(figure)
	figure.knocked_off = true
	figure.linear_velocity = Vector2.ZERO
	figure.collision_layer = 0
	figure.collision_mask = 0
	figure.freeze = true
	figure.visible = false
	if figure == _selected:
		_deselect()


## The held figure is fully shrunk: it counts as knocked off (relics, income, kill counts) and is gone.
func finish_absorbed(figure: Figure) -> void:
	if not is_instance_valid(figure):
		return
	figure.knocked_off = false  # (so the usual knock-off bookkeeping accepts it)
	figure.visible = true
	if figure.team == Figure.Team.PLAYER:
		_figures_lost += 1
	_count_kill(figure)
	figure.knock_off(knock_off_fade_time)
	if figure.team == Figure.Team.ENEMY:
		for player in _players:
			if _is_alive(player):
				player.ability.on_opponent_knocked_off(player, figure)


## The held figure escapes (or its Absorber fell): back in play at `at`, at its current (shrunk) size.
func release_absorbed(figure: Figure, at: Vector2, velocity := Vector2.ZERO) -> void:
	if not is_instance_valid(figure):
		return
	var table: Rect2 = board.get_table_rect()
	figure.knocked_off = false
	figure.visible = true
	figure.freeze = false
	figure.global_position = Vector2(clampf(at.x, table.position.x + 40.0, table.end.x - 40.0),
			clampf(at.y, table.position.y + 40.0, table.end.y - 40.0))
	figure.linear_velocity = velocity
	figure._update_collision()
	if figure.team == Figure.Team.PLAYER:
		figure.on_deck = false
		_players.append(figure)
	else:
		_enemies.append(figure)


func recharge_figure(figure: Figure) -> void:
	if not _is_alive(figure):
		return
	figure.turn_flicks = 0
	figure.ability.on_became_flickable(figure)
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
	Figure.blast(get_tree(), point, radius, force, null, null, Figure.Team.PLAYER)  # (a power: the player's explosion)


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
			"equipment": figure.equipment, "finish": figure.finish, "upgrade": figure.upgrade_state,
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


## A power was discarded in the Inventory: drop any pending targeting and redraw the power bar.
func _on_powers_discarded() -> void:
	_cancel_power()
	ui.set_powers(RunManager.powers)


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
