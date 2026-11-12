extends SceneTree
## Land Miner / Firecracker removal / Blastoid Nuke / Juicer test: godot --headless -s tools/land_miner_test.gd
## (exit 1 on failure; also look for "SCRIPT ERROR" in the output).

var _fails: Array[String] = []
var _main: Node
const LM := "res://resources/figures/land_miner.tres"


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


func _mines(team := -1) -> Array:
	return get_nodes_in_group("mines").filter(func(m): return team < 0 or m.team == team)


func _flick(fig: Node, drag := Vector2(0, 400)) -> void:
	var p: Vector2 = fig.global_position
	_main._on_press(0, p)
	_main._release_aim(p + drag)


func _all() -> void:
	await create_timer(0.5).timeout
	var run = root.get_node("RunManager")
	var cfg = run.config
	var grunt = load("res://resources/figures/grunt.tres")
	var lm = load(LM)

	print("Firecracker is gone, Land Miner is in")
	_check(not ResourceLoader.exists("res://resources/figures/firecracker.tres"), "firecracker.tres deleted")
	_check(cfg.registry.draftable.has(lm) and lm.rarity == 1 and lm.display_name == "Land Miner", "Land Miner is a draftable Uncommon")
	_check(not cfg.registry.is_explosive(lm), "Land Miner is not an explosive-tag figure (mines are not a figure explosion)")
	_check(run.tree_for(lm) != null and run.tree_for(lm).path_a_name == "Multi-Mine" and run.tree_for(lm).path_b_name == "Smart Bombs", "upgrade tree Multi-Mine / Smart Bombs")
	var uses_fc := 0
	for p in ["tinderbox", "powder_keg", "fireworks"]:
		pass
	for enc in cfg.regular_encounters + cfg.elite_encounters:
		var names := {}
		for e in enc.enemies:
			names[e.figure.display_name] = names.get(e.figure.display_name, 0) + e.count
		if enc.display_name == "Tinderbox":
			_check(names == {"Bombo": 1, "Land Miner": 2}, "Tinderbox = Bombo + 2 Land Miners %s" % names)
		if enc.display_name == "Fireworks":
			_check(names == {"Land Miner": 2, "Speedo": 2, "Magnet": 1}, "Fireworks = 2 Land Miners + 2 Speedos + Magnet %s" % names)
		if enc.display_name == "Powder Keg":
			_check(names == {"Land Miner": 1, "Aggro-bom": 1, "Bombo": 2}, "Powder Keg = Land Miner + Aggro-bom + 2 Bombos %s" % names)

	print("Saved run: a Firecracker becomes a Land Miner with no upgrade")
	var RS = load("res://scripts/run_save.gd")
	var path := "user://run_save.json"
	var backup := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	run.start_new_run(0)
	RS.save(run)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	parsed["deck"][0] = "res://resources/figures/firecracker.tres"
	parsed["deck_upgrade_state"][0] = [0, 2]
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(parsed))
	f.close()
	run.start_new_run(0)
	RS.load_into(run)
	_check(run.deck[0] == lm and run.deck_upgrade[0].x < 0, "deck slot 0 is a Land Miner without upgrades")
	if backup != "":
		var g := FileAccess.open(path, FileAccess.WRITE)
		g.store_string(backup)
		g.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	print("Dropping mines")
	await _start([_entry(lm, 0, Vector2(540, 1500)), _entry(grunt, 1, Vector2(900, 400))])
	var miner = _main._players[0]
	var start := Vector2(miner.global_position)
	_check(miner.ability.get_flicks_per_turn(miner) == 1, "average figure")
	var full_travel: float = (2400.0 * lm.flick_power_multiplier / lm.mass - miner.stop_speed) / miner.linear_damp
	print("    full-power travel ~%d px, spacing %d" % [full_travel, miner.ability.mine_spacing])
	_check(full_travel / miner.ability.mine_spacing >= 3.5 and full_travel / miner.ability.mine_spacing < 4.5, "a full-power flick drops about 4 mines (%.2f x spacing)" % (full_travel / miner.ability.mine_spacing))
	_flick(miner, Vector2(0, 220))  # a partial flick that stays on the table
	await _until(func(): return miner.is_resting() or _main._state == 0, 15.0)
	await create_timer(0.5).timeout
	var dropped := _mines(0)
	var travel := start.distance_to(miner.global_position)
	print("    travel %d px, %d mines" % [travel, dropped.size()])
	_check(absi(dropped.size() - int(travel / miner.ability.mine_spacing)) <= 1, "one mine per spacing traveled (%d mines over %d px)" % [dropped.size(), travel])
	if dropped.size() > 0:
		var first: Node = dropped[0]
		_check(absf(first.global_position.distance_to(start) - miner.ability.mine_spacing) < 60.0, "the first mine is ~N px from the start, not at the start (%d px)" % first.global_position.distance_to(start))
		_check(first.team == 0, "mine belongs to the player")

	print("Base numbers, shoved movement, carry-over, outside table, minimum gap")
	await _start([_entry(lm, 0, Vector2(540, 1500))])
	miner = _main._players[0]
	var ab0 = miner.ability
	_check(ab0.mine_spacing == 400.0 and ab0.explosion_radius == 180.0 and ab0.explosion_force == 1800.0 and ab0.max_mines == 12, "base: spacing 400, blast 180 / 1800, cap 12")
	_check(2400.0 / 1.5 / ab0.mine_spacing > 3.5 and 2400.0 / 1.5 / ab0.mine_spacing < 4.5, "a full-power flick drops about 4 mines (%.1f)" % (1590.0 / ab0.mine_spacing))
	var p0: Vector2 = miner.global_position
	miner.linear_velocity = Vector2(0, -1000)  # shoved (no flick of its own)
	await _until(func(): return miner.is_resting(), 10.0)
	var shoved := _mines(0).size()
	var shoved_travel := p0.distance_to(miner.global_position)
	_check(shoved >= 1 and absi(shoved - int(shoved_travel / 400.0)) <= 1, "a shove drops mines too (%d over %d px)" % [shoved, shoved_travel])
	for m in _mines():
		m.queue_free()
	await _frames(2)
	ab0._since_drop = 0.0
	ab0._last_position = Vector2.INF
	miner.global_position = Vector2(540, 1400)
	await _frames(2)
	var base_pos: Vector2 = miner.global_position
	miner.linear_velocity = Vector2(300, 0)
	await _frames(6)
	miner.linear_velocity = Vector2.ZERO
	await _frames(3)
	var half := _mines(0).size()
	var carried: float = ab0._since_drop
	miner.linear_velocity = Vector2(-300, 0)
	await _frames(6)
	miner.linear_velocity = Vector2.ZERO
	print("    counter after first nudge %d px" % carried)
	_check(half == 0 and carried > 0.0 and ab0._since_drop > carried, "the distance counter keeps running between movements")
	_check(not ab0.maybe_drop(miner, Vector2(5, 5)), "no mine outside the table")
	_check(ab0.maybe_drop(miner, Vector2(540, 900)) and not ab0.maybe_drop(miner, Vector2(560, 900)), "no mine within 40 px of another mine")

	print("Cap, trigger rules, friendly blasts")
	await _start([_entry(lm, 0, Vector2(540, 1500)), _entry(grunt, 0, Vector2(300, 1000)), _entry(grunt, 1, Vector2(540, 600)), _entry(grunt, 1, Vector2(800, 700))])
	miner = _main._players[0]
	miner.ability.max_mines = 3
	miner.ability.min_mine_gap = 0.0
	for i in 5:
		miner.ability.maybe_drop(miner, Vector2(150 + i * 60, 1500))
	await _frames(3)
	var cap_count := _mines(0).filter(func(m): return m.global_position.y > 1450).size()
	_check(cap_count == 3, "max 3 mines per Land Miner, oldest removed (%d)" % cap_count)
	for m in _mines():
		m.queue_free()
	await _frames(2)
	var ally = _main._players[1]
	var enemy_a = _main._enemies[0]
	var enemy_b = _main._enemies[1]
	miner.ability.maybe_drop(miner, ally.global_position + Vector2(20, 0))  # next to our own figure
	miner.ability.maybe_drop(miner, enemy_b.global_position + Vector2(0, 110))  # near enemy B but outside its trigger radius
	miner.ability.maybe_drop(miner, enemy_a.global_position + Vector2(0, 60))  # triggered by enemy A
	await _frames(6)
	_check(_mines(0).size() == 2, "only the mine an opposing figure came near went off (%d left)" % _mines(0).size())
	_check(ally.linear_velocity.length() < 1.0 and ally.global_position.distance_to(Vector2(300, 1000)) < 2.0, "the player's own mine blast does not push player figures")
	_check(enemy_a.linear_velocity.length() > 20.0 or enemy_a.global_position.distance_to(Vector2(540, 600)) > 5.0, "the opposing figure was pushed")
	_check(_mines(0).any(func(m): return m.global_position.distance_to(enemy_b.global_position + Vector2(0, 110)) < 2.0), "a blast does not set other mines off")
	await create_timer(1.0).timeout

	print("Enemy mines push their own side too; homing")
	await _start([_entry(lm, 1, Vector2(540, 400)), _entry(grunt, 1, Vector2(600, 700)), _entry(grunt, 0, Vector2(540, 800)), _entry(grunt, 0, Vector2(800, 1500))])
	var emin = _main._enemies[0]
	var eally = _main._enemies[1]
	var player_fig = _main._players[1]
	emin.ability.maybe_drop(emin, Vector2(560, 780))  # the player figure is 20 px from it
	await _frames(6)
	_check(_mines(1).is_empty(), "an enemy mine went off under the player figure")
	_check(eally.linear_velocity.length() > 5.0 or eally.global_position.distance_to(Vector2(600, 700)) > 3.0, "the enemy's own explosion still pushes its own side")
	await create_timer(1.0).timeout
	emin.ability.homing_range = 250.0
	emin.ability.maybe_drop(emin, Vector2(300, 700))
	var mine: Node = _mines(1)[0]
	var before: Vector2 = mine.global_position
	await _frames(10)
	_check(mine.global_position.distance_to(before) < 0.5, "a homing mine stays put while nothing moves near it")
	player_fig.global_position = Vector2(450, 700)
	player_fig.on_deck = false
	for i in 4:
		player_fig.linear_velocity = Vector2(300, 0)
		await _frames(1)
	print("    mine %s -> %s, figure speed %d slow %s" % [before, mine.global_position if is_instance_valid(mine) else "gone", player_fig.linear_velocity.length(), player_fig.is_slow()])
	_check(not is_instance_valid(mine) or mine.global_position.distance_to(before) > 1.0, "a homing mine drifts toward a moving opponent in range")

	print("Land Miner upgrade numbers")
	for case in [[Vector2(0, 1), 268.0, 180.0, 1800.0], [Vector2(0, 2), 268.0, 180.0, 2520.0], [Vector2(0, 3), 200.0, 180.0, 2520.0],
			[Vector2(1, 1), 400.0, 234.0, 2340.0], [Vector2(1, 2), 320.0, 269.1, 2691.0], [Vector2(1, 3), 320.0, 269.1, 2691.0]]:
		await _start([_entry(lm, 0, Vector2(540, 1500), case[0])])
		var a = _main._players[0].ability
		var ok: bool = absf(a.mine_spacing - case[1]) < 5.0 and absf(a.explosion_radius - case[2]) < 2.0 and absf(a.explosion_force - case[3]) < 6.0
		_check(ok, "%s: spacing %.0f radius %.0f force %.0f homing %.0f" % [case[0], a.mine_spacing, a.explosion_radius, a.explosion_force, a.homing_range])
		if case[0] == Vector2(1, 3):
			_check(a.homing_range == 250.0, "Smart Bombs tier 3 homing range 250")

	print("Enemy Land Miner takes AI turns")
	var mines_laid := 0
	await _start([_entry(grunt, 0, Vector2(540, 1500)), _entry(grunt, 0, Vector2(300, 1500)), _entry(lm, 1, Vector2(540, 400))], false)
	Engine.time_scale = 3.0
	for turn in 3:
		var tb: int = _main._enemy_turns_taken
		var pl = _main._players[turn % 2]
		_flick(pl, Vector2(0, 80))
		var ok = await _until(func(): return _main._enemy_turns_taken > tb and _main._state == 0, 30.0)
		_check(ok, "enemy turn %d completed" % (turn + 1))
	mines_laid = _mines(1).size()
	print("    enemy mines on the board after 3 turns: %d" % mines_laid)
	Engine.time_scale = 1.0

	print("Blastoid Nuke: the target takes a huge direct hit, the others the earthquake")
	var blastoid = load("res://resources/figures/blastoid.tres")
	await _start([_entry(blastoid, 0, Vector2(540, 1500), Vector2(1, 3)), _entry(grunt, 1, Vector2(540, 900)), _entry(grunt, 1, Vector2(250, 700))])
	var shooter = _main._players[0]
	var target = _main._enemies[0]
	var other = _main._enemies[1]
	var ab = shooter.ability
	_check(ab.direct_hit_multiplier == 2.5 and ab.earthquake_on_hit, "Nuke tier 3: direct_hit_multiplier 2.5 and earthquake_on_hit")
	ab.on_projectile_hit(shooter, target, Vector2.UP)
	await physics_frame
	await physics_frame
	var expected: float = ab.blast_force * run.explosion_force_multiplier() * ab.direct_hit_falloff * 2.5 / target.mass
	var got: float = target.linear_velocity.length()
	print("    direct hit speed %d (expected ~%d), direction %s; other enemy speed %d" % [got, expected, target.linear_velocity.normalized(), other.linear_velocity.length()])
	_check(absf(got - expected) < expected * 0.08 and target.linear_velocity.normalized().dot(Vector2.UP) > 0.999, "direct hit = 2.5 x the rocket's own push, along the rocket's direction")
	_check(other.linear_velocity.length() > 100.0, "the other enemy got the earthquake")
	# And through a real rocket: the target is flung far (and the plain rocket is much weaker).
	var peaks := {}
	for tier in [0, 3]:
		await _start([_entry(blastoid, 0, Vector2(540, 1500), Vector2(1, tier) if tier > 0 else Vector2(-1, 0)), _entry(grunt, 1, Vector2(540, 900))])
		shooter = _main._players[0]
		target = _main._enemies[0]
		shooter.ability.fire_shot_at(shooter, target.global_position)
		var peak := 0.0
		for i in 120:
			await physics_frame
			if not is_instance_valid(target) or target.knocked_off:
				peak = maxf(peak, 99999.0 if tier == 3 else peak)
				break
			peak = maxf(peak, target.linear_velocity.length())
		peaks[tier] = peak
	print("    rocket peaks: plain %d, nuke %d" % [peaks[0], peaks[3]])
	_check(peaks[3] > 2.5 * peaks[0], "a real Nuke rocket hits far harder than a plain one")

	print("Juicer trail pushes the way it moves")
	var juicer = load("res://resources/figures/juicer.tres")
	await _start([_entry(juicer, 0, Vector2(540, 1500))])
	var j = _main._players[0]
	_flick(j)
	await _until(func(): return j.is_resting() or _main._state == 0, 15.0)
	var pieces: Array = _main.arena._trail
	var good := 0
	for piece in pieces:
		if piece.direction.y < -0.9:
			good += 1
	_check(pieces.size() > 2 and good == pieces.size(), "all %d trail pieces point up (the flick's direction)" % pieces.size())

	Engine.time_scale = 1.0
	print()
	if _fails.is_empty():
		print("ALL LAND MINER TESTS PASSED")
		quit(0)
	else:
		printerr("%d FAILED:" % _fails.size())
		for x in _fails:
			printerr("  - " + x)
		quit(1)
