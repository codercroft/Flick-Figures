extends Node2D
## Game controller: spawns figures, reads touch input, runs the turn, knocks figures off.

enum State { IDLE, AIMING, MOVING }

const FIGURE_COLORS := [
	Color(0.9, 0.25, 0.25),
	Color(0.25, 0.5, 0.9),
	Color(0.3, 0.75, 0.35),
	Color(0.95, 0.75, 0.2),
]

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

@export_group("Turn")
## Don't check for "everything stopped" until this long after a flick (seconds).
@export var min_move_time := 0.3
@export var knock_off_fade_time := 0.4

var _state := State.IDLE
var _figures: Array[Figure] = []
var _aim_figure: Figure
var _touch_index := -1
var _touch_start := Vector2.ZERO
var _move_time := 0.0

@onready var board := $Board
@onready var figures_root := $Figures
@onready var aim_line := $AimLine


func _ready() -> void:
	_spawn_figures()


func _physics_process(delta: float) -> void:
	_knock_off_fallen_figures()
	if _state == State.MOVING:
		_move_time += delta
		if _move_time >= min_move_time and _all_figures_resting():
			_end_turn()


# --- Input -------------------------------------------------------------------
# Written against touch events; "emulate touch from mouse" makes the mouse work too.

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var pos := _to_world(event.position)
		if event.pressed:
			_begin_aim(event.index, pos)
		elif event.index == _touch_index:
			if event.canceled:
				_cancel_aim()
			else:
				_release_aim(pos)
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_aim(_to_world(event.position))


func _to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos


func _begin_aim(index: int, pos: Vector2) -> void:
	if _state != State.IDLE:
		return
	var figure := _figure_at(pos)
	if figure == null:
		return
	_state = State.AIMING
	_touch_index = index
	_aim_figure = figure
	_touch_start = pos
	_update_aim(pos)


func _update_aim(pos: Vector2) -> void:
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
	var impulse := _flick_impulse(pos)
	if impulse == Vector2.ZERO:
		_cancel_aim()
		return
	aim_line.clear()
	_aim_figure.launch(impulse)
	_aim_figure = null
	_touch_index = -1
	_state = State.MOVING
	_move_time = 0.0


func _cancel_aim() -> void:
	aim_line.clear()
	_aim_figure = null
	_touch_index = -1
	_state = State.IDLE


## The flick is opposite the drag. Drag down = flick up. Zero means "no flick".
func _flick_impulse(pos: Vector2) -> Vector2:
	var drag := pos - _touch_start
	var pull := minf(drag.length(), max_pull_distance)
	if pull < min_pull_distance or drag.y <= 0.0:
		return Vector2.ZERO
	return -drag.normalized() * (pull / max_pull_distance) * max_flick_force


func _figure_at(pos: Vector2) -> Figure:
	var best: Figure = null
	var best_distance := INF
	for figure in _figures:
		var distance := figure.global_position.distance_to(pos)
		if figure.can_flick and distance <= figure.radius + grab_padding and distance < best_distance:
			best = figure
			best_distance = distance
	return best


# --- Figures and turns -------------------------------------------------------

func _spawn_figures() -> void:
	var deck: Rect2 = board.deck_rect
	var slot_width := deck.size.x / figure_count
	for i in figure_count:
		var figure: Figure = figure_scene.instantiate()
		figure.radius = figure_radius
		figure.mass = figure_mass
		figure.linear_damp = figure_damping
		figure.bounciness = figure_bounciness
		figure.stop_speed = stop_speed
		figure.color = FIGURE_COLORS[i % FIGURE_COLORS.size()]
		figure.position = Vector2(deck.position.x + slot_width * (i + 0.5), deck.get_center().y)
		figures_root.add_child(figure)
		_figures.append(figure)


func _all_figures_resting() -> bool:
	for figure in _figures:
		if not figure.on_deck and not figure.is_resting():
			return false
	return true


func _knock_off_fallen_figures() -> void:
	var board_rect: Rect2 = board.board_rect
	for figure in _figures.duplicate():
		if figure.on_deck:
			continue
		if board_rect.has_point(figure.global_position):
			figure.entered_board = true
		elif figure.entered_board:
			_knock_off(figure)


func _knock_off(figure: Figure) -> void:
	_figures.erase(figure)
	figure.knock_off(knock_off_fade_time)


func _end_turn() -> void:
	_state = State.IDLE
	# A weak flick can stop short of the board; it never made it onto the table.
	var board_rect: Rect2 = board.board_rect
	for figure in _figures.duplicate():
		if not figure.on_deck and not board_rect.has_point(figure.global_position):
			_knock_off(figure)

	if _figures.is_empty():
		_spawn_figures()
		return
	# Everyone has been flicked: everyone may be flicked again.
	for figure in _figures:
		if figure.can_flick:
			return
	for figure in _figures:
		figure.set_can_flick(true)
