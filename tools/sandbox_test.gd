extends SceneTree
## Sandbox mode test: godot --headless -s tools/sandbox_test.gd (exit 1 on failure).
## Loads the real combat scene in sandbox mode and checks placement, gear, bosses, encounters, AI off, free flick
## and that nothing touches the run save, run history or unlocks.

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


func _until(cond: Callable, seconds := 30.0) -> bool:
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
	var setup = load("res://scripts/sandbox_setup.gd")
	setup.prepare()
	_main = load("res://scenes/main.tscn").instantiate()
	_main.enemy_think_time = 0.05
	root.add_child(_main)
	current_scene = _main
	await _frames(5)


func _all() -> void:
	await create_timer(0.5).timeout
	var Setup = load("res://scripts/sandbox_setup.gd")
	var run = root.get_node("RunManager")
	var history_before := FileAccess.file_exists("user://run_history.json")
	var save_before := FileAccess.file_exists("user://run_save.json")
	Setup.begin()
	print("Empty sandbox")
	await _load()
	_check(_main.sandbox != null, "panel exists")
	_check(_main._enemies.is_empty() and _main._players.is_empty(), "no figures yet")
	_check(_main._state == 0, "player turn state")

	print("Placing figures")
	var panel = _main.sandbox
	var grunt = load("res://resources/figures/grunt.tres")
	var speedo = load("res://resources/figures/speedo.tres")
	var table: Rect2 = _main.board.get_table_rect()
	var pos_p: Vector2 = _main.board.deck_rect.get_center()
	var pos_e: Vector2 = _main.board.board_rect.position + Vector2(450, 250)
	Setup.mode = Setup.Mode.EDIT
	panel.place_data = speedo
	panel.place_team = 0
	panel._finish_touch(pos_p)
	panel.place_data = grunt
	panel.place_team = 1
	panel._finish_touch(pos_e)
	_check(_main._players.size() == 1 and _main._enemies.size() == 1, "one player, one enemy placed")
	_check(_main._players[0].on_deck, "player placed in the deck strip is on deck")
	_check(Setup.entries.size() == 2, "entries recorded")

	print("Gear on a placed figure")
	var fig = _main._players[0]
	panel._select(fig)
	panel._set_equipment(1)  # first equipment item
	_check(_main._players.size() == 1 and Setup.entries[0].equipment != null and _main._players[0].equipment != null, "equipment applied by respawn")
	var tree = run.tree_for(speedo)
	panel._select(_main._players[0])
	panel._set_upgrade(1)
	_check(_main._players[0].upgrade_state == Vector2i(0, 1), "upgrade A1 applied")
	panel._set_finish(1)
	_check(_main._players[0].finish != null, "finish applied")

	print("Moving and deleting")
	var e = _main._enemies[0]
	panel._move_figure(e, _main.board.board_rect.position + Vector2(300, 400))
	_check(e.global_position.distance_to(_main.board.board_rect.position + Vector2(300, 400)) < 1.0, "moved")
	_check(Setup.entries[1].pos.distance_to(e.global_position) < 1.0, "entry position follows")
	panel._select(e)
	panel._delete_selected()
	await _frames(2)
	_check(_main._enemies.is_empty() and Setup.entries.size() == 1, "deleted")

	print("Reset keeps the setup")
	Setup.mode = Setup.Mode.PLAY
	await _load()
	_check(_main._players.size() == 1 and _main._players[0].equipment != null, "player with gear back after reload")

	print("Every boss at Ascension 0 and 8")
	for boss in run.config.registry.bosses:
		for asc in [0, 8]:
			Setup.lineup_kind = "boss"
			Setup.boss = boss
			Setup.ascension = asc
			Setup.act = 2
			await _load()
			_check(not _main._enemies.is_empty(), "%s (A%d): %d enemies" % [boss.display_name, asc, _main._enemies.size()])

	print("Every encounter")
	Setup.ascension = 0
	Setup.act = 0
	for enc in run.config.regular_encounters + run.config.elite_encounters:
		Setup.lineup_kind = "encounter"
		Setup.encounter = enc
		Setup.boss = null
		await _load()
		_check(not _main._enemies.is_empty(), "%s: %d enemies" % [enc.display_name, _main._enemies.size()])

	print("Every arena")
	Setup.lineup_kind = "none"
	for a in run.config.arenas:
		Setup.arena = a
		await _load()
	_check(true, "all %d arenas load" % run.config.arenas.size())

	print("AI off: the user flicks the enemy")
	Setup.entries.clear()
	Setup.lineup_kind = "none"
	Setup.arena = run.config.arenas[0]
	Setup.entries.append({"data": grunt, "team": 0, "pos": _main.board.deck_rect.get_center(), "equipment": null, "finish": null, "upgrade": Vector2i(-1, 0), "node": null})
	Setup.entries.append({"data": grunt, "team": 1, "pos": Vector2(540, 600), "equipment": null, "finish": null, "upgrade": Vector2i(-1, 0), "node": null})
	Setup.ai_off = true
	await _load()
	await _until(func(): return _main._state == 0)
	var p = _main._players[0]
	_main._on_press(0, p.global_position)
	_main._release_aim(p.global_position + Vector2(0, 60))
	var ok = await _until(func(): return _main._manual_enemy and _main._state == 0)
	_check(ok, "after the player's flick it is the user's enemy turn (AI did not act)")
	var en = _main._enemies[0]
	var turns_before: int = _main._enemy_turns_taken
	_main._on_press(0, en.global_position)
	_main._release_aim(en.global_position + Vector2(0, -60))
	ok = await _until(func(): return not _main._manual_enemy and _main._state == 0, 30.0)
	_check(ok and _main._enemy_turns_taken == turns_before, "enemy flicked manually, then back to the player")
	Setup.ai_off = false

	print("Free flick: anything, any time")
	Setup.free_flick = true
	await _load()
	var a = _main._players[0]
	var b = _main._enemies[0]
	_main._on_press(0, a.global_position)
	_main._release_aim(a.global_position + Vector2(0, 60))
	_check(_main._state == 0 and a.flickable, "state stays PLAYER_TURN right after a flick")
	_main._on_press(1, b.global_position)
	_main._release_aim(b.global_position + Vector2(0, -60))
	_check(b.turn_flicks == 1 and a.turn_flicks == 1, "both figures flicked back to back, no turn change")
	Setup.free_flick = false

	print("Isolation")
	_check(FileAccess.file_exists("user://run_history.json") == history_before, "run history file untouched")
	_check(FileAccess.file_exists("user://run_save.json") == save_before, "run save untouched")
	Setup.end()
	print()
	if _fails.is_empty():
		print("ALL SANDBOX TESTS PASSED")
		quit(0)
	else:
		printerr("%d FAILED:" % _fails.size())
		for f in _fails:
			printerr("  - " + f)
		quit(1)
