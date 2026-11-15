extends SceneTree
## New relics test (Lucky Coin, Wet Explosions, Rich Boys, Safety Net, Out the Gate): godot --headless -s tools/relics_test.gd
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


func _entry(data, team: int, pos: Vector2) -> Dictionary:
	return {"data": data, "team": team, "pos": pos, "equipment": null, "finish": null, "upgrade": Vector2i(-1, 0), "node": null}


func _start(entries: Array, player_relics: Array = [], enemy_relics: Array = [], ai_off := true) -> void:
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
	for r in player_relics:
		Setup.player_relics.append(r)
	for r in enemy_relics:
		Setup.enemy_relics.append(r)
	Setup.prepare()
	_main = load("res://scenes/main.tscn").instantiate()
	_main.enemy_think_time = 0.02
	root.add_child(_main)
	current_scene = _main
	await _frames(6)
	await _until(func(): return _main._state == 0)


func _flick(fig, drag := Vector2(0, 60)) -> void:
	var p: Vector2 = fig.global_position
	_main._on_press(0, p)
	_main._release_aim(p + drag)


func _relic(name: String):
	for r in root.get_node("RunManager").config.relic_pool:
		if r.display_name == name:
			return r
	return null


func _all() -> void:
	await _frames(3)
	var run = root.get_node("RunManager")
	var cfg = run.config
	var GR = load("res://resources/figures/grunt.tres")
	var BO = load("res://resources/figures/bombo.tres")
	var Fig = load("res://scripts/figure.gd")
	var lucky = _relic("Lucky Coin")
	var wet = _relic("Wet Explosions")
	var rich = _relic("Rich Boys")
	var net = _relic("Safety Net")
	var gate = _relic("Out the Gate")

	print("Data")
	_check(lucky.effect.get_income_bonus() == 2, "Lucky Coin pays +$2")
	_check(wet != null and wet.rarity == 0 and rich != null and rich.rarity == 1 and rich.economy and net != null and net.rarity == 2 and gate != null and gate.rarity == 3, "rarities: Wet Common, Rich Boys Uncommon (economy), Safety Net Rare, Out the Gate Boss")
	var enemy_pool: Array = cfg.elite_config.enemy_relic_pool
	_check(enemy_pool.has(wet) and enemy_pool.has(net) and not enemy_pool.has(rich) and not enemy_pool.has(gate), "Wet Explosions and Safety Net can be enemy relics; Rich Boys and Out the Gate cannot")
	var in_shop := false
	for offer in cfg.shop.make_offers(cfg.registry):
		if offer.title.contains("Out the Gate"):
			in_shop = true
	_check(not in_shop, "the Boss relic is never in the shop")

	print("Income: Rich Boys")
	run.relics.clear()
	run.money = 0
	var figs: Array[FigureData] = [GR, GR, GR]
	run.award_income(figs, 0)
	var normal: int = run.last_income.total
	run.relics.append(rich)
	run.money = 0
	run.award_income(figs, 0)
	_check(run.last_income.total == normal + 3 and run.last_income.base == 6, "3 figures pay $2 each instead of $1 (%d vs %d)" % [run.last_income.total, normal])
	run.relics.clear()

	print("Wet Explosions")
	await _start([_entry(BO, 0, Vector2(400, 1100)), _entry(GR, 1, Vector2(700, 700)), _entry(GR, 0, Vector2(300, 1300))], [wet])
	var enemy = _main._enemies[0]
	var friend = _main._players[1]
	var center: Vector2 = enemy.global_position + Vector2(0, 80)
	Fig.blast(_main.get_tree(), center, 250.0, 1000.0, _main._players[0], null, 0)
	await _frames(2)
	_check(enemy.is_doused() and absf(enemy.doused_multiplier - 1.3) < 0.001 and enemy.doused_rounds == 2, "an enemy hit by the player's explosion is Doused (x%.2f, %d rounds)" % [enemy.doused_multiplier, enemy.doused_rounds])
	_check(not friend.is_doused(), "own figures are not Doused")
	enemy.douse(2, 1.5)
	Fig.blast(_main.get_tree(), center, 250.0, 1000.0, _main._players[0], null, 0)
	await _frames(2)
	_check(absf(enemy.doused_multiplier - 1.5) < 0.001, "a stronger Douse is kept (x%.2f)" % enemy.doused_multiplier)
	await _start([_entry(GR, 0, Vector2(400, 1100)), _entry(GR, 1, Vector2(700, 700))], [], [wet])
	var player = _main._players[0]
	Fig.blast(_main.get_tree(), player.global_position + Vector2(0, -80), 250.0, 1000.0, _main._enemies[0], null, 1)
	await _frames(2)
	_check(player.is_doused(), "enemy relic: the enemy's explosions Douse player figures")

	print("Safety Net")
	await _start([_entry(GR, 0, Vector2(540, 1480)), _entry(GR, 1, Vector2(700, 500))], [net])
	var eff = net.effect
	_check(eff.on_enemy_turn_start(_main, 0) == 0.0 and _main.arena._edge_walls.is_empty(), "nothing on the first enemy turn")
	_check(eff.on_enemy_turn_start(_main, 1) > 0.0 and _main.arena._edge_walls.size() == 1, "the wall appears on the second enemy turn")
	await _frames(3)
	var runner = _main._players[0]
	runner.on_deck = false
	runner._update_collision()
	runner.teleport_to(Vector2(540, 1250))
	await _frames(2)
	runner.linear_velocity = Vector2(0, 1800)
	await _frames(60)
	_check(is_instance_valid(runner) and not runner.knocked_off, "a figure flying at the bottom edge is not knocked off")
	_check(is_instance_valid(runner) and _main.board.get_table_rect().has_point(runner.global_position), "and stays on the table (%s)" % (runner.global_position if is_instance_valid(runner) else Vector2.ZERO))
	_main.arena.remove_edge_walls()
	_check(_main.arena._edge_walls.is_empty(), "the wall is removed")
	_main.arena.place_edge_wall(1, _main.board.get_table_rect(), true, 30.0, 60.0)
	var table: Rect2 = _main.board.get_table_rect()
	_check(_main.arena.edge_protected(Vector2(500, table.position.y - 50), table) and not _main.arena.edge_protected(Vector2(500, table.end.y + 50), table), "the AI knows which edge is covered (top, not bottom)")
	_main.arena.remove_edge_walls()

	print("Safety Net: the real turn flow")
	await _start([_entry(GR, 0, Vector2(400, 1480)), _entry(GR, 0, Vector2(700, 1480)), _entry(GR, 1, Vector2(540, 500))], [net], [], false)
	var seen_wall := false
	var turns := 0
	for i in 3:
		var movable = null
		for p in _main._players:
			if is_instance_valid(p) and not p.knocked_off and p.flickable:
				movable = p
		if movable == null:
			break
		_flick(movable, Vector2(0, 40))
		var t := 0.0
		while t < 25.0 and not (_main._state == 0 and _main._enemy_turns_taken >= i + 1):
			if _main.arena._edge_walls.size() > 0:
				seen_wall = true
			await create_timer(0.05).timeout
			t += 0.05
		await _until(func(): return _main._state == 0, 10.0)
		turns += 1
		_check(_main.arena._edge_walls.is_empty(), "no wall left over at the start of player turn %d" % (i + 2))
	_check(seen_wall, "the wall was up during the second enemy turn")

	print("Out the Gate")
	await _start([_entry(GR, 0, Vector2(400, 1480)), _entry(GR, 0, Vector2(700, 1480)), _entry(GR, 1, Vector2(540, 500))], [gate], [], false)
	var a = _main._players[0]
	var b = _main._players[1]
	_flick(a, Vector2(0, 60))
	await _until(func(): return _main._gate_window and _main._state == 0)
	_check(_main._gate_window and _main._state == 0 and _main._enemy_turns_taken == 0, "after the first flick settles it is still the player's turn")
	_check(_main.ui.skip_button.visible, "the Skip button is shown")
	_check(not a.flickable and b.flickable, "the other figure can flick (normal cycle rules)")
	_flick(b, Vector2(0, 60))
	await _until(func(): return _main._enemy_turns_taken >= 1, 40.0)
	_check(_main._enemy_turns_taken >= 1 and not _main._gate_window, "after the second flick the enemy acts")
	await _until(func(): return _main._state == 0, 40.0)
	var c = null
	for p in _main._players:
		if is_instance_valid(p) and p.flickable:
			c = p
	var enemy_turns: int = _main._enemy_turns_taken
	_flick(c, Vector2(0, 60))
	await _until(func(): return _main._enemy_turns_taken > enemy_turns, 40.0)
	_check(_main._enemy_turns_taken > enemy_turns, "the second turn has a single flick (no extra)")
	await _start([_entry(GR, 0, Vector2(400, 1480)), _entry(GR, 0, Vector2(700, 1480)), _entry(GR, 1, Vector2(540, 500))], [gate], [], false)
	_flick(_main._players[0], Vector2(0, 60))
	await _until(func(): return _main._gate_window and _main._state == 0)
	_main._skip_bonus_flick()
	await _until(func(): return _main._enemy_turns_taken >= 1, 40.0)
	_check(_main._enemy_turns_taken >= 1 and not _main._gate_window, "Skip passes the turn to the enemy")

	if _fails.is_empty():
		print("ALL OK")
		quit(0)
	else:
		print("FAILED: ", _fails)
		quit(1)
