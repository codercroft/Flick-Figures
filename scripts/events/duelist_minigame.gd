class_name DuelistMinigame
extends Minigame
## The Duelist: one of your figures against a rival copy of the same figure (no upgrades, finish or equipment) in a sumo duel on a
## small round platform (about 500 px across, open edges). Alternate flicks, you first. Knock the rival off to win your figure a free
## Upgrade step; if your figure falls it is Bruised (-20% flick power in the next combat). If nobody falls after
## `duel_max_flicks` each (or both fall) it is a draw.

@export var platform_color := Color(0.62, 0.55, 0.42)
@export var rival_think_time := 0.8
@export_range(0.0, 1.0) var rival_accuracy := 0.6
## Random error on the rival's power (0.05 = 5%).
@export var rival_power_error := 0.05

var _center := Vector2.ZERO
var _hero: Figure
var _rival: Figure
var _slot := 0


func _init() -> void:
	board_rect = Rect2(240, 560, 600, 600)  # (the camera frames this; the platform circle sits in the middle of it)


func _platform_radius() -> float:
	return config().duel_platform_diameter / 2.0


func _draw() -> void:
	_center = board_rect.get_center()
	draw_circle(_center, _platform_radius(), platform_color)
	draw_arc(_center, _platform_radius(), 0.0, TAU, 72, border_color, 8.0, true)


func _physics_process(_delta: float) -> void:
	for figure in all_figures():
		if figure.global_position.distance_to(board_rect.get_center()) > _platform_radius():
			on_fell(figure)


func _run() -> void:
	_slot = await pick_slot("Pick your duelist", "A sumo duel against a copy of it. Win: a free Upgrade. Lose: Bruised.")
	_center = board_rect.get_center()
	var offset := _platform_radius() * 0.55
	_hero = spawn_deck_figure(_slot, Figure.Team.PLAYER, _center + Vector2(0.0, offset))
	_rival = spawn_deck_figure(_slot, Figure.Team.ENEMY, _center + Vector2(0.0, -offset), true)
	await get_tree().create_timer(0.5).timeout
	for round_index in config().duel_max_flicks:
		await request_flick(_hero, "Your flick: push the rival off!")
		await wait_until_settled()
		if _check_end():
			return
		status_label.text = "The rival flicks..."
		await get_tree().create_timer(rival_think_time).timeout
		_rival_flick()
		await wait_until_settled()
		if _check_end():
			return
	_conclude(0)


func _check_end() -> bool:
	var hero_alive := alive(_hero)
	var rival_alive := alive(_rival)
	if hero_alive and rival_alive:
		return false
	_conclude(1 if hero_alive else (-1 if rival_alive else 0))
	return true


func _conclude(outcome: int) -> void:
	var fig_name: String = RunManager.deck[_slot].display_name
	if outcome > 0:
		RunManager.reward_steps = [{"kind": "upgrade", "slot": _slot}]
		RunManager.event_reward_text = "Reward: an Upgrade for %s" % fig_name
		show_result("You win!", Color(1.0, 0.82, 0.25), ["The rival %s is off the platform." % fig_name, RunManager.event_reward_text], true)
	elif outcome < 0:
		RunManager.reward_steps = []
		RunManager.event_reward_text = ""
		RunManager.bruise(_slot)
		show_result("You lose", Color(1.0, 0.4, 0.35), ["%s fell off the platform." % fig_name, "%s is Bruised: -20%% flick power in the next combat." % fig_name])
	else:
		RunManager.reward_steps = []
		RunManager.event_reward_text = ""
		show_result("Draw", Color.WHITE, ["Nobody won: no reward and no penalty."])


## The rival aims at your figure with a power that should slide it past the edge (with aim and power error).
func _rival_flick() -> void:
	var to_hero := _hero.global_position - _rival.global_position
	var distance := to_hero.length()
	var direction := to_hero.normalized()
	# How far the hero must slide to leave the platform along this line, and the speed that takes.
	var edge := _platform_radius()
	var along := (_hero.global_position - _center).dot(direction)
	var to_edge := maxf(sqrt(maxf(edge * edge - (_hero.global_position - _center).length_squared() + along * along, 0.0)) - along, 20.0)
	var hero_speed := to_edge * _hero.linear_damp + stop_speed + 40.0
	var share := (1.0 + _rival.data.bounce * 0.5) * _rival.mass / (_rival.mass + _hero.mass)
	var contact := hero_speed / maxf(share, 0.2)
	var launch_speed := contact + _rival.linear_damp * distance
	var impulse := launch_speed * _rival.mass
	var full := full_force(_rival)
	impulse = clampf(impulse * randf_range(1.0 - rival_power_error, 1.0 + rival_power_error), full * 0.15, full)
	var error := deg_to_rad(randf_range(-1.0, 1.0) * (1.0 - rival_accuracy) * 20.0)
	_rival.launch(direction.rotated(error) * impulse)
