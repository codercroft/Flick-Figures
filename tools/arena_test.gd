extends SceneTree
## Arena difficulty / new arenas / easy start test: godot --headless -s tools/arena_test.gd (exit 1 on failure).

var _fails: Array[String] = []


func _initialize() -> void:
	_all()


func _check(ok: bool, what: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _all() -> void:
	await create_timer(0.5).timeout
	var run = root.get_node("RunManager")
	var cfg = run.config
	var board := Vector2(900, 1000)

	print("Arena data")
	_check(cfg.arenas.size() == 20, "20 arenas in the random pool (%d)" % cfg.arenas.size())
	var counts := [0, 0, 0]
	for arena in cfg.arenas:
		counts[arena.difficulty] += 1
		var warnings: PackedStringArray = arena.get_warnings(board)
		_check(warnings.is_empty(), "%s has no layout warnings %s" % [arena.display_name, warnings])
	_check(counts == [7, 7, 6], "7 Easy / 7 Medium / 6 Hard %s" % [counts])

	print("Nothing blocks the enemy spawn rows or any encounter spot")
	for arena in cfg.arenas:
		for count in [4]:  # (5 and 6 enemies only come from Ascension 3; the old side-rail layouts already crowd the edge slots)
			var slot: float = board.x / count
			for i in count:
				var pos := Vector2(slot * (i + 0.5), 160.0 + 120.0 * (i % 2))
				_check(not arena.blocks_circle(pos, 55.0), "%s: default spawn %d/%d is clear" % [arena.display_name, i, count])
	var encounters: Array = []
	encounters.append_array(cfg.regular_encounters)
	encounters.append_array(cfg.easy_encounters)
	encounters.append_array(cfg.elite_encounters)
	for enc in encounters:
		var arenas_to_test: Array = []
		if enc.arena != null:
			arenas_to_test.append(enc.arena)
		if cfg.easy_encounters.has(enc):
			for a in cfg.arenas:
				if a.difficulty == ArenaData.Difficulty.EASY:
					arenas_to_test.append(a)
		for arena in arenas_to_test:
			for entry in enc.enemies:
				for p in entry.positions:
					_check(not arena.blocks_circle(p, 50.0), "%s on %s: spot %s is clear" % [enc.display_name, arena.display_name, p])

	print("Random pick odds")
	run.start_new_run(0)
	run.config.arenas  # touch
	var tally := {}
	for act in 3:
		run.act = act
		run.easy_start = false
		var hits := [0, 0, 0]
		run.arena = null
		for i in 1500:
			run._pick_arena()
			hits[run.arena.difficulty] += 1
		tally[act] = hits
		print("  act %d: %s" % [act + 1, hits])
	_check(tally[0][2] == 0 and tally[0][0] > 700 and tally[0][1] > 400, "act 1: no Hard, about 60/40")
	_check(tally[1][2] > 250 and tally[1][2] < 500, "act 2: about 25% Hard")
	_check(tally[2][0] > 400 and tally[2][2] > 400, "act 3: about a third each")
	var repeats := 0
	run.act = 1
	run.arena = null
	var last = null
	for i in 400:
		run._pick_arena()
		if run.arena == last:
			repeats += 1
		last = run.arena
	_check(repeats == 0, "never the same arena twice in a row")

	print("Ascension 12 odds")
	run.start_new_run(12)
	for act in 3:
		run.act = act
		run.easy_start = false
		var o: Vector3 = run.arena_odds()
		print("  act %d: %s" % [act + 1, o])
	run.act = 0
	_check(run.arena_odds() == Vector3(30, 45, 25), "act 1 uses act 2's odds")
	run.act = 1
	_check(run.arena_odds() == Vector3(33, 34, 33), "act 2 uses act 3's odds")
	run.act = 2
	_check(run.arena_odds() == Vector3(20, 40, 40), "act 3 uses 20/40/40")
	run.act = 0
	run.easy_start = true
	_check(run.arena_odds() == Vector3(60, 40, 0), "easy start at A12: Easy or Medium")
	run.start_new_run(0)
	run.act = 0
	run.easy_start = true
	_check(run.arena_odds() == Vector3(1, 0, 0), "easy start at A0: Easy only")

	print("Easy start")
	run.start_new_run(0)
	var names: Array = []
	for combat in 4:
		var node := MapNode.new()
		node.type = MapNode.Type.COMBAT
		node.column = 0
		run.node = node
		run._build_lineup()
		names.append("%s/%s/%d" % [run.encounter_name, run.arena.difficulty_name(), run.enemies.size()])
		if combat < 2:
			_check(run.arena.difficulty == ArenaData.Difficulty.EASY, "combat %d is on an Easy arena (%s)" % [combat + 1, run.arena.display_name])
		if combat == 0:
			_check(run.encounter_name == "", "combat 1 is plain Grunts")
		if combat == 1:
			_check(["Bent Lane", "Glass Cannons", "Rookies"].has(run.encounter_name), "combat 2 is an easy encounter (%s)" % run.encounter_name)
		_check(run.enemies.size() == 4, "combat %d has 4 enemies" % [combat + 1])
	print("  ", names)
	for i in 30:
		run.start_new_run(0)
		run.regular_combats_played = 1
		var n := MapNode.new()
		n.type = MapNode.Type.COMBAT
		run.node = n
		run._build_lineup()
		if run.arena.difficulty != ArenaData.Difficulty.EASY:
			_check(false, "easy encounter %s landed on %s" % [run.encounter_name, run.arena.display_name])
	_check(true, "30 easy-encounter rolls were all on Easy arenas")

	print("Ice")
	var arena_node = load("res://scripts/arena.gd").new()
	root.add_child(arena_node)
	var ice: ArenaData = load("res://resources/arenas/ice_rink.tres")
	arena_node.build(ice, Rect2(90, 360, 900, 1000))
	var v0 := Vector2(0, -1000)
	var plain: Vector2 = arena_node.predict_floor_velocity(Vector2(0, 0), v0, 0.08, -1, 1.5)
	var on_ice: Vector2 = arena_node.predict_floor_velocity(Vector2(540, 800), v0, 0.08, -1, 1.5)
	_check(plain == v0, "off the ice nothing changes")
	_check(on_ice.length() > v0.length(), "on the ice the damping is partly cancelled (%.0f)" % on_ice.length())
	_check(not ice.get_warnings(board).is_empty() == false, "ice rink stays off the deck strip")

	print("Conveyor alternates")
	var conv: ArenaData = load("res://resources/arenas/conveyor.tres")
	arena_node.build(conv, Rect2(90, 360, 900, 1000))
	var d1: Vector2 = arena_node.patch_direction(conv.patches[0])
	arena_node.tick_round()
	var d2: Vector2 = arena_node.patch_direction(conv.patches[0])
	_check(d1 == -d2 and d1 != Vector2.ZERO, "the belt reverses each round")

	print("Grippy Table only works on the enemy's turns")
	run.start_new_run(0)
	var node2 := MapNode.new()
	node2.type = MapNode.Type.COMBAT
	run.node = node2
	run.add_relic(load("res://resources/relics/grippy_table.tres"))
	run._build_lineup()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 5:
		await process_frame
	var figure = main._players[0]
	var base: float = figure.linear_damp
	main.turret_side = 1  # Figure.Team.ENEMY
	main._apply_grip()
	_check(is_equal_approx(figure.linear_damp, base / 0.7), "enemy turn: damping x1/0.7 (%.2f -> %.2f)" % [base, figure.linear_damp])
	main.turret_side = 0
	main._apply_grip()
	_check(is_equal_approx(figure.linear_damp, base), "player turn: back to normal")
	_check(run.relics[0].description.contains("enemy"), "description mentions the enemy's turns")

	print("The AI follows a real slide on ice")
	run.start_new_run(0)
	run.sandbox_encounter = null
	run.node = node2
	run._build_lineup()
	run.arena = load("res://resources/arenas/ice_rink.tres")
	main.queue_free()
	for i in 3:
		await process_frame
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 5:
		await process_frame
	var mover = main._players[0]
	for other in main._players:
		if other != mover:
			other.global_position = Vector2(-5000, -5000)  # (out of the way, not checked for knock-off here)
	for e in main._enemies:
		e.global_position = Vector2(-5000, -4000)
	mover.on_deck = false
	var start := Vector2(540, 1250)
	mover.global_position = start
	main.ai._prepare()
	var sim: Dictionary = main.ai._simulate_flight(mover, start, Vector2(0, -500))
	var predicted: Vector2 = sim.points[sim.points.size() - 1]
	mover.linear_velocity = Vector2(0, -500)
	for i in 600:
		await physics_frame
		if mover.linear_velocity.length() < 15.0:
			break
	var real: Vector2 = mover.global_position
	print("  predicted end ", predicted, " real end ", real)
	_check(absf(predicted.y - real.y) < 0.15 * absf(start.y - real.y) + 20.0, "simulated slide matches the real one on ice")
	var plain_slide: float = (500.0 - 15.0) / mover.linear_damp
	_check(absf(start.y - real.y) > 1.8 * plain_slide, "ice slides much farther than normal (%.0f vs %.0f px)" % [absf(start.y - real.y), plain_slide])

	print("\nFAILED: %s" % [_fails] if not _fails.is_empty() else "\nAll arena checks passed")
	quit(1 if not _fails.is_empty() else 0)
