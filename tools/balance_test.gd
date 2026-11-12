extends SceneTree
## Balance-change test (Bumper, Speedo, Glue Guy, Absorber, Spitter, Cluster, Bummer): godot --headless -s tools/balance_test.gd

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


func _until(cond: Callable, seconds := 30.0) -> bool:
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
	Setup.sheet_open = false
	for e in entries:
		Setup.entries.append(e)
	Setup.prepare()
	_main = load("res://scenes/main.tscn").instantiate()
	_main.enemy_think_time = 0.02
	root.add_child(_main)
	current_scene = _main
	await _frames(4)
	await _until(func(): return _main._state == 0)


func _all() -> void:
	await create_timer(0.5).timeout
	var run = root.get_node("RunManager")
	var F := "res://resources/figures/"
	var grunt = load(F + "grunt.tres")
	var bumper = load(F + "bumper.tres")
	var speedo = load(F + "speedo.tres")
	var glue = load(F + "glue_guy.tres")
	var absorber = load(F + "absorber.tres")
	var spitter = load(F + "spitter.tres")
	var cluster = load(F + "cluster.tres")
	var bummer = load(F + "bummer.tres")

	print("Rarity and data")
	_check(bummer.rarity == 2, "Bummer is Rare")
	_check(absorber.flick_power_multiplier == 1.6, "Absorber flick power 1.6")

	print("Bumper Bulk")
	for case in [[Vector2i(1, 1), "mass", 1.1 * 1.15], [Vector2i(1, 2), "knock", 0.75 * 0.75], [Vector2i(1, 3), "flick", 0.85]]:
		await _start([_entry(bumper, 0, Vector2(540, 1500), case[0])])
		var d = _main._players[0].data
		var got: float = d.mass if case[1] == "mass" else (d.knockback_taken_multiplier if case[1] == "knock" else d.flick_power_multiplier)
		_check(absf(got - case[2]) < 0.001, "%s %s = %.3f" % [case[0], case[1], got])
	_check(absf(_main._players[0].data.damping_multiplier - 1.3) < 0.001, "Easy Rolling damping x1.3")

	print("Speedo")
	var tree = run.tree_for(speedo)
	_check([tree.path_a[0].display_name, tree.path_a[1].display_name, tree.path_a[2].display_name] == ["Building Speed", "Flick Fury", "Triple Dash"], "Dash: Building Speed / Flick Fury / Triple Dash (no Quad Dash)")
	_check(tree.path_b[2].display_name == "Hard Hitter", "Zip tier 3 is Hard Hitter")
	await _start([_entry(speedo, 0, Vector2(540, 1500), Vector2i(0, 3))])
	var a = _main._players[0].ability
	_check(a.flicks_per_turn == 3 and a.power_per_flick == 0.15 and a.flick_knockback_per_flick == 0.1, "Dash tier 3: 3 flicks, +15% per flick, +10% knockback per flick taken")

	print("Glue Guy")
	await _start([_entry(glue, 0, Vector2(540, 1000), Vector2i(0, 2)), _entry(grunt, 1, Vector2(300, 800)), _entry(grunt, 1, Vector2(420, 800)),
			_entry(grunt, 1, Vector2(540, 800)), _entry(grunt, 1, Vector2(660, 800)), _entry(grunt, 1, Vector2(780, 800)), _entry(grunt, 1, Vector2(880, 800))])
	var gg = _main._players[0]
	_check(gg.ability.max_stuck == 5, "Sticky tier 2: up to 5")
	for e in _main._enemies:
		gg.ability.on_hit(gg, e)
	_check(gg.glue_partners().size() == 5, "holds 5 figures at once, not more (%d)" % gg.glue_partners().size())
	var chained := 0
	for e in _main._enemies:
		if e.is_glued() and e.glue_partners().size() > 1:
			chained += 1
	_check(chained == 0, "stuck figures are joined only to Glue Guy (no chains)")
	await _start([_entry(glue, 0, Vector2(540, 1000), Vector2i(0, 1)), _entry(grunt, 1, Vector2(300, 800)), _entry(grunt, 1, Vector2(420, 800)), _entry(grunt, 1, Vector2(540, 800)), _entry(grunt, 1, Vector2(660, 800))])
	gg = _main._players[0]
	for e in _main._enemies:
		gg.ability.on_hit(gg, e)
	_check(gg.ability.max_stuck == 3 and gg.glue_partners().size() == 3, "Sticky tier 1: up to 3")
	var gtree = run.tree_for(glue)
	_check(gtree.path_a[2].display_name == "Sticky Flicks" and gtree.path_b[1].display_name == "Locked Down", "Sticky Flicks is tier 3, Thin Prey gone")
	await _start([_entry(glue, 0, Vector2(540, 1000), Vector2i(1, 2))])
	_check(_main._players[0].ability.stuck_enemy_flick == 0.5, "Locked Down: a stuck enemy flicks 50% weaker")

	print("Absorber")
	await _start([_entry(absorber, 0, Vector2(540, 1000)), _entry(grunt, 1, Vector2(540, 700)), _entry(grunt, 1, Vector2(700, 700))])
	var ab = _main._players[0]
	var ao = ab.ability
	_check(ao.absorb_speed == 150.0 and ao.escape_speed == 1100.0, "absorb at 150 px/s, escape at 1100 px/s")
	var victim = _main._enemies[0]
	var mate = _main._enemies[1]
	ao._armed = true
	ao.on_impact(ab, victim, 200.0, victim.global_position)
	_check(ao.held.size() == 1 and not _main._enemies.has(victim), "absorbed at 200 px/s")
	ao.on_impact(ab, mate, 1000.0, mate.global_position)
	_check(ao.held.size() == 1, "a 1000 px/s hit from a teammate does not free it")
	ao.on_impact(ab, mate, 1200.0, mate.global_position)
	_check(ao.held.is_empty() and _main._enemies.has(victim), "a 1200 px/s hit does")
	await _start([_entry(absorber, 0, Vector2(540, 1000), Vector2i(1, 1)), _entry(grunt, 1, Vector2(540, 700)), _entry(grunt, 1, Vector2(700, 700))])
	ab = _main._players[0]
	ao = ab.ability
	victim = _main._enemies[0]
	mate = _main._enemies[1]
	ao._armed = true
	ao.on_impact(ab, victim, 200.0, victim.global_position)
	ao.on_impact(ab, mate, 3000.0, mate.global_position)
	_check(ao.held.size() == 1 and ao.get_escape_speed(ab) == 0.0, "Tight Grip: hits can never free it")
	ab.global_position = Vector2(2000, 1000)  # off the table
	ab.knock_off(0.05)
	await _frames(2)
	_check(ao.held.is_empty() and _main._enemies.has(victim) and not victim.knocked_off, "the Absorber knocked off: the held figure still pops out")

	print("Spitter sprays after its flick")
	await _start([_entry(spitter, 0, Vector2(540, 1500)), _entry(grunt, 1, Vector2(540, 600))], false)
	var sp = _main._players[0]
	var water0: float = sp.ability.water
	var turns: int = _main._enemy_turns_taken
	_main._on_press(0, sp.global_position)
	_main._release_aim(sp.global_position + Vector2(0, 60))
	await _until(func(): return _main._bonus_figure != null, 15.0)
	_check(_main._bonus_figure == sp and _main._bonus_mode == "spray", "after the flick settles a spray window opens")
	_check(_main._enemy_turns_taken == turns, "the enemy has not moved yet")
	_main._on_press(0, Vector2(540, 900))
	await create_timer(0.6).timeout
	_check(_main._spraying, "holding sprays")
	_main._release_aim(Vector2(540, 900))
	_check(sp.ability.water < water0 - 0.1, "water was used (%.2f of %.2f)" % [sp.ability.water, water0])
	_main._on_press(0, Vector2(300, 900))
	_main._release_aim(Vector2(300, 900))
	_main._on_press(0, Vector2(300, 900))
	_main._release_aim(Vector2(300, 1100))
	_check(_main._bonus_figure == sp, "a tap or a drag in the window does not end it or flick")
	_main._skip_bonus_flick()
	var passed = await _until(func(): return _main._enemy_turns_taken > turns and _main._state == 0, 30.0)
	_check(passed, "Skip ends the turn and the enemy moves")

	print("Cluster tosses several times")
	await _start([_entry(cluster, 0, Vector2(540, 1500)), _entry(grunt, 1, Vector2(540, 600))], false)
	var cl = _main._players[0]
	turns = _main._enemy_turns_taken
	_main._on_press(0, cl.global_position)
	_main._release_aim(cl.global_position)  # select
	_main._on_press(0, Vector2(540, 1000))
	_main._release_aim(Vector2(540, 1000))  # toss 1
	await _until(func(): return _main._bonus_figure != null, 20.0)
	_check(_main._bonus_figure == cl and _main._bonus_mode == "toss" and cl.ability.count == 2, "after the first toss a toss window opens (2 clustlings left)")
	_main._on_press(0, Vector2(400, 1000))
	_main._release_aim(Vector2(400, 1000))  # toss 2
	await _until(func(): return cl.ability.count == 1 and _main._state == 2, 5.0)
	var turn_done = await _until(func(): return _main._enemy_turns_taken > turns and _main._state == 0 and _main._bonus_figure == null, 30.0)
	_check(cl.ability.count == 1 and turn_done, "the last clustling can't be tossed: the turn passes after the second toss")
	var tossed := 0
	for p in _main._players:
		if p.data.display_name != "Cluster":
			tossed += 1
	_check(tossed >= 1, "tossed clustlings are on the board (%d)" % tossed)

	print()
	if _fails.is_empty():
		print("ALL BALANCE TESTS PASSED")
		quit(0)
	else:
		printerr("%d FAILED:" % _fails.size())
		for x in _fails:
			printerr("  - " + x)
		quit(1)
