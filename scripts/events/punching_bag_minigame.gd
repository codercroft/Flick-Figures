class_name PunchingBagMinigame
extends Minigame
## Punching Bag: ONE flick with ONE figure of your choice (its upgrades, finish and equipment apply) at a heavy bag held in the
## middle of an open table by a spring. The score comes from the bag's momentum right after the hit, scaled so that
## a full-power Grunt hit is about 33 points (three of them = 100). A strength meter fills up to the score. Rewards are cumulative
## (MinigameConfig.bag_thresholds / bag_rewards): 25 equipment, 50 + a power, 75 + a finish, 100 + an Upgrade. No penalty.

@export_group("Bag")
@export var bag_radius := 95.0
@export var bag_mass := 12.0
## Spring pull back to the middle (1/s^2) and its damping (1/s): the bag slides when hit and returns.
@export var spring_strength := 16.0
@export var spring_damping := 5.0
@export var bag_color := Color(0.75, 0.2, 0.2)
## Seconds the bag's momentum is watched after the flick.
@export var measure_seconds := 4.0
## Seconds the meter takes to fill.
@export var meter_seconds := 1.6

var bag: Figure
var _hero: Figure
var _peak := 0.0
var _measuring := false
var _meter := 0.0
var _meter_max := 100.0
var _score := 0
var _showing_meter := false


func _run() -> void:
	var slot := await pick_slot("Pick your puncher", "One flick. Hit the bag as hard as you can.")
	var center := board_rect.get_center()
	bag = spawn_figure(make_data("Punching Bag", "BAG", bag_color, bag_radius, bag_mass), Figure.Team.ENEMY, center)
	bag.on_deck = false
	_hero = spawn_deck_figure(slot, Figure.Team.PLAYER, Vector2(center.x, board_rect.end.y - launch_margin))
	_showing_meter = true
	await request_flick(_hero, "Drag back and let go: hit the bag hard!")
	_measuring = true
	var waited := 0.0
	while waited < measure_seconds:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	await wait_until_settled()
	_measuring = false
	_score = score_for(bag.mass * _peak, config().bag_grunt_momentum, config().bag_grunt_score)
	var tween := create_tween()
	tween.tween_property(self, "_meter", float(_score), meter_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	_finish_with_rewards()


## Points for a bag momentum (a full Grunt hit's momentum scores `grunt_score`).
static func score_for(momentum: float, grunt_momentum: float, grunt_score: float) -> int:
	return roundi(grunt_score * momentum / maxf(grunt_momentum, 1.0))


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not alive(bag):
		return
	var offset := bag.global_position - board_rect.get_center()
	bag.apply_central_force(-(offset * spring_strength + bag.linear_velocity * spring_damping) * bag.mass)
	if _measuring:
		_peak = maxf(_peak, bag.linear_velocity.length())


func _process(_delta: float) -> void:
	if _showing_meter:
		overlay.queue_redraw()


func _finish_with_rewards() -> void:
	var cfg := config()
	var steps: Array[Dictionary] = []
	var names: Array[String] = []
	for i in cfg.bag_thresholds.size():
		if _score >= cfg.bag_thresholds[i]:
			steps.append({"kind": cfg.bag_rewards[i]})
			names.append({"equipment": "equipment", "power": "a power", "finish": "a finish", "upgrade": "an Upgrade"}.get(cfg.bag_rewards[i], cfg.bag_rewards[i]))
	RunManager.reward_steps = steps
	var lines: Array[String] = ["Score: %d" % _score]
	if steps.is_empty():
		RunManager.event_reward_text = ""
		lines.append("Not enough for a prize (%d needed)." % cfg.bag_thresholds[0])
	else:
		RunManager.event_reward_text = "Reward: " + ", ".join(names)
		lines.append(RunManager.event_reward_text)
	show_result("%d points!" % _score, Color(1.0, 0.82, 0.25) if not steps.is_empty() else Color.WHITE, lines, not steps.is_empty())


func _draw_table() -> void:
	draw_circle(board_rect.get_center(), 30.0, Color(0, 0, 0, 0.18))  # the spring's anchor


func _draw_overlay() -> void:
	if not _showing_meter:
		return
	var cfg := config()
	var bar := Rect2(board_rect.position.x + 60.0, board_rect.position.y + 24.0, board_rect.size.x - 120.0, 56.0)
	overlay.draw_rect(bar, Color(0.08, 0.09, 0.12, 0.9))
	var fraction := clampf(_meter / _meter_max, 0.0, 1.0)
	var color := Color(0.4, 0.8, 0.4).lerp(Color(1.0, 0.3, 0.2), fraction)
	overlay.draw_rect(Rect2(bar.position, Vector2(bar.size.x * fraction, bar.size.y)), color)
	overlay.draw_rect(bar, Color.WHITE, false, 4.0)
	var font := ThemeDB.fallback_font
	for threshold in cfg.bag_thresholds:
		var x: float = bar.position.x + bar.size.x * clampf(threshold / _meter_max, 0.0, 1.0)
		overlay.draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y + 10.0), Color.WHITE, 3.0)
		overlay.draw_string(font, Vector2(x - 24.0, bar.end.y + 44.0), str(threshold), HORIZONTAL_ALIGNMENT_CENTER, 48.0, 30, Color.WHITE)
	overlay.draw_string(font, Vector2(bar.position.x + 12.0, bar.position.y + 42.0), str(roundi(_meter)), HORIZONTAL_ALIGNMENT_LEFT, 200.0, 40, Color.WHITE)
