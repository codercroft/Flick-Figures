extends SceneTree
## Ultimate Shieldon segmented shield test: godot --headless -s tools/shieldon_segments_test.gd (exit 1 on failure).
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


func _entry(data, team: int, pos: Vector2) -> Dictionary:
	return {"data": data, "team": team, "pos": pos, "equipment": null, "finish": null, "upgrade": Vector2i(-1, 0), "node": null}


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
	root.add_child(_main)
	current_scene = _main
	await _frames(6)


func _polys(fig) -> int:
	var n := 0
	for c in fig.get_children():
		if c is CollisionPolygon2D:
			n += 1
	return n


## A Grunt hits the Shieldon from `bearing` (world angle from the Shieldon) at `speed`.
func _hit(boss, bearing: float, speed := 2000.0) -> void:
	var grunt = _main._players[0]
	grunt.on_deck = false
	grunt._update_collision()
	grunt.teleport_to(boss.global_position + Vector2.from_angle(bearing) * 300.0)
	await _frames(2)
	grunt.linear_velocity = -Vector2.from_angle(bearing) * speed
	await _frames(40)


func _all() -> void:
	await _frames(3)
	var US = load("res://resources/figures/ultimate_shieldon.tres")
	var GR = load("res://resources/figures/grunt.tres")
	var Fig = load("res://scripts/figure.gd")
	var down := Vector2.DOWN.angle()
	print("Three segments")
	await _start([_entry(GR, 0, Vector2(540, 1000)), _entry(US, 1, Vector2(540, 700))])
	var boss = _main._enemies[0]
	var sab = boss.ability
	sab.raise_shield(boss)
	_check(sab.segment_count == 3 and _polys(boss) == 3, "3 collision segments (%d)" % _polys(boss))
	_check(absf(rad_to_deg(sab.segment_arc()) - 80.0) < 0.01, "each about 80 degrees")
	_check(sab.covers(boss, boss.global_position + Vector2(0, 200)) and not sab.covers(boss, boss.global_position + Vector2(0, -200)), "front covered, back open")
	_check(absf(angle_difference(sab.shield_angle(), down)) < 0.05, "centered on the nearest player figure")

	print("Hits damage the segment they land on")
	var hits := 0
	var f := 0.0
	while not sab.is_segment_broken(1) and hits < 8:
		sab.raise_shield(boss)
		await _hit(boss, down)
		hits += 1
		f = sab.segment_fraction(1)
		print("    hit %d: centre segment %.0f%%" % [hits, f * 100.0])
	_check(sab.segment_fraction(0) == 0.0 and sab.segment_fraction(2) == 0.0, "the other segments are untouched")
	_check(sab.is_segment_broken(1), "the centre segment broke after %d hits" % hits)
	_check(hits == 2, "2 full-power hits (%d)" % hits)

	print("A broken segment stays broken and leaves that side open")
	sab.raise_shield(boss)  # (the turn-end raise)
	_check(_polys(boss) == 2 and sab.intact_count() == 2, "only 2 segments go up (%d)" % _polys(boss))
	var toward_player: float = (_main._players[0].global_position - boss.global_position).angle()
	_check(sab.bearing_covered(sab.shield_angle(), toward_player), "turned so an intact segment faces the player")
	var grunt = _main._players[0]
	var covered_mult: float = sab.get_knockback_multiplier(boss, grunt)
	_check(absf(covered_mult - 0.1) < 0.001, "an intact segment faces the nearest player: x%.2f" % covered_mult)
	var broken_dir: Vector2 = Vector2.from_angle(sab.segment_center(1, sab.shield_angle()))
	grunt.global_position = boss.global_position + broken_dir * 300.0
	var open_mult: float = sab.get_knockback_multiplier(boss, grunt)
	_check(absf(open_mult - 2.0) < 0.001, "the broken side takes x%.2f (open)" % open_mult)

	print("Explosions damage the segment that faces them")
	await _start([_entry(GR, 0, Vector2(540, 1000)), _entry(US, 1, Vector2(540, 700))])
	boss = _main._enemies[0]
	sab = boss.ability
	sab.raise_shield(boss)
	var before: float = sab.segment_fraction(1)
	Fig.blast(_main.get_tree(), boss.global_position + Vector2(0, 160), 250.0, 1500.0, _main._players[0], null, 0)
	await _frames(3)
	_check(sab.segment_fraction(1) > before, "centre segment cracked by a blast in front (%.2f)" % sab.segment_fraction(1))
	_check(sab.segment_fraction(0) == 0.0 and sab.segment_fraction(2) == 0.0, "the side segments were not touched")

	print("Turning the intact segments toward the player (side segment broken)")
	sab._broken[0] = true
	sab.raise_shield(boss)
	var target: float = (_main._players[0].global_position - boss.global_position).angle()
	_check(sab.bearing_covered(sab.shield_angle(), target), "nearest player still covered")
	var ai = _main.ai
	var spot := Vector2(540, 700)
	var plist: Array[Figure] = []
	plist.append(_main._players[0])
	var value: float = ai._shield_position_value(boss, spot, plist, _main.board.get_table_rect())
	_check(value > -50.0, "AI: no exposure penalty while the player is covered (%.0f)" % value)
	sab._broken[1] = true
	sab._broken[2] = true
	sab.raise_shield(boss)
	_check(_polys(boss) == 0 and not sab.has_shield(), "all segments broken: no shield")
	_check(ai._shield_position_value(boss, spot, plist, _main.board.get_table_rect()) == 0.0, "AI ignores the shield when none is left")

	if _fails.is_empty():
		print("ALL OK")
		quit(0)
	else:
		print("FAILED: ", _fails)
		quit(1)
