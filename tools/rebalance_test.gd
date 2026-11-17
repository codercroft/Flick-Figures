extends SceneTree
## Checks the numbers and rules of the 2026-11-17 balance changes: godot --headless -s tools/rebalance_test.gd (exit 1 on failure)
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


func _entry(data, team: int, pos: Vector2, upgrade := Vector2i(-1, 0), equipment = null, finish = null) -> Dictionary:
	return {"data": data, "team": team, "pos": pos, "equipment": equipment, "finish": finish, "upgrade": upgrade, "node": null}


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


func _fig(name: String):
	return load("res://resources/figures/%s.tres" % name)


func _all() -> void:
	await _frames(3)
	var run = root.get_node("RunManager")
	var cfg = run.config
	print("Numbers")
	_check(_main_cap(), "boss flick cap is 5")
	_check(_fig("juicer").rarity == 1 and _fig("ghost").rarity == 0, "Juicer Uncommon, Ghost Common")
	var ab = _fig("aggro_bom")
	var tree = run.tree_for(ab)
	_check(is_equal_approx(tree.path_b[0].ability_overrides.rage_knockback_per_hit, 0.2) and is_equal_approx(tree.path_b[1].ability_overrides.rage_power_per_hit, 0.2), "Hit Fury / Hit Bulk +20% per hit")
	var dw = _fig("duwall")
	await _start([_entry(dw, 0, Vector2(540, 1000)), _entry(dw, 0, Vector2(300, 1000), Vector2(0, 1)), _entry(_fig("grunt"), 1, Vector2(540, 500))])
	_check(is_equal_approx(_main._players[0].ability.shell_strength, 4000.0), "Duwall shell 4000")
	_check(is_equal_approx(_main._players[1].ability.shell_strength, 6000.0), "Thick Shell: 6000 (x1.5 of the new base)")
	var big = load("res://resources/encounters/big_brother.tres")
	_check(is_equal_approx(big.enemies[0].ability_values.shell_strength, 8000.0), "Big Brother's shell 8000 (double the base)")
	var dt = run.tree_for(dw)
	_check(dt.path_b[0].display_name == "Shrapnel Shell" and dt.path_b[1].display_name == "Heavy Ram" and dt.path_b[2].display_name == "Shell Smash", "Ram path order: Shrapnel Shell, Heavy Ram, Shell Smash")
	var ph = _fig("powerhouse")
	await _start([_entry(ph, 0, Vector2(540, 1000)), _entry(ph, 0, Vector2(300, 1000), Vector2(1, 1)), _entry(ph, 0, Vector2(700, 1000), Vector2(1, 2)), _entry(_fig("grunt"), 1, Vector2(540, 500))])
	var enemy = _main._enemies[0]
	var mults: Array = []
	for i in 3:
		mults.append(_main._players[i].ability.get_knockback_multiplier(_main._players[i], enemy))
	_check(is_equal_approx(mults[0], 2.0) and is_equal_approx(mults[1], 1.5) and is_equal_approx(mults[2], 1.0), "Powerhouse takes x2 / x1.5 (Normal Skin) / x1 (Thick Skin) from enemies (%s)" % str(mults))
	_check(is_equal_approx(_main._players[2].data.knockback_taken_multiplier, ph.knockback_taken_multiplier), "Thick Skin no longer halves its base knockback")
	var bp = _fig("bumper")
	await _start([_entry(bp, 0, Vector2(300, 1000)), _entry(bp, 0, Vector2(540, 1000), Vector2(0, 1)), _entry(bp, 0, Vector2(700, 1000), Vector2(0, 2)), _entry(bp, 0, Vector2(860, 1000), Vector2(0, 3))])
	var ratios: Array = []
	for i in 4:
		ratios.append(snappedf(_main._players[i].ability.bump_ratio, 0.01))
	_check(ratios == [1.18, 1.3, 1.48, 1.6], "Bumper launch x1.18 / 1.3 / 1.48 / 1.6 (%s)" % str(ratios))

	print("Splitter: Lil Warrior")
	var sx = _fig("splitter")
	var st = run.tree_for(sx)
	_check(st.path_b_name == "Lil Warrior" and st.path_b[1].display_name == "Full Force", "path B is Lil Warrior, tier 2 Full Force")
	var boots = null
	for item in cfg.equipment_pool:
		if item.display_name == "Weighted Boots":
			boots = item
	var glitter = null
	for f in cfg.finish_pool:
		if f.display_name == "Glitter":
			glitter = f
	for tier in [1, 3]:
		await _start([_entry(sx, 0, Vector2(540, 1000), Vector2(1, tier), boots, glitter), _entry(_fig("grunt"), 1, Vector2(540, 500))])
		var parent = _main._players[0]
		var original_item = parent.equipment
		parent._core_ability._armed = true
		parent.ability.on_impact(parent, _main._enemies[0], 500.0, parent.global_position + Vector2(0, -80))
		await _frames(4)
		var minis: Array = _main._players.filter(func(f): return f != parent and is_instance_valid(f) and not f.knocked_off)
		var with_item := 0
		var own_copies := true
		var with_finish := 0
		for m in minis:
			if m.equipment != null:
				with_item += 1
				if m.equipment == original_item:
					own_copies = false
			if m.finish != null:
				with_finish += 1
		for m in minis:
			for o in minis:
				if m != o and m.equipment != null and m.equipment == o.equipment:
					own_copies = false
		_check(minis.size() >= 2 and with_item == minis.size() and own_copies, "tier %d: every mini has its own copy of the equipment (%d of %d)" % [tier, with_item, minis.size()])
		_check(with_finish == (minis.size() if tier == 3 else 0), "tier %d: minis with Splitter's finish: %d" % [tier, with_finish])
		_check(parent.equipment == original_item and original_item != null, "the original item stays Splitter's (it goes back to the bag after combat)")
	await _start([_entry(sx, 0, Vector2(540, 1000), Vector2(-1, 0), boots, glitter), _entry(_fig("grunt"), 1, Vector2(540, 500))])
	var plain = _main._players[0]
	plain._core_ability._armed = true
	plain.ability.on_impact(plain, _main._enemies[0], 500.0, plain.global_position + Vector2(0, -80))
	await _frames(4)
	var bare: Array = _main._players.filter(func(f): return f != plain and is_instance_valid(f) and not f.knocked_off)
	_check(bare.size() >= 2 and bare.all(func(m): return m.equipment == null and m.finish == null), "without the upgrades the minis carry nothing")
	if _fails.is_empty():
		print("ALL OK")
		quit(0)
	else:
		print("FAILED: ", _fails)
		quit(1)


func _main_cap() -> bool:
	var m = load("res://scenes/main.tscn").instantiate()
	var cap: int = m.max_enemy_flicks
	m.free()
	return cap == 5
