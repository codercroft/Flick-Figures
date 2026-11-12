extends SceneTree
## Wikka Wat / Ultimate Shieldon test: godot --headless -s tools/wikka_test.gd (exit 1 on failure; check for SCRIPT ERROR).

var _fails: Array[String] = []
var _main: Node


func _initialize() -> void:
	_all()


func _check(ok: bool, what: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		await physics_frame


func _until(cond: Callable, seconds := 40.0) -> bool:
	var t := 0.0
	while t < seconds:
		if cond.call():
			return true
		await create_timer(0.1).timeout
		t += 0.1
	return cond.call()


func _entry(data, team: int, pos: Vector2, upgrade := Vector2i(-1, 0)) -> Dictionary:
	return {"data": data, "team": team, "pos": pos, "equipment": null, "finish": null, "upgrade": upgrade, "node": null}


func _start(entries: Array, ai_off := true) -> void:
	if is_instance_valid(_main):
		_main.queue_free()
		await _frames(3)
	var Setup = load("res://scripts/sandbox_setup.gd")
	Setup.begin()
	Setup.lineup_kind = "none"
	Setup.arena = root.get_node("RunManager").config.boss_arena
	Setup.ai_off = ai_off
	for e in entries:
		Setup.entries.append(e)
	Setup.prepare()
	_main = load("res://scenes/main.tscn").instantiate()
	_main.enemy_think_time = 0.02
	root.add_child(_main)
	current_scene = _main
	await _frames(4)
	await _until(func(): return _main._state == 0)


func _flick(fig: Node, drag := Vector2(0, 150)) -> void:
	var p: Vector2 = fig.global_position
	_main._on_press(0, p)
	_main._release_aim(p + drag)


func _all() -> void:
	await create_timer(0.5).timeout
	var run = root.get_node("RunManager")
	var cfg = run.config
	var grunt = load("res://resources/figures/grunt.tres")
	var ww = load("res://resources/figures/wikka_wat.tres")
	var us = load("res://resources/figures/ultimate_shieldon.tres")

	print("Data")
	_check(cfg.registry.draftable.has(ww) and ww.rarity == 1 and ww.flick_power_multiplier == 1.1, "Wikka Wat: draftable Uncommon, flick power x1.1")
	_check(run.tree_for(ww) != null and run.tree_for(ww).path_a_name == "Scratch" and run.tree_for(ww).path_b_name == "Seek", "tree Scratch / Seek")
	_check(not cfg.registry.draftable.has(us), "Ultimate Shieldon is not draftable")
	var enc = null
	for e in cfg.elite_encounters:
		if e.display_name == "Ultimate Shieldon":
			enc = e
	_check(enc != null and enc.acts == [2] and enc.enemies.size() == 1 and enc.enemies[0].figure == us and enc.enemy_flicks_per_turn == 1 and enc.arena.display_name == "Open Field", "act 2 elite: just the Ultimate Shieldon, 1 flick, Open Field")
	_check(us.radius == 110.0 and us.mass == 5.0, "radius 110, mass 5")

	print("Wikka Wat reverse")
	await _start([_entry(ww, 0, Vector2(540, 1500)), _entry(grunt, 1, Vector2(900, 400))])
	var w = _main._players[0]
	_flick(w)
	await create_timer(0.25).timeout
	_check(_main._state == 2, "settling after the flick")
	var before: Vector2 = w.linear_velocity
	var ok: bool = _main.try_reverse_tap()
	await physics_frame
	var after: Vector2 = w.linear_velocity
	print("    %s -> %s" % [before, after])
	_check(ok and after.dot(before) < 0.0 and absf(after.length() - before.length()) < before.length() * 0.08, "a tap reverses it: same speed, opposite direction")
	_check(not _main.try_reverse_tap(), "only one use per turn at base")
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.position = Vector2(300, 250)
	w.ability._used = 0
	var v1: Vector2 = w.linear_velocity
	_main._input(ev)  # a real tap through the input path
	await physics_frame
	print("    after the tap: state %d, %s -> %s, used %d" % [_main._state, v1, w.linear_velocity, w.ability._used])
	_check(w.linear_velocity.dot(v1) < 0.0, "a screen tap through _input reverses it too")
	await _until(func(): return _main._state == 0 and _main._enemy_turns_taken >= 0, 20.0)
	await _until(func(): return _main._state == 0, 20.0)
	_check(w.ability._used == 0, "charges refilled after the turn change")
	_check(not w.ability.can_reverse(w), "not reversible when not moving")

	print("Scratch / Seek tiers")
	for case in [[Vector2(0, 1), 2], [Vector2(0, 3), 3]]:
		await _start([_entry(ww, 0, Vector2(540, 1500), case[0])])
		_check(_main._players[0].ability.reverses_per_turn == case[1], "%s: %d reverses per turn" % [case[0], case[1]])
	await _start([_entry(ww, 0, Vector2(540, 1500), Vector2(0, 2)), _entry(grunt, 1, Vector2(900, 700))])
	w = _main._players[0]
	var ab = w.ability
	_check(ab.reverses_per_turn == 2 and ab.speed_bonus == 0.25 and ab.knockback_bonus == 0.25, "Scratch tier 2: +25% speed and knockback, 2 uses")
	_flick(w, Vector2(50, 0))
	await create_timer(0.25).timeout
	before = w.linear_velocity
	w.ability.use_reverse(w)
	await physics_frame
	_check(absf(w.linear_velocity.length() / before.length() - 1.25) < 0.08, "each use gives +25%% speed (x%.2f)" % (w.linear_velocity.length() / before.length()))
	_check(absf(ab.get_dealt_knockback_bonus(w, null) - 0.25) < 0.001, "and +25% knockback dealt")
	await _until(func(): return not is_instance_valid(w) or w.is_resting(), 15.0)
	_check(ab.get_dealt_knockback_bonus(w, null) == 0.0, "the bonus ends when it comes to rest")

	await _start([_entry(ww, 0, Vector2(540, 1500), Vector2(1, 1)), _entry(grunt, 1, Vector2(900, 700)), _entry(grunt, 1, Vector2(200, 600))])
	w = _main._players[0]
	_flick(w, Vector2(0, 100))
	await create_timer(0.25).timeout
	before = w.linear_velocity
	var near: Vector2 = (_main._enemies[0].global_position - w.global_position).normalized()
	var nearest = _main._enemies[0]
	for e in _main._enemies:
		if e.global_position.distance_to(w.global_position) < nearest.global_position.distance_to(w.global_position):
			nearest = e
	near = (nearest.global_position - w.global_position).normalized()
	w.ability.use_reverse(w)
	await physics_frame
	_check(w.linear_velocity.normalized().dot(near) > 0.97 and absf(w.linear_velocity.length() - before.length()) < before.length() * 0.08, "Seek: redirects toward the nearest opponent at the same speed")
	await _until(func(): return _main._state == 0, 25.0)

	print("Seek refresh and kill stacks")
	w.ability.refresh_on_hit = true
	w.ability._used = 1
	w.linear_velocity = Vector2(0, -400)
	w.ability.on_hit(w, _main._enemies[0] if not _main._enemies.is_empty() else null)
	_check(w.ability._used == 0 or _main._enemies.is_empty(), "hitting an opponent refreshes the reverse")
	var tier3 = _main._players[0]
	await _start([_entry(ww, 0, Vector2(540, 1500), Vector2(1, 3)), _entry(grunt, 1, Vector2(900, 700))])
	w = _main._players[0]
	var m0: float = w.mass
	_main._flicker = w
	for i in 7:
		w.ability.on_opponent_knocked_off(w, null)
	_check(absf(w.mass - m0 * pow(1.2, 5)) < 0.01 and absf(w.ability.get_flick_power_multiplier(w) - pow(1.2, 5)) < 0.01, "Bloodscent stacks +20%% mass and flick power per kill, capped at 5 (mass %.2f)" % w.mass)

	print("Enemy Wikka Wat")
	await _start([_entry(grunt, 0, Vector2(540, 1000)), _entry(grunt, 0, Vector2(300, 1500)), _entry(grunt, 0, Vector2(500, 1500)), _entry(grunt, 0, Vector2(700, 1500)), _entry(ww, 1, Vector2(900, 700))], false)
	var ew = _main._enemies[0]
	var pl = _main._players[0]
	# A Wikka Wat flying past the player's figure: the AI should want to come back.
	ew.global_position = Vector2(540, 700)
	ew.linear_velocity = Vector2(0, -700)
	_main.turret_side = 1
	var dir: Vector2 = _main.ai.choose_wikka_reverse(ew, _main._players, _main.board.get_table_rect())
	print("    reverse direction %s" % dir)
	_check(dir != Vector2.ZERO and dir.y > 0.5, "an enemy Wikka Wat that flew past reverses to hit the player's figure")
	ew.linear_velocity = Vector2(0, 700)  # heading straight at it: keep going
	dir = _main.ai.choose_wikka_reverse(ew, _main._players, _main.board.get_table_rect())
	_check(dir == Vector2.ZERO, "and keeps going when already on course")
	Engine.time_scale = 3.0
	for turn in 3:
		var tb: int = _main._enemy_turns_taken
		if _main._players.is_empty():
			break
		_flick(_main._players[_main._players.size() - 1], Vector2(0, 40))
		var done = await _until(func(): return _main._enemy_turns_taken > tb and _main._state == 0, 30.0)
		_check(done, "enemy turn %d with a Wikka Wat completed" % (turn + 1))
	Engine.time_scale = 1.0

	print("Ultimate Shieldon shield")
	await _start([_entry(grunt, 0, Vector2(540, 1500)), _entry(grunt, 0, Vector2(800, 1500)), _entry(us, 1, Vector2(450, 600))], false)
	var boss = _main._enemies[0]
	var sab = boss.ability
	_check(not sab.has_shield(), "no shield before its first turn ends")
	Engine.time_scale = 3.0
	var tb2: int = _main._enemy_turns_taken
	_flick(_main._players[0], Vector2(0, 40))
	await _until(func(): return _main._enemy_turns_taken > tb2 and _main._state == 0, 40.0)
	Engine.time_scale = 1.0
	_check(sab.has_shield(), "the shield is up at the end of its turn")
	var nearest_player = _main._players[0]
	for p in _main._players:
		if p.global_position.distance_to(boss.global_position) < nearest_player.global_position.distance_to(boss.global_position):
			nearest_player = p
	var want: float = (nearest_player.global_position - boss.global_position).angle()
	_check(absf(angle_difference(want, sab.shield_angle())) < 0.05, "centered toward the nearest player figure")
	_check(sab.arc_degrees == 240.0 and sab.covers(boss, boss.global_position + Vector2.from_angle(sab.shield_angle()) * 100.0) \
			and not sab.covers(boss, boss.global_position - Vector2.from_angle(sab.shield_angle()) * 100.0), "240 degree arc: the front is covered, the back is open")
	var shapes := 0
	for c in boss.get_children():
		if c is CollisionPolygon2D:
			shapes += 1
	_check(shapes == 1, "the shield is a collision polygon on the body")
	_main._enemies[0].ability.on_flicked(boss, Vector2.ZERO)
	_check(not sab.has_shield(), "it drops when the Ultimate Shieldon is flicked")

	print("Shield side vs open side")
	var results := {}
	for side in ["shield", "open"]:
		await _start([_entry(grunt, 0, Vector2(540, 1500)), _entry(us, 1, Vector2(450, 800))])
		boss = _main._enemies[0]
		sab = boss.ability
		sab.raise_shield(boss)  # toward the player (below it)
		var attacker = _main._players[0]
		attacker.on_deck = false
		var from_below: bool = side == "shield"
		attacker.global_position = boss.global_position + Vector2(0, 260 if from_below else -260)
		attacker.linear_velocity = Vector2(0, -1500 if from_below else 1500)
		var peak := 0.0
		var rebound := 0.0
		for i in 40:
			await physics_frame
			peak = maxf(peak, boss.linear_velocity.length())
			if is_instance_valid(attacker):
				rebound = maxf(rebound, attacker.linear_velocity.dot(Vector2(0, 1 if from_below else -1)))
		results[side] = {"boss": peak, "rebound": rebound}
		print("    %s: Shieldon peak speed %d, attacker rebound %d" % [side, peak, rebound])
	_check(results.shield.boss < 0.5 * results.open.boss, "hits on the shield move the Shieldon much less (%d vs %d)" % [results.shield.boss, results.open.boss])
	_check(results.shield.rebound > 200.0, "and bounce the attacker back (%d)" % results.shield.rebound)

	print("Ultimate Shieldon fight in the sandbox lineup")
	var Setup = load("res://scripts/sandbox_setup.gd")
	Setup.begin()
	Setup.lineup_kind = "encounter"
	Setup.encounter = enc
	Setup.arena = null
	Setup.prepare()
	_main.queue_free()
	await _frames(3)
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	current_scene = _main
	await _frames(4)
	_check(_main._enemies.size() == 1 and _main._enemies[0].data.display_name == "Ultimate Shieldon" and run.arena.display_name == "Open Field", "the encounter loads: one Ultimate Shieldon on Open Field")

	Engine.time_scale = 1.0
	print()
	if _fails.is_empty():
		print("ALL WIKKA / SHIELDON TESTS PASSED")
		quit(0)
	else:
		printerr("%d FAILED:" % _fails.size())
		for x in _fails:
			printerr("  - " + x)
		quit(1)
