extends SceneTree
## Ascension / Skull-o-tron / enemy upgrade test: godot --headless -s tools/ascension_test.gd (exit 1 on failure).
## Run it, then check the output for "SCRIPT ERROR" (the AI sweep exercises the AI with every upgrade tier).

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


func _until(cond: Callable, seconds := 40.0) -> bool:
	var t := 0.0
	while t < seconds:
		if cond.call():
			return true
		await create_timer(0.1).timeout
		t += 0.1
	return cond.call()


func _load() -> void:
	if is_instance_valid(_main):
		_main.queue_free()
		await _frames(3)
	load("res://scripts/sandbox_setup.gd").prepare()
	_main = load("res://scenes/main.tscn").instantiate()
	_main.enemy_think_time = 0.02
	root.add_child(_main)
	current_scene = _main
	await _frames(5)


func _entry(data, team: int, pos: Vector2, upgrade := Vector2i(-1, 0)) -> Dictionary:
	return {"data": data, "team": team, "pos": pos, "equipment": null, "finish": null, "upgrade": upgrade, "node": null}


func _all() -> void:
	await create_timer(0.5).timeout
	var run = root.get_node("RunManager")
	var cfg = run.config.ascension
	var Setup = load("res://scripts/sandbox_setup.gd")

	print("Data-driven levels")
	_check(cfg.max_level == cfg.level_names.size() - 1 and cfg.max_level == 11, "max_level follows the list (%d)" % cfg.max_level)
	_check(cfg.level_descriptions.size() == cfg.level_names.size(), "a description for every level")
	_check(cfg.level_name(5) == "Upgraded Enemies" and cfg.level_name(11) == "Double Boss", "names: 5 Upgraded Enemies, 11 Double Boss")
	_check(cfg.level_name(25) == "Ascension 25", "an undefined level still has a fallback name")

	print("Migration")
	var AP = load("res://scripts/ascension_progress.gd")
	_check(AP.migrate_level(4) == 4 and AP.migrate_level(5) == 6 and AP.migrate_level(10) == 11, "levels 5+ shift up by one")
	var RH = load("res://scripts/run_history.gd")
	var old_entry := {"ascension": 6, "won": true}
	var new_entry := {"ascension": 6, "asc_version": 2, "won": true}
	_check(RH.ascension_label(old_entry, cfg) == "Ascension 6 (old: Fewer Offers)", "old history entry keeps its number and old name")
	_check(RH.ascension_label(new_entry, cfg) == "Ascension 6", "new entry plain")

	print("Upgrade rolls (Upgraded Enemies)")
	var bumper = load("res://resources/figures/bumper.tres")
	var grunt = load("res://resources/figures/grunt.tres")
	run.start_new_run(5)
	for act in 3:
		run.act = act
		var tier1 := 0
		var tier2 := 0
		var e_tier1 := 0
		var e_tier2 := 0
		var n := 4000
		for i in n:
			var r: Vector2i = run._roll_enemy_upgrade(bumper, false)
			if r.x >= 0:
				tier1 += 1
			if r.y >= 2:
				tier2 += 1
			var t: Vector2i = run._roll_enemy_upgrade(bumper, true)
			if t.x >= 0:
				e_tier1 += 1
			if t.y >= 2:
				e_tier2 += 1
		print("    act %d: regular tier1 %.0f%% tier2 %d | elite tier1 %.0f%% tier2 %.0f%% of rolled" % [act + 1, 100.0 * tier1 / n, tier2, 100.0 * e_tier1 / n, 100.0 * e_tier2 / maxf(e_tier1, 1)])
		var want_reg: float = [0.15, 0.30, 0.45][act]
		var want_elite: float = [0.30, 0.45, 0.45][act]
		var want_t2: float = [0.25, 0.5, 0.5][act]
		_check(absf(tier1 / float(n) - want_reg) < 0.04 and tier2 == 0, "act %d regular: ~%d%% tier 1, never tier 2" % [act + 1, want_reg * 100])
		_check(absf(e_tier1 / float(n) - want_elite) < 0.04 and absf(e_tier2 / maxf(e_tier1, 1.0) - want_t2) < 0.07, "act %d elite/boss: next-act tier 1 rate and tier 2 chance" % [act + 1])
	_check(run._roll_enemy_upgrade(grunt, true) == run.NO_UPGRADE, "figures without a tree (Grunt, bosses) roll none")

	print("Level 1 gives no upgrade tiers")
	var upgraded := 0
	for ascension in [1, 4]:
		run.start_new_run(ascension)
		run.act = 2
		for i in 40:
			var node := MapNode.new()
			node.type = MapNode.Type.ELITE
			node.column = 4
			run.node = node
			run._build_lineup()
			for g in run.enemy_gear:
				if g.upgrade.x >= 0 and g.upgrade != Vector2i(-1, 0):
					upgraded += 1
	_check(upgraded == 0, "no enemy upgrades at levels 1-4 over 80 act 3 elite lineups (%d)" % upgraded)
	run.start_new_run(5)
	run.act = 2
	for i in 40:
		var node := MapNode.new()
		node.type = MapNode.Type.ELITE
		node.column = 4
		run.node = node
		run._build_lineup()
		for g in run.enemy_gear:
			if g.upgrade.x >= 0:
				upgraded += 1
	_check(upgraded > 0, "level 5 elites do carry upgrades (%d)" % upgraded)

	print("Skull-o-tron: any pin contact breaks an arm at once")
	var skull = load("res://resources/figures/boss_skull_o_tron.tres")
	Setup.begin()
	Setup.lineup_kind = "boss"
	Setup.boss = skull
	Setup.arena = run.config.boss_arena
	await _load()
	var boss = _main._enemies[0]
	var ability = boss.ability
	var before: int = ability.arms_left()
	var enemies_before: int = _main._enemies.size()
	_check(before == 3, "starts with 3 arms")
	var arm_ball: Node = ability._arms[0].ball
	var pin := StaticBody2D.new()
	pin.collision_layer = 8  # Figure.LAYER_ARENA
	pin.add_to_group("pins")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	pin.add_child(shape)
	_main.add_child(pin)
	pin.global_position = arm_ball.global_position
	await _frames(4)
	_check(ability.arms_left() == before - 1, "one arm broke off at a motionless pin touch (arms %d)" % ability.arms_left())
	_check(_main._enemies.size() == enemies_before + 1, "it became a Skull Ball")
	pin.queue_free()

	print("AI sweep: an enemy with every upgrade tier 2 takes its turn")
	var failures := 0
	var cases := 0
	Engine.time_scale = 3.0
	for tree in run.config.upgrade_trees:
		var data = tree.figure
		if run.config.registry.economy.has(data):
			continue
		for path in 2:
			Setup.begin()
			Setup.lineup_kind = "none"
			Setup.arena = run.config.arenas[0]
			Setup.ai_off = false
			Setup.entries.append(_entry(grunt, 0, Vector2(540, 1500)))
			Setup.entries.append(_entry(grunt, 0, Vector2(540, 1000)))
			Setup.entries.append(_entry(data, 1, Vector2(540, 600), Vector2(path, 2)))
			await _load()
			await _until(func(): return _main._state == 0)
			var player = _main._players[0]
			var turns_before: int = _main._enemy_turns_taken
			_main._on_press(0, player.global_position)
			_main._release_aim(player.global_position + Vector2(0, 40))
			var ok = await _until(func(): return _main._enemy_turns_taken > turns_before and _main._state == 0, 20.0)
			cases += 1
			print("    %s path %d: %s" % [data.display_name, path, "ok" if ok else "STUCK"])
			if not ok:
				failures += 1
	_check(failures == 0, "all %d figure/path cases completed an enemy turn (%d stuck)" % [cases, failures])

	Setup.end()
	print()
	if _fails.is_empty():
		print("ALL ASCENSION TESTS PASSED")
		quit(0)
	else:
		printerr("%d FAILED:" % _fails.size())
		for f in _fails:
			printerr("  - " + f)
		quit(1)
