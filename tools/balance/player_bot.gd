extends RefCounted
## PlayerBot: plays the PLAYER side of a combat for the balance sims (tools only; the game never loads this file).
## It asks the enemy AI's own shot evaluation (EnemyAI.choose_flick) for the best shot, mirrored for the player's side,
## at the elite search depth and with a normal aim error, then performs it through the same Main functions a touch uses
## (press, drag, release, taps), so every rule of the real player turn applies. Abilities are used the way the AI already
## understands them: Blastoid / Cluster tap shots, Spitter sprays, Pinhead pins, Engineer turrets, Alchemist zones, tap
## abilities (Magnet, Absorber, Ghost teleport), bonus flicks and a few powers.
##
## It is a plain RefCounted driven by FightRunner: when the combat is waiting for the player (`Main._state == 0`) the
## runner calls take_turn() (a coroutine); `busy` is true until it finishes.

## How accurate its aim is (1 = perfect, 0 = the widest error). The enemy figures use their own `accuracy`.
var accuracy := 0.85
## Search tier of its shot evaluation: 1 regular, 2 elite (default), 3 boss.
var search_tier := 2
## Use the powers it holds (Super Flick, Extra Turn, Bomb Drop, Freeze Ray, Shrink Ray, Rewind). Others are never used.
var use_powers := true
## Rewind is only used when a figure was lost in the last enemy turn.
var busy := false
var stats := {"turns": 0, "no_enemy_flicks": 0, "powers_used": 0, "fallback_flicks": 0, "skipped_bonus": 0, "bonus_flicks": 0, "taps": 0, "sprays": 0, "pins": 0, "turrets": 0, "zones": 0}

var where := ""  # what it was doing last (shown when a fight gets stuck)
var main  # the Main node of the combat
var tree: SceneTree
var run
var _lost_before := 0


func _init(combat) -> void:
	main = combat
	tree = combat.get_tree()
	run = tree.root.get_node("RunManager")
	_lost_before = main._figures_lost


## One look at the board when it is the player's move. Does nothing if the state is not PLAYER_TURN.
func take_turn() -> void:
	busy = true
	await _turn()
	busy = false


func _turn() -> void:
	if not is_instance_valid(main) or main._state != 0:
		return
	stats.turns += 1
	where = "start of turn"
	if main._power_slot >= 0:
		main._cancel_power()
	if main._bonus_figure != null:
		await _bonus_window()
		return
	where = "powers"
	await _use_powers()
	if not _can_act():
		return
	where = "tap abilities"
	_tap_abilities()
	await tree.physics_frame
	if not _can_act():
		return
	where = "placements"
	_place_turrets()
	if await _place_zone():
		return  # an Alchemist's zone was its action; the turn goes on from the settle
	var excluded: Array = []
	for attempt in 4:  # (a pin or a spray-only choice does not end the turn: look again without that figure's trick)
		await tree.physics_frame
		if not _can_act():
			return
		var candidates := _candidates(excluded)
		if candidates.is_empty():
			break
		var choice := _choose(candidates, -INF)
		if choice.is_empty():
			break
		where = "executing %s" % str(choice.keys())
		var done := await _execute(choice, excluded)
		if done or not _can_act():
			return
	await _fallback_flick()


## True while the combat is still waiting for the player's move.
func _can_act() -> bool:
	return is_instance_valid(main) and main._state == 0


# --- Choosing --------------------------------------------------------------------------------------------------------

func _candidates(excluded: Array) -> Array:
	var able: Array = []
	for figure in main._players:
		if main._is_alive(figure) and figure.flickable and figure.data.can_flick and not figure.is_frozen() \
				and figure.stunned_rounds == 0 and not excluded.has(figure):
			able.append(figure)
	return able


## The AI's best shot for these shooters (mirrored: the opponents are the enemy figures).
func _choose(shooters: Array, min_score: float) -> Dictionary:
	var ai = main.ai
	var saved_accuracy: float = ai.accuracy_override
	var saved_tier: int = ai.tier_override
	ai.accuracy_override = accuracy
	ai.tier_override = search_tier
	var max_force: float = main.max_flick_force * main.flick_boost * run.relic_flick_multiplier(main, shooters[0])
	var choice: Dictionary = ai.choose_flick(shooters, main._enemies, main.board.get_table_rect(), max_force, min_score)
	ai.accuracy_override = saved_accuracy
	ai.tier_override = saved_tier
	return choice


## Performs a choice. Returns true when it used up the turn's action (the combat is now settling).
func _execute(choice: Dictionary, excluded: Array) -> bool:
	var figure = choice.enemy  # (the key is named after the enemy AI's own use of it)
	if not main._is_alive(figure):
		return false
	if choice.has("pin_only"):
		_put_pin(figure, choice)
		excluded.append(figure)  # (a pin costs a player figure nothing: it can still flick, so look again)
		excluded.clear()
		return false
	if choice.has("pin") and choice.has("impulse"):
		_put_pin(figure, choice)
	if choice.has("spray_point"):
		stats.sprays += 1
		await main._enemy_spray(figure, choice.spray_point, choice.spray_seconds)
		if not main._is_alive(figure):
			return false
		if not (choice.has("impulse") or choice.has("shot_point")):
			excluded.append(figure)  # spray only: spraying does not use the action, so another figure (or a plain flick) goes now
			return false
	if choice.has("shot_point"):
		if _select(figure):
			stats.taps += 1
			_tap_point(choice.shot_point)
			return main._state != 0
		return false
	if choice.has("impulse"):
		return _flick(figure, choice.impulse)
	return false


func _put_pin(figure, choice: Dictionary) -> void:
	if figure.placed_this_turn or not _select(figure):
		return
	if main.arena.place_temp_pin(figure, choice.pin, choice.pin_radius, main.board.board_rect, figure.ability.get_pin_options(figure)):
		figure.placed_this_turn = true
		stats.pins += 1


## Presses on `figure` (so it is selected) and lets go without dragging. A touch picks the nearest flickable figure under
## the finger, so where figures overlap the press moves a little until it lands on the intended one.
func _select(figure) -> bool:
	var spot := _press_spot(figure)
	if spot == Vector2.INF:
		return false
	main._on_press(0, spot)
	main._release_aim(spot)
	return main._selected == figure


func _press_spot(figure) -> Vector2:
	var center: Vector2 = figure.global_position
	if main._player_figure_at(center, true) == figure:
		return center
	for ring in [0.45, 0.8]:
		for k in 8:
			var spot: Vector2 = center + Vector2.from_angle(TAU * k / 8.0) * figure.radius * ring
			if main._player_figure_at(spot, true) == figure:
				return spot
	return Vector2.INF


## A drag that gives `figure` exactly this impulse (the inverse of Main._flick_impulse).
func _flick(figure, impulse: Vector2) -> bool:
	var spot := _press_spot(figure)
	if spot == Vector2.INF:
		return false
	main._on_press(0, spot)
	if main._state != 1 or main._aim_figure != figure:  # (a Bummer takes the flick over, or the touch picked something else)
		if main._state == 1:
			main._cancel_aim()
		return main._state != 0
	var full_force: float = main.max_flick_force * figure.data.flick_power_multiplier * main.flick_boost \
			* figure.ability.get_flick_power_multiplier(figure) * figure.aura_flick_multiplier() * run.relic_flick_multiplier(main, figure)
	var max_pull: float = main.get_viewport_rect().size.x * main.max_pull_fraction
	var pull := maxf(clampf(impulse.length() / full_force, 0.0, 1.0) * max_pull, main.min_pull_distance + 1.0)
	var pos: Vector2 = spot - impulse.normalized() * pull
	main._update_aim(pos)
	main._release_aim(pos)
	return main._state != 0


## A tap on empty board with the (already selected) figure.
func _tap_point(point: Vector2) -> void:
	main._on_press(0, point)
	main._release_aim(point)


## Nothing was worth doing: a player must still flick, so the first figure that can nudges toward the nearest enemy.
func _fallback_flick() -> void:
	if not _can_act():
		return
	stats.fallback_flicks += 1
	var candidates := _candidates([])
	if candidates.is_empty():
		candidates = main._players.filter(func(f): return main._is_alive(f) and f.flickable)
	for figure in candidates:
		var target = _nearest_enemy(figure.global_position)
		# (no enemy left but the fight is not over yet: any flick lets the game notice)
		if target == null:
			stats.no_enemy_flicks += 1
		var dir: Vector2 = Vector2.UP if target == null else (target.global_position - figure.global_position).normalized()
		var speed: float = 600.0 * figure.data.flick_power_multiplier
		if _flick(figure, dir * speed * figure.mass):
			return
	# Last resort: tap the first figure that can act so the game does not wait forever.
	if main._bonus_figure != null:
		main._skip_bonus_flick()


func _nearest_enemy(from: Vector2):
	var best = null
	var best_d := INF
	for enemy in main._enemies:
		if main._is_alive(enemy) and enemy.global_position.distance_to(from) < best_d:
			best = enemy
			best_d = enemy.global_position.distance_to(from)
	return best


# --- Bonus flicks (Speedo, Bloodluster, Jet Pack...) -------------------------------------------------------------------

func _bonus_window() -> void:
	var figure = main._bonus_figure
	if main._bonus_mode != "flick" or not main._is_alive(figure):
		stats.skipped_bonus += 1
		main._skip_bonus_flick()  # (spray / toss windows: the bot is done with that figure)
		return
	await tree.physics_frame
	if not main._is_alive(figure) or main._state != 0:
		return
	var choice := _choose([figure], main.ai.bonus_flick_min_score)
	if choice.is_empty() or not choice.has("impulse"):
		stats.skipped_bonus += 1
		main._skip_bonus_flick()
		return
	stats.bonus_flicks += 1
	if not _flick(figure, choice.impulse):
		main._skip_bonus_flick()


# --- Tap abilities, placements ----------------------------------------------------------------------------------------

## Magnet's push / implode, Absorber's spit, Ghost's teleport (the same decisions the enemy side makes at the start of its turn).
func _tap_abilities() -> void:
	var opponents: Array = []
	for enemy in main._enemies:
		if main._is_alive(enemy):
			opponents.append(enemy)
	for figure in main._players:
		if not main._is_alive(figure):
			continue
		var tap: Dictionary = figure.ability.get_tap_ability(figure)
		if tap.is_empty() or not tap.ready:
			continue
		if tap.kind == "self" and figure.ability.ai_wants_tap(figure, opponents):
			if _select(figure):
				stats.taps += 1
				main._try_self_tap(figure)
		elif tap.kind == "point":
			var point: Vector2 = figure.ability.ai_tap_point(figure, opponents)
			if point != Vector2.INF and _select(figure):
				stats.taps += 1
				_tap_point(point)
		if main._state != 0:
			return


func _place_turrets() -> void:
	for figure in main._players:
		if not main._is_alive(figure) or figure.placed_this_turn or not figure.flickable:
			continue
		var turret: Dictionary = figure.ability.get_turret_stats(figure)
		if turret.is_empty():
			continue
		var spot: Vector2 = main.ai.choose_turret_spot(figure, main._enemies, main._players, turret, main.arena, main.board.board_rect, main.board.get_table_rect())
		if spot != Vector2.INF and _select(figure):
			stats.turrets += 1
			_tap_point(spot)


## An Alchemist's zone is its whole action. True if one was placed (the turn is now settling).
func _place_zone() -> bool:
	for figure in main._players:
		if not main._is_alive(figure) or figure.placed_this_turn or not figure.flickable:
			continue
		if figure.ability.get_zone_stats(figure).is_empty():
			continue
		var spot: Vector2 = main.ai.choose_zone_spot(figure, main._enemies)
		if spot != Vector2.INF and _select(figure):
			stats.zones += 1
			_tap_point(spot)
			if main._state != 0:
				return true
	return false


# --- Powers ----------------------------------------------------------------------------------------------------------

func _use_powers() -> void:
	if not use_powers:
		return
	for slot in run.powers.size():
		var power = run.powers[slot]
		if power == null or power.effect == null or not _can_act():
			continue
		var name: String = power.effect.get_script().resource_path.get_file()
		match name:
			"extra_turn_effect.gd":
				await _use(slot, [])
			"super_flick_effect.gd":
				if main.flick_boost <= 1.0 and _good_shot_exists():
					await _use(slot, [])
			"bomb_drop_effect.gd":
				var spot := _best_cluster()
				if spot != Vector2.INF:
					await _use_point(slot, spot)
			"freeze_ray_effect.gd", "shrink_ray_effect.gd":
				var target = _strongest_enemy()
				if target != null:
					await _use_enemy(slot, target)
			"rewind_effect.gd":
				if main._figures_lost > _lost_before:
					await _use(slot, [])
		_lost_before = main._figures_lost


func _use(slot: int, _args: Array) -> void:
	main._on_power_slot_pressed(slot)
	if run.powers[slot] == null:
		stats.powers_used += 1
	await tree.physics_frame
	await _wait_for_player()


func _use_enemy(slot: int, target) -> void:
	main._on_power_slot_pressed(slot)
	if main._power_slot == slot:
		main._try_power_target(target.global_position)
		if run.powers[slot] == null:
			stats.powers_used += 1
		else:
			main._cancel_power()
	await tree.physics_frame
	await _wait_for_player()


func _use_point(slot: int, point: Vector2) -> void:
	main._on_power_slot_pressed(slot)
	if main._power_slot == slot:
		main._try_power_target(point)
		if run.powers[slot] == null:
			stats.powers_used += 1
		else:
			main._cancel_power()
	await tree.physics_frame
	await _wait_for_player()


## Settling powers (Bomb Drop) put the combat in SETTLING: wait until it is the player's move again.
func _wait_for_player() -> void:
	var guard := 0
	while is_instance_valid(main) and main._state != 0 and main._state != 4 and guard < 3000:
		await tree.physics_frame
		guard += 1


func _good_shot_exists() -> bool:
	var candidates := _candidates([])
	if candidates.is_empty():
		return false
	var choice := _choose(candidates, 150.0)
	return choice.has("impulse")


## The spot (within the board) where a Bomb Drop pushes the most enemy figures toward the edge.
func _best_cluster() -> Vector2:
	var best := Vector2.INF
	var best_count := 1
	for enemy in main._enemies:
		if not main._is_alive(enemy):
			continue
		var count := 0
		for other in main._enemies:
			if main._is_alive(other) and other.global_position.distance_to(enemy.global_position) < 250.0:
				count += 1
		var near_players := 0
		for p in main._players:
			if main._is_alive(p) and p.global_position.distance_to(enemy.global_position) < 330.0:
				near_players += 1
		if count > best_count and near_players == 0:
			best_count = count
			best = enemy.global_position
	return best


func _strongest_enemy():
	var best = null
	var best_mass := 0.0
	for enemy in main._enemies:
		if main._is_alive(enemy) and not enemy.shrunk and enemy.mass > best_mass:
			best = enemy
			best_mass = enemy.mass
	return best
