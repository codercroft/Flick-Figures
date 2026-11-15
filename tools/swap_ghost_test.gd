extends SceneTree
## Swap power + Ghost teleport test: godot --headless -s tools/swap_ghost_test.gd (exit 1 on failure).
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


func _until(cond: Callable, seconds := 20.0) -> bool:
	var t := 0.0
	while t < seconds:
		if cond.call():
			return true
		await create_timer(0.1).timeout
		t += 0.1
	return cond.call()


func _entry(data, team: int, pos: Vector2, upgrade := Vector2i(-1, 0)) -> Dictionary:
	return {"data": data, "team": team, "pos": pos, "equipment": null, "finish": null, "upgrade": upgrade, "node": null}


func _start(entries: Array, powers: Array = []) -> void:
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
	for p in powers:
		Setup.player_powers.append(p)
	Setup.prepare()
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	current_scene = _main
	await _frames(6)
	await _until(func(): return _main._state == 0)


func _tap(pos: Vector2) -> void:
	_main._on_press(0, pos)
	await _frames(2)


func _tap_board(pos: Vector2) -> void:
	_main._on_press(0, pos)
	_main._release_aim(pos)
	await _frames(2)


func _power_left() -> bool:
	return root.get_node("RunManager").powers[0] != null


func _settle() -> void:
	await _frames(3)
	await _until(func(): return _main._state == 0 and _main._power_slot < 0)


func _swap(a, b) -> void:
	_main._on_power_slot_pressed(0)
	await _frames(1)
	await _tap(a.global_position)
	await _tap(b.global_position)
	await _settle()


func _all() -> void:
	await _frames(3)
	var GR = load("res://resources/figures/grunt.tres")
	var SW = load("res://resources/powers/swap.tres")
	var P := 0
	var E := 1
	var a_pos := Vector2(400, 1000)
	var b_pos := Vector2(700, 800)

	print("Swap: two player figures on the board")
	await _start([_entry(GR, P, a_pos), _entry(GR, P, b_pos)], [SW])
	var a = _main._players[0]
	var b = _main._players[1]
	await _swap(a, b)
	_check(a.global_position.distance_to(b_pos) < 1.0 and b.global_position.distance_to(a_pos) < 1.0, "positions exchanged (%s %s)" % [a.global_position, b.global_position])
	_check(not _power_left(), "power used up")

	print("Swap: player + enemy")
	await _start([_entry(GR, P, a_pos), _entry(GR, E, b_pos)], [SW])
	a = _main._players[0]
	b = _main._enemies[0]
	await _swap(a, b)
	_check(a.global_position.distance_to(b_pos) < 1.0 and b.global_position.distance_to(a_pos) < 1.0, "positions exchanged (%s %s)" % [a.global_position, b.global_position])
	_check(not _power_left(), "power used up")

	print("Swap: deck figure with board figure")
	await _start([_entry(GR, P, Vector2(540, 1480)), _entry(GR, P, b_pos)], [SW])
	a = _main._players[0]
	b = _main._players[1]
	print("   on_deck ", a.on_deck, " ", b.on_deck, " ", a.global_position, " ", b.global_position)
	var a0: Vector2 = a.global_position
	var b0: Vector2 = b.global_position
	var a_deck: bool = a.on_deck
	var b_deck: bool = b.on_deck
	await _swap(a, b)
	_check(a.global_position.distance_to(b0) < 1.0 and b.global_position.distance_to(a0) < 1.0, "positions exchanged")
	_check(a.on_deck == b_deck and b.on_deck == a_deck, "on_deck follows the spot")
	_check(not _power_left(), "power used up")

	print("Swap: moving figure")
	await _start([_entry(GR, P, a_pos), _entry(GR, P, b_pos)], [SW])
	a = _main._players[0]
	b = _main._players[1]
	b.linear_velocity = Vector2(300, 0)
	await _swap(a, b)
	_check(a.linear_velocity == Vector2.ZERO and b.linear_velocity == Vector2.ZERO, "both stopped")
	_check(a.global_position.distance_to(b_pos) < 30.0 and b.global_position.distance_to(a_pos) < 30.0, "positions exchanged (%s %s)" % [a.global_position, b.global_position])

	print("Swap: same figure twice, then empty space")
	await _start([_entry(GR, P, a_pos), _entry(GR, P, b_pos)], [SW])
	a = _main._players[0]
	b = _main._players[1]
	_main._on_power_slot_pressed(0)
	await _tap(a.global_position)
	_check(a.selected and _main._power_targets.size() == 1, "first figure is shown as selected")
	await _tap(a.global_position)
	_check(not a.selected and _main._power_targets.is_empty(), "tapping it again unselects it")
	await _tap(a.global_position)
	await _tap(Vector2(900, 500))
	_check(_main._power_slot < 0 and _power_left(), "empty tap cancels and keeps the power")
	_check(not a.selected, "selection cleared")
	_check(a.global_position.distance_to(a_pos) < 1.0, "nothing moved")

	await _swap_special()
	await _ghost()
	if _fails.is_empty():
		print("ALL OK")
		quit(0)
	else:
		print("FAILED: ", _fails)
		quit(1)


func _ghost() -> void:
	var GH = load("res://resources/figures/ghost.tres")
	var GR = load("res://resources/figures/grunt.tres")
	var start := Vector2(540, 1000)
	print("Ghost teleport")
	await _start([_entry(GH, 0, start, Vector2i(1, 2)), _entry(GR, 0, Vector2(300, 1100)), _entry(GR, 1, Vector2(540, 600))])
	var g = _main._players[0]
	var target := Vector2(800, 900)
	await _tap_board(g.global_position)  # select it
	_check(_main._selected == g, "ghost selected")
	await _tap_board(target)
	await _frames(5)
	_check(g.global_position.distance_to(target) < 2.0, "ghost is at the tapped spot (%s)" % g.global_position)
	_check(g.ability._teleported if "_teleported" in g.ability else true, "teleport counted")
	print("Ghost teleport from the deck")
	await _start([_entry(GH, 0, Vector2(540, 1480), Vector2i(1, 2)), _entry(GR, 0, Vector2(300, 1480)), _entry(GR, 1, Vector2(540, 600))])
	g = _main._players[0]
	print("   on_deck ", g.on_deck, " ", g.global_position)
	await _tap_board(g.global_position)
	_check(_main._selected == g, "deck ghost selected")
	await _tap_board(target)
	await _frames(5)
	_check(g.global_position.distance_to(target) < 2.0, "deck ghost is at the tapped spot (%s)" % g.global_position)
	_check(not g.on_deck, "no longer on deck")
	await _frames(30)
	_check(g.global_position.distance_to(target) < 2.0, "still there 30 frames later (%s)" % g.global_position)
	print("Ghost teleport: blocked spots keep it where it was")
	await _start([_entry(GH, 0, start, Vector2i(1, 2)), _entry(GR, 0, Vector2(300, 1100)), _entry(GR, 1, Vector2(540, 600))])
	g = _main._players[0]
	await _tap_board(g.global_position)
	await _tap_board(Vector2(540, 610))  # on top of an enemy
	await _frames(5)
	_check(g.global_position.distance_to(start) < 2.0, "refused: overlaps a figure")
	await _tap_board(Vector2(60, 700))  # off the table / outside
	await _frames(5)
	_check(g.global_position.distance_to(start) < 2.0, "refused: off the table")
	_check(not g.ability._teleported, "not used up by a refused tap")


func _swap_special() -> void:
	var GR = load("res://resources/figures/grunt.tres")
	var CL = load("res://resources/figures/cluster.tres")
	var AB = load("res://resources/figures/absorber.tres")
	var SW = load("res://resources/powers/swap.tres")
	var a_pos := Vector2(400, 1000)
	var b_pos := Vector2(700, 800)
	print("Swap: glued figure is refused")
	await _start([_entry(GR, 0, a_pos), _entry(GR, 0, b_pos), _entry(GR, 0, Vector2(400, 1100))], [SW])
	var a = _main._players[0]
	var b = _main._players[1]
	var c = _main._players[2]
	a.glue_to(c)
	await _frames(2)
	_main._on_power_slot_pressed(0)
	await _tap(a.global_position)
	_check(_main._power_targets.is_empty() and _main._power_slot >= 0, "glued figure not accepted, still waiting")
	await _tap(b.global_position)
	await _tap(c.global_position)
	_check(_main._power_targets.size() == 1 and _main._power_slot >= 0, "glued figure not accepted as the second one either")
	await _tap(Vector2(900, 500))
	_check(_power_left(), "power kept")
	print("Swap: Cluster with a Grunt")
	await _start([_entry(CL, 0, a_pos), _entry(GR, 1, b_pos)], [SW])
	a = _main._players[0]
	b = _main._enemies[0]
	var a0: Vector2 = a.global_position
	await _swap(a, b)
	_check(a.global_position.distance_to(b_pos) < 1.0 and b.global_position.distance_to(a0) < 1.0, "positions exchanged")
	print("Swap: an absorbed figure cannot be tapped")
	await _start([_entry(AB, 0, a_pos), _entry(GR, 1, b_pos), _entry(GR, 0, Vector2(300, 900))], [SW])
	var victim = _main._enemies[0]
	_main.absorb_figure(victim)
	await _frames(2)
	_main._on_power_slot_pressed(0)
	await _tap(b_pos)
	_check(_main._power_slot < 0 and _power_left(), "tap on the hidden figure's spot = empty space = cancel")
