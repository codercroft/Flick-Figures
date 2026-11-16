extends SceneTree
## Records the enemy AI's shot choice on fixed-seed positions, so a refactor of enemy_ai.gd can be checked for IDENTICAL
## choices:  godot --headless -s tools/balance/ai_regression.gd -- --out=/tmp/ai_before.json [--count=60]
## Run it before and after the change and diff the two files (run_sims.py --check-ai does that against git HEAD).
## Positions: every regular / elite encounter and boss, a random deck of draftable figures, every figure teleported to a
## seeded random spot (some player figures off the deck), then ai.choose_flick() with a seeded RNG.

var _out := "/tmp/ai_choices.json"
var _count := 60


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--count="):
			_count = int(arg.substr(8))
	_go()


func _go() -> void:
	for i in 3:
		await process_frame
	var Fight = load("res://tools/balance/fight_runner.gd")
	var runner = Fight.new(self)
	var run = root.get_node("RunManager")
	var cfg = run.config
	var targets: Array = []
	for e in cfg.regular_encounters:
		targets.append({"kind": "encounter", "encounter": e, "act": e.acts[0]})
	for e in cfg.elite_encounters:
		targets.append({"kind": "elite", "encounter": e, "act": e.acts[0]})
	for b in cfg.registry.bosses:
		targets.append({"kind": "boss", "boss": b, "act": 2})
	var draftable: Array = cfg.registry.draftable
	var results: Array = []
	var rng := RandomNumberGenerator.new()
	for i in _count:
		rng.seed = 1000 + i
		var target: Dictionary = targets[i % targets.size()]
		var deck: Array = []
		for s in 4:
			deck.append(Fight.slot(draftable[rng.randi() % draftable.size()]))
		var spec := target.duplicate()
		spec["deck"] = deck
		spec["seed"] = 500 + i
		spec["ascension"] = 3 if i % 3 == 0 else 0  # (some with act scaling and gear, so those code paths are covered)
		runner.prepare(spec)
		runner.start_combat()
		var main = runner.main
		main.ai.think_budget_ms = 100000000
		await physics_frame
		await physics_frame
		# Scatter every figure over the board with the seeded RNG (no overlaps).
		var board: Rect2 = main.board.board_rect
		var placed: Array[Vector2] = []
		for f in main.get_all_figures():
			for attempt in 40:
				var p := Vector2(rng.randf_range(board.position.x + 90.0, board.end.x - 90.0), rng.randf_range(board.position.y + 90.0, board.end.y - 90.0))
				var clear := true
				for q in placed:
					if p.distance_to(q) < 190.0:
						clear = false
				if clear:
					placed.append(p)
					if f.team == Figure.Team.PLAYER:
						f.on_deck = rng.randf() < 0.3
						f._update_collision()
					f.teleport_to(p)
					break
		await physics_frame
		await physics_frame
		seed(7000 + i)
		var candidates: Array = main._flick_candidates()
		var t0 := Time.get_ticks_msec()
		var choice: Dictionary = main.ai.choose_flick(candidates, main._players, main.board.get_table_rect(), main.max_flick_force)
		var row := {"i": i, "target": runner.run.encounter_name if run.encounter_name != "" else run.boss.display_name if run.boss != null else "-", "ms": Time.get_ticks_msec() - t0}
		if choice.is_empty():
			row["choice"] = "pass"
		else:
			row["enemy"] = main._enemies.find(choice.enemy)
			for key in ["impulse", "shot_point", "spray_point", "pin"]:
				if choice.has(key):
					var v: Vector2 = choice[key]
					row[key] = [snappedf(v.x, 0.01), snappedf(v.y, 0.01)]
			for key in ["spray_seconds", "pin_only", "pass"]:
				if choice.has(key):
					row[key] = choice[key]
		results.append(row)
		runner.finish_combat()
		await process_frame
	var file := FileAccess.open(_out, FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	file.close()
	var total := 0
	for r in results:
		total += int(r.ms)
	print("ai_regression: %d positions written to %s (%d ms of thinking)" % [results.size(), _out, total])
	quit(0)
