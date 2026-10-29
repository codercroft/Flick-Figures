class_name Minigame
extends Node2D
## Base class of the minigame events (Bocce, Curling, Bowling). A minigame is one small scene: an open
## table, real Figures with the normal flick controls and physics, and a result panel at the bottom.
## Subclasses override `_run()` (an async game loop), `_draw_table()` and call `finish()` with the result.
## Flicking works like combat: press and drag ANYWHERE, opposite to where the figure should go.

const FIGURE_SCENE := preload("res://scenes/figure.tscn")
const AIM_LINE := preload("res://scripts/aim_line.gd")
const GRUNT := preload("res://resources/figures/grunt.tres")
const MAP_SCENE := "res://scenes/map.tscn"
const REWARD_SCENE := "res://scenes/reward.tscn"
## Height (px) reserved at the bottom for the status text.
const BOTTOM_UI_HEIGHT := 230.0

@export_group("Flick")
## Impulse of a full-strength flick (same as combat).
@export var max_flick_force := 2400.0
## Drag this far, as a fraction of the screen width, for a full-strength flick.
@export_range(0.1, 0.6) var max_pull_fraction := 0.3
## Drags shorter than this (px) are cancelled instead of flicking.
@export var min_pull_distance := 40.0

@export_group("Physics")
## Base damping (same as combat). Higher = stops sooner.
@export var figure_damping := 1.5
## Figures slower than this (px/s) count as slow, and stop dead after `settle_frames` frames.
@export var stop_speed := 15.0
@export var settle_frames := 5
## Wait this long (seconds) after a flick before checking that everything has stopped.
@export var settle_delay := 0.3
## Safety net: if figures still move this long (seconds) after a flick, stop them all.
@export var max_settle_time := 8.0

@export_group("Table")
## The open table. Any figure whose center leaves it falls off.
@export var board_rect := Rect2(90, 360, 900, 1000)
@export var board_color := Color(0.78, 0.66, 0.47)
@export var border_color := Color(0.42, 0.3, 0.18)
## Where the player's figures start, this far above the bottom edge.
@export var launch_margin := 90.0
@export var knock_off_fade_time := 0.3

signal player_flicked

var figures_root := Node2D.new()
var overlay := Node2D.new()  # drawn above the figures (distance lines, markers)
var aim_line: Node2D
var camera := Camera2D.new()
var status_label := Label.new()
var top_bar := TopBar.new()

var _flick_figure: Figure  # the figure the player may flick right now (null = no input)
var _touch_index := -1
var _touch_start := Vector2.ZERO
var _aiming := false
var _finished := false
var _result_layer := CanvasLayer.new()
var _next_scene := MAP_SCENE


func _ready() -> void:
	RunManager.combat = null
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(camera)
	add_child(figures_root)
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	aim_line = Node2D.new()
	aim_line.set_script(AIM_LINE)
	add_child(aim_line)
	add_child(top_bar)
	var ui := CanvasLayer.new()
	add_child(ui)
	status_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	status_label.offset_top = -(BOTTOM_UI_HEIGHT - 20.0 + SafeArea.insets().bottom)
	status_label.offset_bottom = -(20.0 + SafeArea.insets().bottom)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.add_theme_font_size_override("font_size", 44)
	ui.add_child(status_label)
	_result_layer.layer = 25
	add_child(_result_layer)
	_fit_world(TopBar.height(), BOTTOM_UI_HEIGHT + SafeArea.insets().bottom)
	queue_redraw()
	_run()


func _draw() -> void:
	draw_rect(board_rect, board_color)
	draw_rect(board_rect, border_color, false, 8.0)
	_draw_table()


## Override: draw anything on the table (target rings...). Figures are drawn on top.
func _draw_table() -> void:
	pass


## Override: draw above the figures.
func _draw_overlay() -> void:
	pass


## Override: the game loop. Use `await request_flick(...)`, `await wait_until_settled()` and `finish()`.
func _run() -> void:
	pass


# --- Layout and input ---------------------------------------------------------

## Centers the table between the status bar and the bottom text (the same camera trick as combat).
func _fit_world(top_px: float, bottom_px: float) -> void:
	var view := get_viewport_rect().size
	var margin := 24.0
	var block := board_rect.grow(margin)
	var available := view.y - top_px - bottom_px
	var zoom := minf(1.0, minf(available / block.size.y, view.x / block.size.x))
	var screen_center := Vector2(view.x / 2.0, top_px + available / 2.0)
	camera.zoom = Vector2(zoom, zoom)
	camera.position = block.get_center() - screen_center / zoom


func _to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos


func _input(event: InputEvent) -> void:
	if _flick_figure == null or RunInfo.is_open:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and not top_bar.is_over(event.position):
				_touch_index = event.index
				_touch_start = _to_world(event.position)
				_aiming = true
				_update_aim(_touch_start)
		elif event.index == _touch_index:
			if event.canceled:
				_cancel_aim()
			else:
				_release_aim(_to_world(event.position))
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_aim(_to_world(event.position))


## The flick is opposite the drag. Zero means "no flick".
func _flick_impulse(pos: Vector2) -> Vector2:
	var drag := pos - _touch_start
	var max_pull := get_viewport_rect().size.x * max_pull_fraction
	var pull := minf(drag.length(), max_pull)
	if pull < min_pull_distance:
		return Vector2.ZERO
	return -drag.normalized() * (pull / max_pull) * full_force(_flick_figure)


## The impulse of a full-strength flick for this figure.
func full_force(figure: Figure) -> float:
	return max_flick_force * figure.data.flick_power_multiplier * figure.ability.get_flick_power_multiplier(figure)


func _update_aim(pos: Vector2) -> void:
	if not _aiming or _flick_figure == null:
		return
	var impulse := _flick_impulse(pos)
	if impulse == Vector2.ZERO:
		aim_line.clear()
		return
	# Roughly where the figure will come to rest (ignores bumping into things).
	var speed := impulse.length() / _flick_figure.mass
	var distance := maxf(speed - stop_speed, 0.0) / _flick_figure.linear_damp
	var direction := impulse.normalized()
	aim_line.show_aim(_flick_figure.global_position + direction * _flick_figure.radius, direction, distance)


func _release_aim(pos: Vector2) -> void:
	var impulse := _flick_impulse(pos) if _aiming and _flick_figure != null else Vector2.ZERO
	_cancel_aim()
	if impulse == Vector2.ZERO:
		return
	var figure := _flick_figure
	_flick_figure = null
	figure.selected = false
	figure.launch(impulse)
	player_flicked.emit()


func _cancel_aim() -> void:
	aim_line.clear()
	_aiming = false
	_touch_index = -1


## Lets the player flick `figure` (drag anywhere). Returns when the flick has been taken.
func request_flick(figure: Figure, prompt: String) -> void:
	figure.selected = true
	status_label.text = prompt
	_flick_figure = figure
	await player_flicked


# --- Figures -------------------------------------------------------------------

## A new figure on the table. Player figures start "on deck" so they ignore each other until flicked.
func spawn_figure(data: FigureData, team: Figure.Team, pos: Vector2, item: EquipmentData = null) -> Figure:
	var figure: Figure = FIGURE_SCENE.instantiate()
	figure.setup(data, team, figure_damping, stop_speed, settle_frames, item)
	figure.on_deck = team == Figure.Team.PLAYER
	figure.position = pos
	figures_root.add_child(figure)
	return figure


## A copy of the Grunt in another color (so the two sides are easy to tell apart).
func colored_grunt(color: Color) -> FigureData:
	var data := GRUNT.duplicate() as FigureData
	data.color = color
	return data


func alive(figure) -> bool:  # untyped on purpose: a freed Figure can't be passed as a Figure
	return is_instance_valid(figure) and not figure.knocked_off


func all_figures() -> Array[Figure]:
	var list: Array[Figure] = []
	for child in figures_root.get_children():
		var figure := child as Figure
		if figure != null and not figure.knocked_off:
			list.append(figure)
	return list


func _physics_process(_delta: float) -> void:
	for figure in all_figures():
		if not board_rect.has_point(figure.global_position):
			on_fell(figure)


## A figure's center left the table. The default removes it; subclasses can save it (the jack).
func on_fell(figure: Figure) -> void:
	figure.knock_off(knock_off_fade_time)


## A launch point on the bottom edge near `x` where no figure is in the way.
func free_launch_point(from_top := false) -> Vector2:
	var y := board_rect.position.y + launch_margin if from_top else board_rect.end.y - launch_margin
	var center_x := board_rect.get_center().x
	for step in [0.0, -1.0, 1.0, -2.0, 2.0, -3.0, 3.0]:
		var spot := Vector2(center_x + step * 130.0, y)
		var clear := true
		for figure in all_figures():
			if figure.global_position.distance_to(spot) < figure.radius + 60.0 + 30.0:
				clear = false
		if clear:
			return spot
	return Vector2(center_x, y)


## Waits until every figure has stopped (and force-stops stragglers after max_settle_time).
func wait_until_settled() -> void:
	await get_tree().create_timer(settle_delay).timeout
	var waited := settle_delay
	while not _all_resting():
		if waited >= max_settle_time:
			push_warning("[minigame] settle forced after %.1fs" % waited)
			for figure in all_figures():
				figure.force_settle()
			break
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()


func _all_resting() -> bool:
	for figure in all_figures():
		if not figure.is_resting():
			return false
	return true


# --- Result ---------------------------------------------------------------------

## Shows the result panel. `title` is the big line, `lines` the details; `reward_text` is what you got.
## On a win the caller has already handed out money and set RunManager.reward_steps if there is an item;
## `has_item` sends Continue through the reward screen first.
func show_result(title: String, color: Color, lines: Array[String], has_item := false) -> void:
	if _finished:
		return
	_finished = true
	_flick_figure = null
	aim_line.clear()
	status_label.text = ""
	if has_item:
		_next_scene = REWARD_SCENE
	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	var insets := SafeArea.insets()
	panel.offset_left = 24.0 + insets.left
	panel.offset_right = -(24.0 + insets.right)
	panel.offset_bottom = -(24.0 + insets.bottom)
	panel.offset_top = -(24.0 + insets.bottom + 120.0 + 70.0 + 46.0 * lines.size() + 60.0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.09, 0.12, 0.96)
	box.set_border_width_all(4)
	box.border_color = color
	box.set_corner_radius_all(24)
	box.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 64)
	heading.add_theme_color_override("font_color", color)
	column.add_child(heading)
	for line in lines:
		var label := Label.new()
		label.text = line
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 34)
		column.add_child(label)
	var button := Button.new()
	button.text = "Continue"
	button.custom_minimum_size = Vector2(0.0, 100.0)
	button.add_theme_font_size_override("font_size", 42)
	button.pressed.connect(_continue)
	column.add_child(button)
	_result_layer.add_child(panel)
	overlay.queue_redraw()


func _continue() -> void:
	if _next_scene == MAP_SCENE:
		RunManager.finish_node()
	get_tree().change_scene_to_file(_next_scene)


# --- Rewards ---------------------------------------------------------------------

func config() -> MinigameConfig:
	var cfg: MinigameConfig = RunManager.config.minigames if RunManager.config != null else null
	return cfg if cfg != null else MinigameConfig.new()


## Pays `money` and, if `item_kind` is not empty, queues that reward step (the reward screen shows it
## after Continue). Returns the text for the result panel.
func give_reward(money: int, item_kind: String) -> String:
	RunManager.money += money
	var parts: Array[String] = []
	if money > 0:
		parts.append("$%d" % money)
	RunManager.reward_steps = []
	if item_kind != "":
		RunManager.reward_steps = [{"kind": item_kind}]
		parts.append({"power": "a power", "equipment": "an equipment item", "finish": "a toy finish"}.get(item_kind, "an item"))
	var text := "Reward: " + " and ".join(parts) if not parts.is_empty() else "No reward."
	RunManager.event_reward_text = text
	return text


## A plain FigureData for markers and props (the jack, bowling pins).
func make_data(display_name: String, short_label: String, color: Color, radius: float, mass: float) -> FigureData:
	var data := FigureData.new()
	data.display_name = display_name
	data.label = short_label
	data.color = color
	data.radius = radius
	data.mass = mass
	data.bounce = 0.7
	data.accuracy = 1.0
	return data
