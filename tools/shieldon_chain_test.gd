extends SceneTree
## Shieldon Ooper: Wall Chain (Bulwark tier 3) and the Decoy path: godot --headless -s tools/shieldon_chain_test.gd (exit 1 on failure)
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


func _start(entries: Array) -> void:
	if is_instance_valid(_main):
		_main.queue_free()
		await _frames(3)
	var Setup = load("res://scripts/sandbox_setup.gd")
	Setup.begin()
	Setup.lineup_kind = "none"
	Setup.arena = root.get_node("RunManager").config.boss_arena
	Setup.ai_off = true
	for e in entries:
		Setup.entries.append(e)
	Setup.prepare()
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	current_scene = _main
	await _frames(6)
	await _until(func(): return _main._state == 0)


func _flick(fig, drag := Vector2(0, 120)) -> void:
	var p: Vector2 = fig.global_position
	_main._on_press(0, p)
	_main._release_aim(p + drag)


func _walls_of(fig) -> int:
	var n := 0
	for w in _main.arena._shield_walls:
		if is_instance_valid(w) and w.owner_figure == fig:
			n += 1
	return n


func _all() -> void:
	await _frames(3)
	var SO = load("res://resources/figures/shieldon_ooper.tres")
	var GR = load("res://resources/figures/grunt.tres")
	print("Wall Chain: the nearest teammate on the board also gets a wall")
	await _start([_entry(SO, 0, Vector2(540, 1480), Vector2i(0, 3)), _entry(GR, 0, Vector2(250, 900)), _entry(GR, 1, Vector2(540, 600))])
	var so = _main._players[0]
	var ally = _main._players[1]
	ally.on_deck = false
	ally._update_collision()
	_flick(so)
	await _until(func(): return _main._state != 0 and _main._state != 1)
	await _until(func(): return _main._state == 3 or _main._state == 0, 30.0)
	print("   state ", _main._state, " pos ", so.global_position, " spot ", so.ability._spot, " walls ", _main.arena._shield_walls.size(), " flicking ", so.ability._flicking)
	_check(_walls_of(so) >= 1 or so.ability.has_active_wall(so), "Shieldon put up its own wall")
	_check(_walls_of(ally) == 1, "the board ally has a wall too (%d)" % _walls_of(ally))
	print("Wall Chain: a teammate still on the deck also gets one")
	await _start([_entry(SO, 0, Vector2(300, 1480), Vector2i(0, 3)), _entry(GR, 0, Vector2(700, 1480)), _entry(GR, 1, Vector2(540, 600))])
	so = _main._players[0]
	ally = _main._players[1]
	_flick(so)
	await _until(func(): return _main._state == 3 or _main._state == 0, 30.0)
	_check(_walls_of(ally) == 1, "the deck ally has a wall (%d)" % _walls_of(ally))
	await _decoy(SO, GR)
	if _fails.is_empty():
		print("ALL OK")
		quit(0)
	else:
		print("FAILED: ", _fails)
		quit(1)


func _wall(so) -> Object:
	var facing := Vector2.UP
	var center: Vector2 = so.global_position + facing * (so.radius + 10.0 + 13.0)
	_main.arena.place_shield_wall(so, center, Vector2(190, 26), facing.angle() - PI / 2.0, so.ability._wall_props())
	so.ability._spot = so.global_position
	for w in _main.arena._shield_walls:
		if w.owner_figure == so:
			return w
	return null


func _decoy(SO, GR) -> void:
	var run = root.get_node("RunManager")
	print("Decoy path data")
	var tree = run.tree_for(SO)
	_check(tree.path_b_name == "Decoy" and tree.path_b[0].display_name == "Decoy" and tree.path_b[1].display_name == "Bouncy Wall" and tree.path_b[2].display_name == "Hidden Wall", "path B is Decoy: Decoy / Bouncy Wall / Hidden Wall")
	_check(tree.enemy_excluded_paths == [1], "enemies never use the Decoy path")
	run.start_new_run(5)
	var rolled_b := 0
	for i in 3000:
		run.act = i % 3
		var r: Vector2i = run._roll_enemy_upgrade(SO, i % 2 == 0)
		if r.x == 1:
			rolled_b += 1
	_check(rolled_b == 0, "an enemy Shieldon never rolls a Decoy tier (%d of 3000)" % rolled_b)
	run.deck.clear()
	run.deck_equipment.clear()
	run.deck_finish.clear()
	run.deck_upgrade.clear()
	for k in 4:
		run.deck.append(SO)
		run.deck_equipment.append(null)
		run.deck_finish.append(null)
		run.deck_upgrade.append(Vector2i(1, 3))
	run.enemies.clear()
	run.enemy_forced_upgrade.clear()
	run.enemy_forced_equipment.clear()
	run.enemy_forced_finish.clear()
	run.enemy_boosts.clear()
	run.enemy_positions.clear()
	run.enemy_elite.clear()
	run._add_mirror_enemies(load("res://resources/encounters/mirror_match.tres"))
	var mirrored := 0
	for u in run.enemy_forced_upgrade:
		if u.x == 1:
			mirrored += 1
	_check(not run.enemy_forced_upgrade.is_empty() and mirrored == 0, "Mirror Match does not copy a Decoy upgrade")

	print("Decoy tier 1: first-turn targeting and the AI ignoring the wall")
	for tier in [0, 1, 3]:
		await _start([_entry(SO, 0, Vector2(540, 1000), Vector2(1, tier) if tier > 0 else Vector2(-1, 0)), _entry(GR, 0, Vector2(860, 1000)), _entry(GR, 1, Vector2(540, 400))])
		var so = _main._players[0]
		so.on_deck = false
		so._update_collision()
		var wall = _wall(so)
		await _frames(3)
		var ai = _main.ai
		ai.think_budget_ms = 100000000
		var ENEMY := 1
		_main._enemy_turns_taken = 1  # the enemy's first turn
		ai._prepare()
		var hidden_first: bool = ai._ignored_walls[ENEMY].has(wall.get_rid())
		_main._enemy_turns_taken = 2
		ai._prepare()
		var hidden_later: bool = ai._ignored_walls[ENEMY].has(wall.get_rid())
		_check(hidden_first == (tier >= 1) and hidden_later == (tier == 3), "tier %d: wall ignored on turn 1 = %s, later = %s" % [tier, str(hidden_first), str(hidden_later)])
		_main._enemy_turns_taken = 1
		var toward := 0
		for i in 8:
			seed(100 + i)
			var choice: Dictionary = ai.choose_flick(_main._flick_candidates(), _main._players, _main.board.get_table_rect(), _main.max_flick_force)
			if not choice.is_empty() and choice.has("impulse"):
				var enemy = choice.enemy
				var dir: Vector2 = choice.impulse.normalized()
				var to_so: Vector2 = (so.global_position - enemy.global_position).normalized()
				if dir.dot(to_so) > 0.97:
					toward += 1
		print("    tier %d: %d of 8 first-turn shots aimed at Shieldon" % [tier, toward])
		if tier == 0:
			_check(toward >= 0, "baseline measured")
		else:
			_check(toward >= 7, "tier %d: the first-turn shots go at Shieldon" % tier)
		_main._enemy_turns_taken = 2
		var later := 0
		for i in 8:
			seed(100 + i)
			var choice2: Dictionary = ai.choose_flick(_main._flick_candidates(), _main._players, _main.board.get_table_rect(), _main.max_flick_force)
			if not choice2.is_empty() and choice2.has("impulse"):
				var e2 = choice2.enemy
				if choice2.impulse.normalized().dot((so.global_position - e2.global_position).normalized()) > 0.97:
					later += 1
		print("    tier %d: later turns %d of 8 at Shieldon" % [tier, later])
	print("Decoy tier 2: Bouncy Wall")
	await _start([_entry(SO, 0, Vector2(540, 1000), Vector2(1, 2))])
	_check(is_equal_approx(_main._players[0].ability.wall_bounce_multiplier, 1.5), "wall bounce x1.5")
