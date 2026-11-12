extends SceneTree
## Scripted-combat test for every "more than one flick per turn" mechanic.
##   godot --headless -s tools/bonus_flick_test.gd        (exit code 1 on any failure)
## It builds a real combat (main.tscn), then drives it through the same handlers touches use
## (_on_press / _release_aim / the Skip signal) and checks how many flicks happen and that the turn
## passes to the enemy and back correctly.

var _fails: Array[String] = []
var _main: Node
var _run: Node


func _initialize() -> void:
	_all()


func _check(ok: bool, what: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Waits until `cond` is true (max `seconds`); returns whether it became true.
func _until(cond: Callable, seconds := 30.0) -> bool:
	var t := 0.0
	while t < seconds:
		if cond.call():
			return true
		await create_timer(0.1).timeout
		t += 0.1
	return cond.call()


func _start(deck_paths: Array, equip := {}, upgrades := {}) -> void:
	if is_instance_valid(_main):
		_main.queue_free()
		await _frames(3)
	_run = root.get_node("RunManager")
	_run.start_new_run(0)
	for i in deck_paths.size():
		if deck_paths[i] != "":
			_run.deck[i] = load(deck_paths[i])
	for slot in equip:
		_run.deck_equipment[slot] = load(equip[slot])
	for slot in upgrades:
		_run.deck_upgrade[slot] = upgrades[slot]
	_run.enter_node(_run.reachable_nodes()[0])
	_main = load("res://scenes/main.tscn").instantiate()
	_main.enemy_think_time = 0.05
	root.add_child(_main)
	current_scene = _main  # (abilities find Main through current_scene)
	await _frames(5)
	await _until(func(): return _main._state == 0)  # PLAYER_TURN
	Engine.time_scale = 3.0


func _fig(slot: int) -> Node:
	return _main._players[slot]


## Drag the figure down (= flick up) through the real press/release handlers.
func _flick(fig: Node, drag := 60.0) -> void:
	var p: Vector2 = fig.global_position
	_main._on_press(0, p)
	_main._update_aim(p + Vector2(0, drag))
	_main._release_aim(p + Vector2(0, drag))


func _tap(pos: Vector2) -> void:
	_main._on_press(0, pos)
	_main._release_aim(pos)


## Taps empty board spots until `done` says the placement worked (random arenas may block some spots).
func _tap_until(done: Callable) -> void:
	for spot in [Vector2(450, 600), Vector2(300, 650), Vector2(600, 650), Vector2(450, 450), Vector2(250, 500), Vector2(650, 500), Vector2(450, 750)]:
		_tap(_main.board.board_rect.position + spot)
		if done.call():
			return


func _turns() -> int:
	return _main._enemy_turns_taken


## Waits for the next stop: a bonus flick on offer, or the enemy turn having come and gone.
## Returns "bonus", "turn" or "stuck".
func _stop(turns_before: int) -> String:
	var ok := await _until(func():
		return (_main._bonus_figure != null and _main._state == 0) or (_turns() > turns_before and _main._state == 0 and _main._bonus_figure == null))
	if not ok:
		return "stuck"
	return "bonus" if _main._bonus_figure != null else "turn"


## Flicks `first`, then keeps taking offered bonus flicks (`take` returns true to flick, false to skip)
## until the turn passes. Returns the number of flicks taken and the offers seen.
func _play_turn(first: Node, take: Callable, between := Callable()) -> Dictionary:
	var turns := _turns()
	var flicks_before: int = _main.player_flicks
	var offers := 0
	_flick(first)
	while true:
		if between.is_valid():
			between.call()
		var s: String = await _stop(turns)
		if s == "stuck":
			return {"stuck": true, "flicks": _main.player_flicks - flicks_before, "offers": offers}
		if s == "turn":
			break
		var fig: Node = _main._bonus_figure
		if _main._bonus_mode != "flick":  # a spray / toss window (Spitter, Cluster): not a bonus flick, just end it
			_main._skip_bonus_flick()
			continue
		offers += 1
		if take.call(offers, fig):
			_check(fig.flickable and _main.ui.skip_button != null, "bonus figure %s is flickable on offer" % fig.data.display_name)
			_flick(fig)
		else:
			_main._skip_bonus_flick()
	return {"stuck": false, "flicks": _main.player_flicks - flicks_before, "offers": offers}


func _all() -> void:
	await create_timer(0.5).timeout
	var S := "res://resources/figures/speedo.tres"
	var G := "res://resources/figures/grunt.tres"

	print("Speedo: 2 flicks (take the bonus)")
	await _start([S])
	var r: Dictionary = await _play_turn(_fig(0), func(_n, _f): return true)
	_check(not r.stuck and r.flicks == 2 and r.offers == 1, "2 flicks, 1 offer (got %s)" % r)
	_check(_main._state == 0 and _main._bonus_figure == null, "back to a normal player turn after the enemy")

	print("Speedo: skip the bonus")
	await _start([S])
	r = await _play_turn(_fig(0), func(_n, _f): return false)
	_check(not r.stuck and r.flicks == 1 and r.offers == 1, "1 flick, offer skipped, enemy moved (got %s)" % r)

	print("Speedo: skip via the UI Skip signal")
	await _start([S])
	var turns := _turns()
	_flick(_fig(0))
	await _stop(turns)
	_check(_main._bonus_figure != null, "bonus offered")
	_check(_main.ui.turn_label.text.begins_with("Bonus flick!"), "label says 'Bonus flick!' (%s)" % _main.ui.turn_label.text)
	await _frames(2)
	_check(_main.ui.skip_button.visible, "Skip button is visible")
	_main.ui.bonus_skipped.emit()
	await _stop(turns)
	_check(_turns() > turns and _main._bonus_figure == null, "Skip passes the turn to the enemy")

	for n in [3, 4]:
		print("Speedo: %d flicks per turn" % n)
		await _start([S])
		_fig(0).ability.flicks_per_turn = n
		r = await _play_turn(_fig(0), func(_n, _f): return true)
		_check(not r.stuck and r.flicks == n and r.offers == n - 1, "%d flicks (got %s)" % [n, r])

	print("Speedo: Dash (each flick stronger)")
	await _start([S])
	var sp = _fig(0)
	sp.ability.power_per_flick = 0.25
	var base: float = sp.ability.get_flick_power_multiplier(sp)
	sp.turn_flicks = 1
	_check(sp.ability.get_flick_power_multiplier(sp) > base, "second flick is stronger")
	sp.turn_flicks = 0

	print("Speedo: Zip tier 3 (+25% knockback dealt) and Dash tier 2 (+10% per flick taken)")
	await _start([S])
	sp = _fig(0)
	sp.ability.knockback_dealt_bonus = 0.25
	_check(absf(sp.ability.get_dealt_knockback_bonus(sp, null) - 0.25) < 0.001, "Hard Hitter: +25% knockback dealt")
	sp.ability.flick_knockback_per_flick = 0.1
	for i in 12:
		sp.ability.on_flicked(sp, Vector2.ZERO)
	_check(absf(sp.ability.get_dealt_knockback_bonus(sp, null) - 1.25) < 0.001, "Flick Fury: +10%% per flick taken, capped at 10 flicks (%.2f)" % sp.ability.get_dealt_knockback_bonus(sp, null))

	print("Bloodluster: chain of bonus flicks while each flick kills")
	await _start(["res://resources/figures/bloodluster.tres"])
	var bl_kills := [0]  # flicks that "kill": the first three
	r = await _play_turn(_fig(0), func(_n, _f): return true, func():
		if _main._state == 2 and bl_kills[0] < 3 and _main._flick_kills == 0:
			_main._flick_kills = 1  # (pretend the flick in progress knocked something off)
			bl_kills[0] += 1)
	_check(not r.stuck and r.flicks == 4 and r.offers == 3, "1 flick + 3 chained bonus flicks (got %s)" % r)

	print("Bloodluster: no kill, no bonus")
	await _start(["res://resources/figures/bloodluster.tres"])
	r = await _play_turn(_fig(0), func(_n, _f): return true)
	_check(not r.stuck and r.flicks == 1 and r.offers == 0, "plain flick passes the turn (got %s)" % r)

	print("Jet Pack: one extra flick, once per combat")
	await _start([G], {0: "res://resources/equipment/jet_pack.tres"})
	r = await _play_turn(_fig(0), func(_n, _f): return true)
	_check(not r.stuck and r.flicks == 2 and r.offers == 1, "first turn: 2 flicks (got %s)" % r)
	await _until(func(): return _main._state == 0 and _main._bonus_figure == null)
	_main._make_all_flickable()
	r = await _play_turn(_fig(0), func(_n, _f): return true)
	_check(not r.stuck and r.flicks == 1 and r.offers == 0, "second turn: charge spent, 1 flick (got %s)" % r)

	print("Jet Pack: skipping keeps the charge")
	await _start([G], {0: "res://resources/equipment/jet_pack.tres"})
	r = await _play_turn(_fig(0), func(_n, _f): return false)
	_check(not r.stuck and r.flicks == 1 and r.offers == 1, "skipped (got %s)" % r)

	print("Extra Turn power")
	await _start([G, G])
	_main.extra_turns = 1
	turns = _turns()
	_flick(_fig(0))
	await _until(func(): return _main._state == 0 and _main.extra_turns == 0 and _main._bonus_figure == null)
	_check(_turns() == turns, "the enemy did not move between the two flicks")
	r = await _play_turn(_fig(1), func(_n, _f): return true)
	_check(not r.stuck and r.flicks == 1, "second flick then enemy turn (got %s)" % r)

	print("Queued bonus flick (Energizer instant recharge / Rally Rallying Cry / any grant_bonus_flick)")
	await _start([G, G])
	var g0 = _fig(0)
	var g1 = _fig(1)
	r = await _play_turn(g0, func(_n, _f): return true, func(): if _main._bonus_queue.is_empty() and g1.turn_flicks == 0 and g0.turn_flicks == 1: _main.grant_bonus_flick(g1))
	_check(not r.stuck and r.flicks == 2 and r.offers == 1, "the granted figure gets one flick (got %s)" % r)

	print("Energizer: Instant Recharge grants a flick; recharge_all path")
	await _start(["res://resources/figures/energizer.tres", G])
	var en = _fig(0)
	_check(en.ability.has_method("on_flicked"), "energizer loaded")
	_main.grant_bonus_flick(_fig(1))
	r = await _play_turn(en, func(_n, _f): return true)
	_check(not r.stuck and r.flicks == 2, "flick + granted flick, then enemy (got %s)" % r)

	print("Glue Guy: +1 flick per figure stuck to")
	await _start(["res://resources/figures/glue_guy.tres"])
	var gg = _fig(0)
	gg.ability.flick_per_stuck = true
	_check(gg.ability.get_flicks_per_turn(gg) == 1, "1 flick with nothing stuck")
	var victim: Node = _main._enemies[0]
	gg.glue_to(victim)
	_check(gg.ability.get_flicks_per_turn(gg) == 2, "2 flicks with one stuck (got %d)" % gg.ability.get_flicks_per_turn(gg))
	r = await _play_turn(gg, func(_n, _f): return true)
	_check(not r.stuck and r.flicks >= 1, "turn completes (got %s)" % r)

	print("Pinhead: place a pin, then flick the same turn")
	await _start(["res://resources/figures/pinhead.tres"])
	var ph = _fig(0)
	_tap(ph.global_position)  # select
	_tap_until(func(): return ph.placed_this_turn)
	_check(ph.placed_this_turn, "pin placed (%s)" % _main.ui.turn_label.text)
	_check(ph.flickable, "still flickable after placing")
	r = await _play_turn(ph, func(_n, _f): return true)
	_check(not r.stuck and r.flicks == 1, "then flicked once, enemy moved (got %s)" % r)

	print("Engineer: place a turret, then flick")
	await _start(["res://resources/figures/engineer.tres"])
	var eng = _fig(0)
	_tap(eng.global_position)
	_tap_until(func(): return eng.placed_this_turn)
	_check(eng.placed_this_turn and eng.flickable, "turret placed, still flickable (%s)" % _main.ui.turn_label.text)
	r = await _play_turn(eng, func(_n, _f): return true)
	_check(not r.stuck and r.flicks == 1, "then flicked once (got %s)" % r)

	print("Spitter: spray, then flick")
	await _start(["res://resources/figures/spitter.tres"])
	var spit = _fig(0)
	_tap(spit.global_position)
	spit.ability.set_spray(spit, true, spit.global_position + Vector2(0, -300))
	await _frames(10)
	spit.ability.set_spray(spit, false)
	_check(spit.flickable, "still flickable after spraying")
	r = await _play_turn(spit, func(_n, _f): return true)
	_check(not r.stuck and r.flicks == 1, "then flicked once (got %s)" % r)

	print("Ghost: teleport tap, then flick")
	await _start(["res://resources/figures/ghost.tres"])
	var gh = _fig(0)
	gh.ability.teleport = true
	_tap(gh.global_position)
	var tap: Dictionary = gh.ability.get_tap_ability(gh)
	_check(tap.get("ready", false) and not tap.get("uses_action", true), "teleport ready and keeps the action")
	_tap(_main.board.board_rect.position + Vector2(450, 500))
	_check(gh.flickable, "flickable after teleport")
	r = await _play_turn(gh, func(_n, _f): return true)
	_check(not r.stuck and r.flicks == 1, "then flicked once (got %s)" % r)

	print("Cluster: Rebound toss keeps the action")
	await _start(["res://resources/figures/cluster.tres"])
	var cl = _fig(0)
	cl.ability.toss_keeps_action = true
	_tap(cl.global_position)
	var flicks0: int = _main.player_flicks
	_tap(cl.global_position + Vector2(0, -300))
	_check(cl.flickable, "Cluster still flickable after the toss")
	r = await _play_turn(cl, func(_n, _f): return true)
	_check(not r.stuck, "turn completes (got %s)" % r)

	print("Alchemist: Brew (place and flick)")
	await _start(["res://resources/figures/alchemist.tres"])
	var al = _fig(0)
	al.ability.place_and_flick = true
	_tap(al.global_position)
	_tap_until(func(): return al.placed_this_turn)
	_check(al.placed_this_turn and al.flickable, "still flickable after placing a zone")
	r = await _play_turn(al, func(_n, _f): return true)
	_check(not r.stuck and r.flicks == 1, "then flicked once (got %s)" % r)

	print("Enemy Speedo: bonus flicks run and the turn returns")
	await _start([G])
	_main.queue_free()
	await _frames(3)
	_run.start_new_run(0)
	_run.enter_node(_run.reachable_nodes()[0])
	_run.enemies[0] = load(S)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.enemy_think_time = 0.05
	root.add_child(_main)
	current_scene = _main
	await _frames(5)
	await _until(func(): return _main._state == 0)
	Engine.time_scale = 3.0
	var es = _main._enemies[0]
	turns = _turns()
	_flick(_fig(0))  # the enemy answers
	await _until(func(): return _turns() > turns and _main._state == 0, 60.0)
	_check(_turns() > turns and _main._state == 0 and _main._bonus_figure == null, "enemy turn with a Speedo ends and control returns")
	_check(es.turn_flicks <= es.ability.get_flicks_per_turn(es), "Speedo never exceeds its flicks (%d)" % es.turn_flicks)

	print()
	if _fails.is_empty():
		print("ALL BONUS FLICK TESTS PASSED")
		quit(0)
	else:
		printerr("%d FAILED:" % _fails.size())
		for f in _fails:
			printerr("  - " + f)
		quit(1)
