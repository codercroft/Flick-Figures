extends SceneTree
## Duwall explosion shell damage + Ultimate Shieldon open-side knockback: godot --headless -s tools/duwall_blast_test.gd
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
	root.add_child(_main)
	current_scene = _main
	await _frames(6)


func _fig(team: int, label: String):
	var list: Array = _main._players if team == 0 else _main._enemies
	for f in list:
		if is_instance_valid(f) and f.data.display_name == label:
			return f
	return null


func _dmg(a) -> float:
	if "damage" in a:
		return a.damage
	if "first" in a:
		return maxf(_dmg(a.first), _dmg(a.second))
	return 0.0


func _all() -> void:
	await _frames(3)
	var DW = load("res://resources/figures/duwall.tres")
	var US = load("res://resources/figures/ultimate_shieldon.tres")
	var GR = load("res://resources/figures/grunt.tres")
	var Fig = load("res://scripts/figure.gd")
	var P: int = Fig.Team.PLAYER
	var E: int = Fig.Team.ENEMY
	var pos := Vector2(540, 900)
	print("Enemy blast cracks a player Duwall")
	await _start([_entry(DW, P, pos), _entry(GR, E, Vector2(540, 600))])
	var dw = _fig(P, "Duwall")
	var enemy = _fig(E, "Grunt")
	Fig.blast(_main.get_tree(), dw.global_position + Vector2(100, 0), 250.0, 1500.0, enemy, null, E)
	await _frames(3)
	var full: float = _dmg(dw.ability)
	_check(full > 0.0, "damage taken (%.0f)" % full)
	print("Player-side blast: no push, no crack")
	await _start([_entry(DW, P, pos), _entry(GR, P, Vector2(640, 900))])
	dw = _fig(P, "Duwall")
	var friend = _fig(P, "Grunt")
	Fig.blast(_main.get_tree(), dw.global_position + Vector2(100, 0), 250.0, 1500.0, friend, null, P)
	await _frames(3)
	_check(_dmg(dw.ability) == 0.0, "no shell damage from friendly blast")
	_check(dw.linear_velocity.length() < 5.0, "no push from friendly blast")
	print("Bomb Shelter")
	await _start([_entry(DW, P, pos, Vector2i(0, 2)), _entry(GR, E, Vector2(540, 600))])
	dw = _fig(P, "Duwall")
	enemy = _fig(E, "Grunt")
	Fig.blast(_main.get_tree(), dw.global_position + Vector2(100, 0), 250.0, 1500.0, enemy, null, E)
	await _frames(3)
	_check(absf(_dmg(dw.ability) - full * 0.5) < full * 0.05, "half damage (%.0f vs %.0f)" % [_dmg(dw.ability), full])
	_check(dw.linear_velocity.length() < 5.0, "no push")
	print("Ultimate Shieldon: open side x2")
	await _start([_entry(US, E, Vector2(540, 800)), _entry(GR, P, Vector2(540, 1000))])
	var us = _fig(E, "Ultimate Shieldon")
	var hitter = _fig(P, "Grunt")
	var open: float = us.ability.get_knockback_multiplier(us, hitter)
	_check(is_equal_approx(open, 2.0), "no shield: x2 (%.2f)" % open)
	us.ability.raise_shield(us)
	var shielded: float = us.ability.get_knockback_multiplier(us, hitter)
	var behind_pos: Vector2 = us.global_position + (us.global_position - hitter.global_position).normalized() * 300.0
	var dummy = _fig(P, "Grunt")
	dummy.global_position = behind_pos
	var open_side: float = us.ability.get_knockback_multiplier(us, dummy)
	_check(shielded < 0.2, "shield side deflects (%.2f)" % shielded)
	_check(is_equal_approx(open_side, 2.0), "open side x2 (%.2f)" % open_side)
	if _fails.is_empty():
		print("ALL OK")
		quit(0)
	else:
		print("FAILED: ", _fails)
		quit(1)
