extends SceneTree
## Fat Man turn timing: a grab turn and a throw turn must resolve quickly (not wait for the 6 s settle timeout).
## godot --headless -s tools/fat_timing_test.gd (exit 1 on failure).

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


func _all() -> void:
	await create_timer(0.5).timeout
	var run = root.get_node("RunManager")
	var grunt = load("res://resources/figures/grunt.tres")
	var fat_boss = load("res://resources/figures/boss_fat_man.tres")
	var Setup = load("res://scripts/sandbox_setup.gd")
	Setup.begin()
	Setup.lineup_kind = "boss"
	Setup.boss = fat_boss
	Setup.arena = run.config.boss_arena
	Setup.ai_off = false
	for pos in [Vector2(540, 1500), Vector2(300, 1500), Vector2(780, 1500)]:
		Setup.entries.append({"data": grunt, "team": 0, "pos": pos, "equipment": null, "finish": null, "upgrade": Vector2i(-1, 0), "node": null})
	Setup.prepare()
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	current_scene = _main
	await _frames(4)
	while _main._state != 0:
		await create_timer(0.1).timeout
	for turn in 2:
		print("    start turn %d state %d held %d" % [turn + 1, _main._state, _main._fat_man.held_figures().size()])
		var p = null
		for f in _main._players:
			if not f.held and f.flickable:
				p = f
				break
		var start: Vector2 = p.global_position
		_main._on_press(0, start)
		_main._release_aim(start + Vector2(0, 120))
		# time from the player's flick to the player's next turn (includes the player's own settle)
		var t0 := Time.get_ticks_msec()
		while _main._state == 0 or _main._state == 1:
			await create_timer(0.02).timeout
		var enemy_start := 0
		var seen_enemy := false
		while true:
			await create_timer(0.05).timeout
			if _main._state == 3 and not seen_enemy:
				seen_enemy = true
				enemy_start = Time.get_ticks_msec()
			if seen_enemy and _main._state == 0:
				break
			if Time.get_ticks_msec() - t0 > 30000:
				break
		var enemy_time := (Time.get_ticks_msec() - enemy_start) / 1000.0
		var held: int = _main._fat_man.held_figures().size()
		print("    turn %d (%s): enemy turn took %.1f s, held now %d" % [turn + 1, "grab" if turn == 0 else "throw", enemy_time, held])
		_check(enemy_time < 4.0, "the %s turn resolves in under 4 s (%.1f s)" % ["grab" if turn == 0 else "throw", enemy_time])
	_main.queue_free()
	print("\n%s" % ("ALL OK" if _fails.is_empty() else "FAILED: %s" % ", ".join(_fails)))
	quit(1 if not _fails.is_empty() else 0)
