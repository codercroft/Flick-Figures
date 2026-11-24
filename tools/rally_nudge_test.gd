extends SceneTree
## Rally's nudge counts as a flick for ability triggers (not for the flick cycle): godot --headless -s tools/rally_nudge_test.gd
## Every probe is run on the board and on the deck. Exit 1 on failure.

var _fails: Array[String] = []
var _main: Node
const F := "res://resources/figures/"


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
	_main.enemy_think_time = 0.02
	root.add_child(_main)
	current_scene = _main
	await _frames(4)
	await _until(func(): return _main._state == 0)


func _settle() -> void:
	await _until(func(): return _main._all_figures_resting(), 20.0)
	await _frames(3)


## One figure (player) at `at`, optionally with enemies; returns it. `deck` puts it on the deck strip.
func _probe(data, deck: bool, upgrade := Vector2i(-1, 0), enemies: Array = []) -> Node:
	var at := Vector2(540, 1500) if deck else Vector2(540, 1100)
	var entries: Array = [_entry(data, 0, at, upgrade)]
	for e in enemies:
		entries.append(_entry(e[0], 1, e[1]))
	await _start(entries)
	var fig = _main._players[0]
	return fig


func _all() -> void:
	await create_timer(0.5).timeout
	var grunt = load(F + "grunt.tres")
	for deck in [false, true]:
		var where := "deck" if deck else "board"
		print("== %s" % where)
		# --- the nudge is not a flick for the cycle -----------------------------------------------------------
		var g = await _probe(grunt, deck)
		var flick_signals := 0
		g.flicked.connect(func(_f, _i): flick_signals += 1)
		g.flickable = true
		var turns: int = g.turn_flicks
		g.rally_nudge(Vector2(0, -700))
		_check(g.flickable and g.turn_flicks == turns and flick_signals == 0, "%s: still flickable, turn_flicks %d, flicked signal %d" % [where, g.turn_flicks, flick_signals])
		await _settle()
		_check(not g.nudged_flick, "%s: the nudge state ends when it stops" % where)

		# --- Juicer: trail ------------------------------------------------------------------------------------
		var ju = await _probe(load(F + "juicer.tres"), deck)
		ju.rally_nudge(Vector2(0, -1500))
		await create_timer(0.5).timeout
		_check(_main.arena._trail.size() > 0, "%s: Juicer lays a trail" % where)

		# --- Land Miner: mines -------------------------------------------------------------------------------
		var lm = await _probe(load(F + "land_miner.tres"), deck)
		lm.rally_nudge(Vector2(0, -1800))
		await _settle()
		_check(get_nodes_in_group("mines").size() > 0, "%s: Land Miner drops mines (%d)" % [where, get_nodes_in_group("mines").size()])

		# --- Sneaky Bomber: explodes where it stops if it touched nothing ---------------------------------------
		var sb = await _probe(load(F + "sneaky_bomber.tres"), deck, Vector2i(-1, 0), [[grunt, Vector2(700, 900)]])
		var foe = _main._enemies[0]
		var foe_start: Vector2 = foe.global_position
		sb.rally_nudge(Vector2(0, -900))
		_check(sb.ability._flicking, "%s: Sneaky Bomber is armed by the nudge" % where)
		foe.global_position = sb.global_position + Vector2(120, -450)
		foe_start = foe.global_position
		await _settle()
		_check(foe.global_position.distance_to(foe_start) > 30.0 or not is_instance_valid(foe) or foe.knocked_off, "%s: it exploded where it stopped (the enemy near the stop was pushed)" % where)

		# --- Bombo: first hit, Aggro-bom: counts, Splitter: splits ---------------------------------------------
		var bo = await _probe(load(F + "bombo.tres"), deck, Vector2i(-1, 0), [[grunt, Vector2(540, 800)]])
		bo.ability._exploded = true
		bo.rally_nudge(Vector2(0, -1500))
		_check(not bo.ability._exploded, "%s: Bombo is re-armed by the nudge" % where)
		await _settle()
		_check(bo.ability._exploded, "%s: Bombo exploded on its first hit" % where)
		var ag = await _probe(load(F + "aggro_bom.tres"), deck, Vector2i(-1, 0), [[grunt, Vector2(540, 800)]])
		ag.rally_nudge(Vector2(0, -1500))
		await _settle()
		_check(ag.ability._count >= 1, "%s: Aggro-bom counted the hit (%d)" % [where, ag.ability._count])
		var sx = await _probe(load(F + "splitter.tres"), deck, Vector2i(-1, 0), [[grunt, Vector2(540, 800)]])
		var before: int = _main._players.size()
		sx.rally_nudge(Vector2(0, -2000))
		await _settle()
		_check(_main._players.size() > before, "%s: Splitter split on impact (%d -> %d players)" % [where, before, _main._players.size()])

		# --- Pusher, Absorber, Eater, Glue Guy, Energizer ----------------------------------------------------
		var pu = await _probe(load(F + "pusher.tres"), deck)
		pu.rally_nudge(Vector2(0, -600))
		_check(pu.ability._pushing, "%s: Pusher's push is on (timer and no-rebound)" % where)
		await _settle()
		var ab = await _probe(load(F + "absorber.tres"), deck)
		ab.rally_nudge(Vector2(0, -600))
		_check(ab.ability._armed, "%s: Absorber is armed" % where)
		var et = await _probe(load(F + "eater.tres"), deck, Vector2i(-1, 0), [[load(F + "speedo.tres"), Vector2(540, 800)]])
		var prey = _main._enemies[0]
		et.rally_nudge(Vector2(0, -1500))
		await _settle()
		_check(not is_instance_valid(prey) or prey.knocked_off, "%s: Eater ate the smaller figure" % where)
		var gg = await _probe(load(F + "glue_guy.tres"), deck, Vector2i(-1, 0), [[grunt, Vector2(540, 800)]])
		gg.rally_nudge(Vector2(0, -1500))
		await _settle()
		_check(gg.is_glued(), "%s: Glue Guy stuck to what it hit" % where)
		await _start([_entry(load(F + "energizer.tres"), 0, Vector2(540, 1500) if deck else Vector2(540, 1100)), _entry(grunt, 0, Vector2(540, 1150) if deck else Vector2(540, 800))])
		var en = _main._players[0]
		var friend = _main._players[1]
		friend.flickable = false
		en.rally_nudge(Vector2(0, -700))
		if deck:  # (a deck figure passes through its allies on the board, so it can only be armed)
			_check(en.ability._flicking, "deck: Energizer is armed by the nudge")
			await _settle()
		else:
			await _settle()
			_check(is_instance_valid(friend) and friend.flickable, "board: Energizer recharged the ally it hit")

		# --- Crazy Man: speeds up per bump ------------------------------------------------------------------
		var cm = await _probe(load(F + "crazy_man.tres"), deck, Vector2i(-1, 0), [[load(F + "wall_piece.tres"), Vector2(540, 800)]])
		var plain = 0.0
		cm.rally_nudge(Vector2(0, -1500))
		var peak := 0.0
		for i in 60:
			await physics_frame
			if cm.linear_velocity.y > 0.0:
				peak = maxf(peak, cm.linear_velocity.length())
		_check(peak > 0.0, "%s: Crazy Man bounced back off the wall piece (%.0f px/s)" % [where, peak])

		# --- Shieldon: wall at the stop --------------------------------------------------------------------
		var so = await _probe(load(F + "shieldon_ooper.tres"), deck, Vector2i(-1, 0), [[grunt, Vector2(540, 300)]])
		so.rally_nudge(Vector2(0, -500))
		await _settle()
		await create_timer(0.4).timeout
		_check(so.ability.has_active_wall(so), "%s: Shieldon raised its wall where it stopped" % where)

		# --- Wikka Wat: reverse available, Magnet: pulse available ----------------------------------------------
		var ww = await _probe(load(F + "wikka_wat.tres"), deck)
		ww.rally_nudge(Vector2(0, -900))
		await physics_frame
		_check(ww.ability.can_reverse(ww), "%s: Wikka Wat can reverse" % where)
		await _settle()
		var mg = await _probe(load(F + "magnet.tres"), deck, Vector2i(0, 2))
		mg.rally_nudge(Vector2(0, -900))
		await physics_frame
		_check(mg.ability.pulse_ready(mg), "%s: Magnet's Repel Pulse is available" % where)
		await _settle()

		# --- Ghost: wraps on its own side's turn ---------------------------------------------------------------
		var gh = await _probe(load(F + "ghost.tres"), deck)
		gh.teleport_to(Vector2(540, 1560) if deck else Vector2(540, 1600))
		gh.rally_nudge(Vector2(0, 900))
		await _frames(40)
		_check(is_instance_valid(gh) and not gh.knocked_off, "%s: Ghost wrapped instead of falling off" % where)

		# --- Bloodluster: bonus flick after a kill (real Rally flick) --------------------------------------------
		var rally = load(F + "rally.tres")
		var y := 1500.0 if deck else 700.0
		await _start([_entry(rally, 0, Vector2(700, 1500)), _entry(load(F + "bloodluster.tres"), 0, Vector2(260, y)), _entry(grunt, 1, Vector2(110, y))])
		var ra = _main._players[0]
		var bl = _main._players[1]
		ra.ability.nudge_speed = 2600.0
		var p: Vector2 = ra.global_position
		_main._on_press(0, p)
		_main._release_aim(p + Vector2(0, 100))
		await _until(func(): return _main._bonus_figure != null or _main._state == 0, 30.0)
		await _until(func(): return _main._bonus_figure != null, 5.0)
		_check(_main._bonus_figure == bl, "%s: a nudged Bloodluster that knocked something off gets its bonus flick" % where)

		# --- what must NOT count -----------------------------------------------------------------------------
		var sp = await _probe(load(F + "speedo.tres"), deck)
		sp.rally_nudge(Vector2(0, -600))
		_check(sp.ability._combat_flicks == 0, "%s: Speedo's flick counters ignore a nudge" % where)
		await _settle()
		_check(sp.turn_flicks == 0 and sp.flickable, "%s: Speedo keeps its flicks" % where)

	print("== Rally loops")
	var rally = load(F + "rally.tres")
	await _start([_entry(rally, 0, Vector2(300, 1100)), _entry(rally, 0, Vector2(700, 1100)), _entry(grunt, 1, Vector2(540, 300))])
	var r1 = _main._players[0]
	var r2 = _main._players[1]
	r2.ability._last_rally_ms = -10000
	r1.ability.rally_on_hit = true
	r2.ability.rally_on_hit = true
	r1.rally_nudge(Vector2(0, -300))  # as if a Rally had nudged it: it must not rally
	await _frames(2)
	_check(r2.linear_velocity.length() < 1.0 and r1.nudged_flick, "a nudged Rally does not rally (one Rally trigger per real flick)")
	r1.ability.on_flicked(r1, Vector2.ZERO)
	r1.nudged_flick = false
	r1.ability.on_flicked(r1, Vector2.ZERO)
	await _frames(2)
	_check(r2.nudged_flick and r2.linear_velocity.length() > 100.0, "a real Rally flick still rallies the other Rally")
	await _settle()
	_check(not r1.ability._last_rally_ms == r2.ability._last_rally_ms or r2.ability._last_rally_ms == -10000, "the nudged Rally did not rally back")

	if is_instance_valid(_main):
		_main.queue_free()
	print("\n%s" % ("ALL OK" if _fails.is_empty() else "FAILED: %s" % ", ".join(_fails)))
	quit(1 if not _fails.is_empty() else 0)
