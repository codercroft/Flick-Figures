class_name KingOfTheHillMinigame
extends Minigame
## King of the Hill: a marked zone in the middle of an open table. You pick 3 of your figures and they start in the zone. Grunts
## arrive over three enemy turns (2, then 3, then 4: MinigameConfig.hill_grunts) and each flicks at your figures; you flick one
## figure between the enemy turns. After the third enemy turn the figures still inside the zone decide the prize: 1 = $5,
## 2 = + equipment, 3 = + a finish. Nothing is lost from your deck; no penalty.

@export var zone_color := Color(0.95, 0.85, 0.3, 0.28)
@export var enemy_color := Color(0.95, 0.5, 0.15)
@export var grunt_gap := 0.35
## Extra speed (px/s) the Grunts have when they reach your figures (bigger = harder shoves).
@export var grunt_extra_speed := 300.0
@export_range(0.0, 1.0) var grunt_accuracy := 0.6

var _mine: Array[Figure] = []
var _zone_center := Vector2.ZERO


func _zone_radius() -> float:
	return config().hill_zone_radius


func figures_in_zone() -> int:
	var count := 0
	for figure in _mine:
		if alive(figure) and figure.global_position.distance_to(_zone_center) <= _zone_radius():
			count += 1
	return count


func _run() -> void:
	_zone_center = board_rect.get_center()
	var slots: Array[int] = []
	var wanted := mini(3, RunManager.deck.size())
	if RunManager.deck.size() <= 3:
		for i in RunManager.deck.size():
			slots.append(i)
	else:
		while slots.size() < wanted:
			var left: Array[int] = []
			for i in RunManager.deck.size():
				if not slots.has(i):
					left.append(i)
			slots.append(await pick_slot("Pick figure %d of %d" % [slots.size() + 1, wanted], "They start in the zone.", left))
	for i in slots.size():
		var angle := -PI / 2.0 + TAU * i / slots.size()
		var pos := _zone_center + Vector2.from_angle(angle) * (_zone_radius() * 0.45 if slots.size() > 1 else 0.0)
		_mine.append(spawn_deck_figure(slots[i], Figure.Team.PLAYER, pos))
	var turns: Array[int] = config().hill_grunts
	for turn in turns.size():
		status_label.text = "Enemy turn %d: %d Grunts arrive!" % [turn + 1, turns[turn]]
		await get_tree().create_timer(0.6).timeout
		await _enemy_turn(turns[turn])
		if turn < turns.size() - 1:
			var living: Array[Figure] = []
			for figure in _mine:
				if alive(figure):
					living.append(figure)
			if not living.is_empty():
				await request_flick_from(living, "Your flick: tap a figure, then drag. Hold the zone!")
				await wait_until_settled()
	_finish()


func _enemy_turn(count: int) -> void:
	var data := colored_grunt(enemy_color)
	var grunts: Array[Figure] = []
	var offset := randf() * TAU
	for i in count:
		# They arrive from all around the table (evenly spread, random start angle) so the shoves do not all push one way.
		var angle := offset + TAU * i / count
		var pos := board_rect.get_center() + Vector2(cos(angle) * (board_rect.size.x / 2.0 - 70.0), sin(angle) * (board_rect.size.y / 2.0 - 70.0))
		grunts.append(spawn_figure(data, Figure.Team.ENEMY, pos))
	await get_tree().create_timer(0.5).timeout
	for grunt in grunts:
		var target := _nearest_mine(grunt.global_position)
		if target == null or not alive(grunt):
			continue
		var to := target.global_position - grunt.global_position
		var speed := to.length() * grunt.linear_damp + stop_speed + grunt_extra_speed
		var impulse := minf(speed * grunt.mass, full_force(grunt))
		var error := deg_to_rad(randf_range(-1.0, 1.0) * (1.0 - grunt_accuracy) * 20.0)
		grunt.launch(to.normalized().rotated(error) * impulse)
		await get_tree().create_timer(grunt_gap).timeout
	await wait_until_settled()


func _nearest_mine(from: Vector2) -> Figure:
	var best: Figure = null
	for figure in _mine:
		if alive(figure) and (best == null or figure.global_position.distance_to(from) < best.global_position.distance_to(from)):
			best = figure
	return best


func _finish() -> void:
	var cfg := config()
	var count := figures_in_zone()
	var steps: Array[Dictionary] = []
	var parts: Array[String] = []
	if count >= 1:
		RunManager.money += cfg.hill_money
		parts.append("$%d" % cfg.hill_money)
	for i in clampi(count - 1, 0, cfg.hill_items.size()):
		steps.append({"kind": cfg.hill_items[i]})
		parts.append({"equipment": "equipment", "finish": "a finish", "power": "a power", "upgrade": "an Upgrade"}.get(cfg.hill_items[i], cfg.hill_items[i]))
	RunManager.reward_steps = steps
	RunManager.event_reward_text = "Reward: " + ", ".join(parts) if not parts.is_empty() else ""
	var lines: Array[String] = ["%d figure(s) held the zone." % count]
	lines.append(RunManager.event_reward_text if not parts.is_empty() else "No prize.")
	show_result("%d in the zone" % count, Color(1.0, 0.82, 0.25) if count > 0 else Color.WHITE, lines, not steps.is_empty())


func _draw_table() -> void:
	var center := board_rect.get_center()
	draw_circle(center, config().hill_zone_radius, zone_color)
	draw_arc(center, config().hill_zone_radius, 0.0, TAU, 64, Color(0.9, 0.7, 0.1), 8.0, true)
	draw_string(ThemeDB.fallback_font, center + Vector2(-150.0, -config().hill_zone_radius - 18.0), "HOLD THE ZONE", HORIZONTAL_ALIGNMENT_CENTER, 300.0, 34, Color(0.45, 0.3, 0.05))
