class_name BowlingMinigame
extends Minigame
## Bowling against the AI: ten small white pins stand in a triangle at the top of the table. There are
## `rounds` rounds. In each, you flick a heavy, slow ball twice at the pins; then the pins reset and the
## AI flicks twice; then they reset again. A pin counts as knocked over once it has moved more than
## `moved_threshold` px from its spot or left the table. After the last round the higher total wins
## (a tie goes to you). A win pays money plus a random item; a loss makes the next fight harder.

@export_group("Match")
@export var rounds := 3
## Flicks each side takes per round.
@export var flicks := 2
@export var player_color := Color(0.3, 0.55, 1.0)
@export var opponent_color := Color(0.95, 0.5, 0.15)

@export_group("Ball")
## The ball is a Grunt this many times heavier than normal...
@export var ball_mass_multiplier := 1.6
## ...with this flick power (a normal Grunt is 1.0). Its launch speed is 2400 x power / mass multiplier,
## so the defaults give about 1200 px/s: a full pull rolls roughly 790 px, enough to reach the back pins.
@export var ball_flick_power := 0.8

@export_group("Pins")
@export var pin_radius := 28.0
@export var pin_mass := 0.45
## Distance between neighbouring pin centers in a row.
@export var pin_spacing := 78.0
## Rows from the back: 4 pins, 3, 2, 1 = ten.
@export var pin_rows := 4
## The back row is this far (px) below the top edge of the table.
@export var pin_top_margin := 150.0
## A pin that moves farther than this (px) counts as knocked over.
@export var moved_threshold := 30.0
## Seconds the result of a turn is shown before the pins reset.
@export var reset_pause := 1.4

@export_group("Opponent")
## How near (px) a pin must be to a predicted slide path for the AI to expect it to be knocked over.
@export var ai_chain_reach := 70.0
## Value of a pin the AI expects to hit directly, to knock into others, and to be swept by the ball.
@export var ai_hit_value := 1.0
@export var ai_chain_value := 0.8
@export var ai_sweep_value := 0.6

var ai := MinigameAI.new()
var _pins: Array[Figure] = []
var _starts: Array[Vector2] = []
var _down: Array[bool] = []
var _scores := {Figure.Team.PLAYER: [], Figure.Team.ENEMY: []}  # pins down per round
var _cells: Array[Label] = []  # the scoreboard (3 rows x (rounds + 2) columns)


func _draw_overlay() -> void:
	# A faint ring where each knocked-over pin stood.
	for i in _pins.size():
		if _down[i]:
			overlay.draw_arc(_starts[i], pin_radius, 0.0, TAU, 24, Color(1.0, 0.4, 0.35, 0.8), 4.0, true)


func _run() -> void:
	ai.name = "AI"
	ai.power_step = 0.04
	add_child(ai)
	_build_scoreboard()
	var player_data := _ball_data(player_color)
	var opponent_data := _ball_data(opponent_color)
	for round_number in rounds:
		for team in [Figure.Team.PLAYER, Figure.Team.ENEMY]:
			_reset_pins()
			var mine: bool = team == Figure.Team.PLAYER
			var who := "Your" if mine else "Opponent's"
			status_label.text = "Round %d of %d: %s turn" % [round_number + 1, rounds, who.to_lower()]
			await get_tree().create_timer(0.6).timeout
			for flick in flicks:
				var ball := spawn_figure(player_data if mine else opponent_data, team, free_launch_point())
				if mine:
					await request_flick(ball, "Round %d: your flick %d of %d\nPins down: %d" % [round_number + 1, flick + 1, flicks, _count_down()])
				else:
					await _opponent_flick(ball)
				await wait_until_settled()
				_update_down()
				overlay.queue_redraw()
				figures_root.remove_child(ball)  # the ball rolls away so it does not block the next flick
				ball.queue_free()
				if _count_down() >= _pins.size():
					break
			_scores[team].append(_count_down())
			_update_scoreboard()
			status_label.text = "%s pins: %d" % [who, _count_down()]
			await get_tree().create_timer(reset_pause).timeout
	_judge()


func _ball_data(color: Color) -> FigureData:
	var data := colored_grunt(color)
	data.mass *= ball_mass_multiplier
	data.flick_power_multiplier = ball_flick_power
	return data


# --- Pins -------------------------------------------------------------------------

## Stands up a fresh set of ten pins (the old ones, standing or not, are removed).
func _reset_pins() -> void:
	for pin in _pins:
		if is_instance_valid(pin):
			if pin.get_parent() != null:
				pin.get_parent().remove_child(pin)
			pin.queue_free()
	_pins.clear()
	_starts.clear()
	_down.clear()
	var data := make_data("Pin", "", Color.WHITE, pin_radius, pin_mass)
	var row_height := pin_spacing * 0.866
	for k in pin_rows:
		var count := pin_rows - k
		var y := board_rect.position.y + pin_top_margin + k * row_height
		for i in count:
			var x := board_rect.get_center().x + (i - (count - 1) / 2.0) * pin_spacing
			var pin := spawn_figure(data, Figure.Team.ENEMY, Vector2(x, y))
			_pins.append(pin)
			_starts.append(pin.position)
			_down.append(false)
	overlay.queue_redraw()


func _update_down() -> void:
	for i in _pins.size():
		if _down[i]:
			continue  # once down, always down
		if not alive(_pins[i]) or _pins[i].global_position.distance_to(_starts[i]) > moved_threshold:
			_down[i] = true


func _count_down() -> int:
	var count := 0
	for knocked in _down:
		if knocked:
			count += 1
	return count


# --- The opponent -------------------------------------------------------------------

func _opponent_flick(ball: Figure) -> void:
	status_label.text = "Opponent's flick..."
	await get_tree().physics_frame  # let the physics server know the new body before casting shots
	await get_tree().physics_frame
	await get_tree().create_timer(config().ai_think_time).timeout
	var points: Array[Vector2] = []
	var standing := Vector2.ZERO
	for i in _pins.size():
		if not _down[i] and alive(_pins[i]):
			points.append(_pins[i].global_position)
			standing += _pins[i].global_position
	if points.is_empty():
		points.append(board_rect.get_center())
	else:
		points.append(standing / points.size())
	var impulse := ai.choose(ball, board_rect, full_force(ball), points, _score_shot, config().ai_accuracy,
			config().ai_power_error)
	if impulse == Vector2.ZERO:
		impulse = Vector2.UP * full_force(ball) * 0.6
	ball.launch(impulse)


## How many pins a predicted flick should knock over: the pin it hits, the pins that pin slides into,
## and the pins the ball itself sweeps after the hit (rough, but it favors hitting the cluster head on).
func _score_shot(moved: Dictionary) -> float:
	var score := 0.0
	var ball_end := Vector2.INF
	var hit_from := Vector2.INF
	for i in _pins.size():
		if not alive(_pins[i]) or not moved.has(_pins[i]):
			continue
		hit_from = _pins[i].global_position
		var end: Vector2 = moved[_pins[i]]
		if not _down[i]:
			score += ai_hit_value
		if end == Vector2.INF:
			end = hit_from + Vector2.UP * 500.0
		for j in _pins.size():
			if j != i and not _down[j] and alive(_pins[j]) and not moved.has(_pins[j]):
				var closest := Geometry2D.get_closest_point_to_segment(_pins[j].global_position, hit_from, end)
				if closest.distance_to(_pins[j].global_position) <= ai_chain_reach:
					score += ai_chain_value
	for figure in moved:
		if figure.data.display_name != "Pin" and hit_from != Vector2.INF and moved[figure] != Vector2.INF:
			ball_end = moved[figure]
	if ball_end != Vector2.INF:
		for j in _pins.size():
			if not _down[j] and alive(_pins[j]) and not moved.has(_pins[j]):
				var closest := Geometry2D.get_closest_point_to_segment(_pins[j].global_position, hit_from, ball_end)
				if closest.distance_to(_pins[j].global_position) <= ai_chain_reach * 0.8:
					score += ai_sweep_value
	return score


# --- Scoreboard and result -------------------------------------------------------------

## A small table under the status bar: a row per side, a column per round, then the total.
func _build_scoreboard() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_top = TopBar.height() + 10.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.09, 0.12, 0.9)
	box.set_corner_radius_all(14)
	box.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grid := GridContainer.new()
	grid.columns = rounds + 2
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 4)
	panel.add_child(grid)
	var header: Array[String] = [""]
	for r in rounds:
		header.append("R%d" % (r + 1))
	header.append("Total")
	var rows: Array = [header, ["You"], ["Opp."]]
	for row in 3:
		for column in rounds + 2:
			var label := Label.new()
			label.add_theme_font_size_override("font_size", 32)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.text = rows[row][column] if column < rows[row].size() else "-"
			if row == 1:
				label.add_theme_color_override("font_color", player_color.lightened(0.3))
			elif row == 2:
				label.add_theme_color_override("font_color", opponent_color.lightened(0.2))
			grid.add_child(label)
			_cells.append(label)
	layer.add_child(panel)


func _update_scoreboard() -> void:
	var columns := rounds + 2
	for row in 2:
		var team: Figure.Team = Figure.Team.PLAYER if row == 0 else Figure.Team.ENEMY
		var list: Array = _scores[team]
		var total := 0
		for r in rounds:
			_cells[(row + 1) * columns + 1 + r].text = str(list[r]) if r < list.size() else "-"
			if r < list.size():
				total += list[r]
		_cells[(row + 1) * columns + columns - 1].text = str(total)


func _total(team: Figure.Team) -> int:
	var total := 0
	for pins in _scores[team]:
		total += pins
	return total


func _judge() -> void:
	var mine := _total(Figure.Team.PLAYER)
	var theirs := _total(Figure.Team.ENEMY)
	var lines: Array[String] = ["Total pins: you %d, opponent %d" % [mine, theirs]]
	if mine == theirs:
		lines.append("A tie goes to you.")
	conclude_contest(1 if mine >= theirs else -1, lines)
