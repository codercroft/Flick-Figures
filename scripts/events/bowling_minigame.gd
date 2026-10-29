class_name BowlingMinigame
extends Minigame
## Bowling (solo, never a penalty): ten small white pins stand in a triangle at the top of the table.
## You get two flicks with a Grunt (the ball leaves after each flick). A pin counts as knocked over once
## it has moved more than `moved_threshold` px from its spot or left the table. The prize grows with
## the pins (MinigameConfig); a strike or spare also gives a random power.

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
@export var flicks := 2
@export var ball_color := Color(0.3, 0.55, 1.0)

var _pins: Array[Figure] = []
var _starts: Array[Vector2] = []
var _down: Array[bool] = []


func _draw_overlay() -> void:
	# A faint ring where each knocked-over pin stood.
	for i in _pins.size():
		if _down[i]:
			overlay.draw_arc(_starts[i], pin_radius, 0.0, TAU, 24, Color(1.0, 0.4, 0.35, 0.8), 4.0, true)


func _run() -> void:
	_spawn_pins()
	status_label.text = "Knock down the pins!"
	await get_tree().create_timer(0.6).timeout
	var ball_data := colored_grunt(ball_color)
	var first_flick_down := 0
	for flick in flicks:
		var ball := spawn_figure(ball_data, Figure.Team.PLAYER, free_launch_point())
		await request_flick(ball, "Flick %d of %d: drag anywhere\nPins down: %d of %d" % [flick + 1, flicks, _count_down(), _pins.size()])
		await wait_until_settled()
		_update_down()
		overlay.queue_redraw()
		if flick == 0:
			first_flick_down = _count_down()
		# The ball rolls away so it does not block the next flick.
		figures_root.remove_child(ball)
		ball.queue_free()
		if _count_down() >= _pins.size():
			break
	_judge(first_flick_down)


func _spawn_pins() -> void:
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


func _judge(first_flick_down: int) -> void:
	var down := _count_down()
	var total := _pins.size()
	var title := "%d pin%s" % [down, "" if down == 1 else "s"]
	var color := Color.WHITE
	var clear := down >= total
	if clear:
		title = "Strike!" if first_flick_down >= total else "Spare!"
		color = Color(1.0, 0.82, 0.25)
	var table := config().bowling_money_by_pins
	var money: int = table[clampi(down, 0, table.size() - 1)] if not table.is_empty() else 0
	var kind := "power" if clear and config().bowling_power_on_clear else ""
	var reward := give_reward(money, kind)
	var lines: Array[String] = ["Pins knocked over: %d of %d" % [down, total], reward]
	show_result(title, color, lines, kind != "")
