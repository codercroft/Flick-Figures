extends SceneTree
## Jim's magnet / glue immunity, Magnet's Repel Pulse tap, Ghost and Energizer upgrade changes:
## godot --headless -s tools/field_changes_test.gd (exit 1 on failure).

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


func _tap(screen_pos: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.position = screen_pos
	_main._input(ev)


func _all() -> void:
	await create_timer(0.5).timeout
	var F := "res://resources/figures/"
	var grunt = load(F + "grunt.tres")
	var jim = load(F + "slippery_jim.tres")
	var magnet = load(F + "magnet.tres")
	var ghost = load(F + "ghost.tres")
	var energizer = load(F + "energizer.tres")

	print("Slippery Jim: immune to magnets and glue while he has stacks")
	await _start([_entry(grunt, 0, Vector2(540, 1400)), _entry(jim, 1, Vector2(540, 700)), _entry(grunt, 1, Vector2(300, 700))])
	var jimf = _main._enemies[0]
	var other = _main._enemies[1]
	_check(jimf.field_immune(), "field_immune while slippery")
	jimf.glue_to(other)
	_check(not jimf.is_glued(), "Glue Guy / glue chains can't stick to him")
	other.glue_to(jimf)
	_check(not other.is_glued(), "nor can he be the other end of a glue link")
	_main.arena.add_magnet_zone(Vector2(540, 400), 600.0, 100.0, 1600.0, 2)
	jimf.linear_velocity = Vector2(0, -400)
	other.linear_velocity = Vector2(0, -400)
	await create_timer(0.3).timeout
	var jim_dx: float = absf(jimf.global_position.x - 540.0)
	var other_dx: float = absf(other.global_position.x - 300.0)
	_check(jim_dx < 5.0, "Magnet Throw zone does not pull him (moved %.1f px sideways)" % jim_dx)
	jimf.ability._left = 0
	_check(not jimf.field_immune(), "no stacks: no longer immune")
	other.unglue()
	jimf.glue_to(other)
	_check(jimf.is_glued(), "without stacks glue works on him")

	print("Magnet Repel Pulse: tap anywhere while it moves")
	for tier in [2, 3]:
		await _start([_entry(magnet, 0, Vector2(540, 1400), Vector2i(0, tier)), _entry(grunt, 1, Vector2(540, 700)), _entry(grunt, 1, Vector2(560, 1000))])
		var mg = _main._players[0]
		var foe = _main._enemies[1]
		_check(mg.ability.push_enabled and mg.ability.push_once_per_turn == (tier == 3), "tier %d flags" % tier)
		_tap(Vector2(500, 900))  # the Magnet is still on the deck: nothing moves, nothing is used
		_check(not mg.ability._push_used, "a tap with the Magnet at rest does nothing")
		var p: Vector2 = mg.global_position
		_main._on_press(0, p)
		_main._release_aim(p + Vector2(0, 300))
		await create_timer(0.15).timeout
		_check(mg.linear_velocity.length() > 80.0 and mg.ability.pulse_ready(mg), "moving Magnet shows the pulse as ready")
		var before: Vector2 = foe.linear_velocity
		foe.global_position = mg.global_position + Vector2(0, -250)
		await _frames(1)
		_tap(Vector2(300, 450))  # anywhere on the screen
		await _frames(2)
		_check(mg.ability._push_used, "the tap fired the pulse")
		_check(foe.linear_velocity.length() > 200.0 and foe.linear_velocity.y < 0.0, "the opponent was shoved away from the Magnet (%s)" % foe.linear_velocity)
		var after: Vector2 = foe.linear_velocity
		_tap(Vector2(300, 450))
		await _frames(1)
		_check(foe.linear_velocity.length() <= after.length() + 1.0, "no second pulse in the same flick")
		await _until(func(): return _main._state == 0, 30.0)
		mg.ability.on_turn_ended(mg)
		_check(mg.ability._push_used != (tier == 3), "tier %d: %s" % [tier, "recharged for the next turn" if tier == 3 else "still spent (once per combat)"])

	print("Ghost Haunt")
	var gt = root.get_node("RunManager").tree_for(ghost)
	_check(is_equal_approx(gt.path_a[0].ability_overrides.wrap_knockback, 0.2), "Spooky Gains +20% knockback per wrap")
	_check(is_equal_approx(gt.path_a[1].ability_overrides.wrap_power, 0.2), "Spirit Power +20% power per wrap")
	var ga = load("res://scripts/abilities/ghost_ability.gd").new()
	ga.wraps_on_opponent_turn = true
	ga._opponent_wraps_used = 1
	ga.on_turn_ended(null)
	_check(ga._opponent_wraps_used == 1 and ga.get_wrap_count_for_test() == 0 if ga.has_method("get_wrap_count_for_test") else ga._opponent_wraps_used == 1, "the opponent-turn wrap is not reset between turns (once per combat)")

	print("Energizer")
	await _start([_entry(energizer, 0, Vector2(540, 1300), Vector2i(0, 2)), _entry(grunt, 0, Vector2(540, 1000)), _entry(grunt, 1, Vector2(300, 600))])
	var en = _main._players[0]
	var ally = _main._players[1]
	_check(is_equal_approx(en.ability.ally_knockback_reduction, 0.3) and is_equal_approx(en.ability.ally_power_bonus, 0.25), "Overcharge: +25% power and 30% less knockback")
	en.ability.on_flicked(en, Vector2.ZERO)
	en.ability.on_hit(en, ally)
	_check(is_equal_approx(ally.charge_taken, 0.7) and is_equal_approx(ally.charge_power, 1.25), "the recharged ally got both")
	_check(ally.aura_knockback_multiplier() < 0.71, "the ally takes 30% less knockback")
	ally.launch(Vector2.ZERO)
	_check(is_equal_approx(ally.charge_taken, 1.0), "until its next flick")
	await _start([_entry(energizer, 0, Vector2(540, 1300), Vector2i(1, 3)), _entry(grunt, 1, Vector2(300, 600))])
	en = _main._players[0]
	var victim = _main._enemies[0]
	en.ability.on_flicked(en, Vector2.ZERO)
	en.ability.on_hit(en, victim)
	_check(is_equal_approx(victim.shock_flick, 0.4), "Stun: the hit enemy's next flick is -60 percent (x%.2f)" % victim.shock_flick)
	_check(victim.stunned_rounds == 0, "it no longer loses its turn")

	print("Wrap Gift badge")
	await _start([_entry(grunt, 0, Vector2(540, 1000))])
	var gifted = _main._players[0]
	gifted.set_meta("ghost_wrap", true)
	await _frames(3)  # (a few draws with the badge: no errors)
	_check(gifted.has_meta("ghost_wrap"), "the charge (and so the badge) is up")
	gifted.teleport_to(Vector2(-50, 1000))  # off the table: the charge is spent on a wrap
	await _frames(3)
	_check(not gifted.has_meta("ghost_wrap") and not gifted.knocked_off, "using the wrap removes the charge (badge gone) and saves the figure")

	if is_instance_valid(_main):
		_main.queue_free()
	print("\n%s" % ("ALL OK" if _fails.is_empty() else "FAILED: %s" % ", ".join(_fails)))
	quit(1 if not _fails.is_empty() else 0)
