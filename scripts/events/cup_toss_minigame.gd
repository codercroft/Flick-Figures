class_name CupTossMinigame
extends Minigame
## Cup Toss: three cups on an open table (near, middle, far). One flick of a small ball (radius 24). A ball that comes to rest
## inside a cup wins that cup's prize (MinigameConfig.cup_rewards: near = a power, middle = equipment, far = a relic); a miss
## pays `cup_miss_money`. No penalty.

@export var ball_color := Color(0.95, 0.95, 0.9)
@export var ball_mass := 1.0
## Cup centers as fractions of the table: x from the left, y from the top (near, middle, far).
@export var cup_positions: Array[Vector2] = [Vector2(0.28, 0.62), Vector2(0.72, 0.42), Vector2(0.5, 0.14)]
@export var cup_colors: Array[Color] = [Color(0.4, 0.75, 0.45), Color(0.95, 0.75, 0.25), Color(0.85, 0.35, 0.35)]

var _ball: Figure


func cup_center(index: int) -> Vector2:
	return board_rect.position + board_rect.size * cup_positions[index]


## Which cup (0 near, 1 middle, 2 far) a ball resting at `point` is in, or -1.
func cup_at(point: Vector2) -> int:
	for i in cup_positions.size():
		if point.distance_to(cup_center(i)) <= config().cup_radius:
			return i
	return -1


func _run() -> void:
	var data := make_data("Ball", "", ball_color, config().cup_ball_radius, ball_mass)
	_ball = spawn_figure(data, Figure.Team.PLAYER, Vector2(board_rect.get_center().x, board_rect.end.y - launch_margin))
	await request_flick(_ball, "One flick: land the ball in a cup!")
	await wait_until_settled()
	var cup := cup_at(_ball.global_position) if alive(_ball) else -1
	var cfg := config()
	if cup < 0:
		RunManager.money += cfg.cup_miss_money
		RunManager.reward_steps = []
		RunManager.event_reward_text = "Reward: $%d" % cfg.cup_miss_money
		show_result("Missed", Color.WHITE, ["The ball did not stop in a cup.", "Consolation: $%d." % cfg.cup_miss_money])
		return
	var kind: String = cfg.cup_rewards[cup]
	RunManager.reward_steps = [{"kind": kind}]
	var prize: String = {"power": "a power", "equipment": "an equipment item", "relic": "a relic"}.get(kind, kind)
	RunManager.event_reward_text = "Reward: " + prize
	show_result("In the cup!", Color(1.0, 0.82, 0.25), ["The %s cup wins %s." % [["near", "middle", "far"][cup], prize]], true)


func _draw_table() -> void:
	var names := ["NEAR", "MIDDLE", "FAR"]
	var cfg := config()
	for i in cup_positions.size():
		var center := cup_center(i)
		draw_circle(center, cfg.cup_radius, cup_colors[i].darkened(0.55))
		draw_circle(center, cfg.cup_radius - 10.0, cup_colors[i].darkened(0.25))
		draw_arc(center, cfg.cup_radius, 0.0, TAU, 40, cup_colors[i], 6.0, true)
		var prize: String = {"power": "POWER", "equipment": "GEAR", "relic": "RELIC"}.get(cfg.cup_rewards[i], "")
		draw_string(ThemeDB.fallback_font, center + Vector2(-90.0, -cfg.cup_radius - 12.0), "%s: %s" % [names[i], prize], HORIZONTAL_ALIGNMENT_CENTER, 180.0, 28, Color(0.2, 0.12, 0.05))
