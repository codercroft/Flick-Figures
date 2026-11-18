extends SceneTree
## Slippery Jim, Bomb Duo and Fat Man: godot --headless -s tools/new_bosses_test.gd
## (exit 1 on failure; also look for "SCRIPT ERROR" in the output).

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


## Starts a sandbox combat: `boss` (a BossData) as the lineup, or none, plus the placed figures.
func _start(entries: Array, boss = null, ai_off := true, ascension := 0) -> void:
	if is_instance_valid(_main):
		_main.queue_free()
		await _frames(3)
	var Setup = load("res://scripts/sandbox_setup.gd")
	Setup.begin()
	Setup.lineup_kind = "boss" if boss != null else "none"
	Setup.boss = boss
	Setup.ascension = ascension
	Setup.arena = root.get_node("RunManager").config.boss_arena
	Setup.ai_off = ai_off
	for e in entries:
		Setup.entries.append(e)
	Setup.prepare()
	_main = load("res://scenes/main.tscn").instantiate()
	_main.enemy_think_time = 0.05
	root.add_child(_main)
	current_scene = _main
	await _frames(4)
	await _until(func(): return _main._state == 0)


func _flick(fig: Node, drag := Vector2(0, 400)) -> void:
	var p: Vector2 = fig.global_position
	_main._on_press(0, p)
	_main._release_aim(p + drag)


func _settled() -> bool:
	return _main._state == 0 and _main._all_figures_resting()


func _all() -> void:
	await create_timer(0.5).timeout
	var run = root.get_node("RunManager")
	var cfg = run.config
	var reg = cfg.registry
	var grunt = load("res://resources/figures/grunt.tres")
	var jim_boss = load("res://resources/figures/boss_slippery_jim.tres")
	var duo_boss = load("res://resources/figures/boss_bomb_duo.tres")
	var fat_boss = load("res://resources/figures/boss_fat_man.tres")

	print("Pools, data and icons")
	_check(reg.bosses_act1.size() == 3 and reg.bosses_act1.has(jim_boss), "act 1 pool: The Wall, Sniper Squad, Slippery Jim")
	_check(reg.bosses_act2.size() == 3 and reg.bosses_act2.has(duo_boss), "act 2 pool: Trangle, Slime, Bomb Duo")
	_check(reg.bosses_act3.size() == 3 and reg.bosses_act3.has(fat_boss), "act 3 pool: Skull-o-tron, Mad Creator, Fat Man")
	_check(reg.bosses.size() == 9, "all nine bosses are in the registry list (sandbox and Compendium read it)")
	var jim = load("res://resources/figures/slippery_jim.tres")
	_check(is_equal_approx(jim.radius, 75.0) and is_equal_approx(jim.mass, 1.8) and is_equal_approx(jim.flick_power_multiplier, 1.3), "Jim: radius 75, mass 1.8, power x1.3")
	_check(jim.ability.stacks == 5, "Jim starts with 5 stacks")
	_check(jim_boss.enemy_flicks_per_turn == 1 and not jim_boss.back_wall, "Jim: 1 flick per turn, no back wall")
	_check(fat_boss.fat_man and fat_boss.enemies.is_empty() and fat_boss.fat_man_hits == 5, "Fat Man: no bodies, 5 hits")
	_check(duo_boss.flick_per_unit and duo_boss.enemies.size() == 2, "Bomb Duo: two bodies, a flick for each")

	print("Lineups and Boss Upgrades")
	var node := MapNode.new()
	node.column = 5
	node.type = MapNode.Type.BOSS
	run.node = node
	run.act = 0
	run.ascension = 0
	run.boss = jim_boss
	run._build_lineup()
	_check(run.enemies.size() == 1 and run.enemy_boosts[0].get("ability_values", {}).is_empty(), "Jim at level 0: no stack boost")
	run.ascension = 9
	run._build_lineup()
	_check(run.enemy_boosts[0].ability_values.get("stacks", 0) == 7, "Jim at Boss Upgrades: 7 stacks")
	run.ascension = 0
	run.boss = duo_boss
	run._build_lineup()
	_check(run.enemies.size() == 2 and run.enemy_flick_per_unit, "Bomb Duo lineup: 2 bodies, flicks per unit")
	var big: Dictionary = run.enemy_scale(0)
	var miner: Dictionary = run.enemy_scale(1)
	_check(is_equal_approx(run.enemies[0].radius * big.size, 85.0) and is_equal_approx(run.enemies[0].mass * big.mass, 2.5), "Aggro-bom boss body: radius 85, mass 2.5")
	_check(is_equal_approx(run.enemies[1].radius * miner.size, 70.0) and is_equal_approx(run.enemies[1].mass * miner.mass, 2.5), "Land Miner boss body: radius 70, mass 2.5")
	_check(run.enemy_gear[0].upgrade == Vector2i(0, 1) and run.enemy_gear[1].upgrade == Vector2i(0, 1), "Bomb Duo base: Fuse tier 1 and Multi-Mine tier 1")
	_check(run.enemy_boosts[1].ability_values.get("support_partner", false), "the miner is flagged to support its bomb")
	run.ascension = 9
	run._build_lineup()
	_check(run.enemy_gear[0].upgrade == Vector2i(0, 3) and run.enemy_gear[1].upgrade == Vector2i(0, 3), "Bomb Duo at Boss Upgrades: tier 3 on both")
	run.ascension = 0
	run.boss = fat_boss
	run._build_lineup()
	_check(run.enemies.is_empty() and run.fat_man_hits_needed == 5, "Fat Man lineup: no bodies, 5 hits")
	run.ascension = 9
	run._build_lineup()
	_check(run.fat_man_hits_needed == 6, "Fat Man at Boss Upgrades: 6 hits")
	run.ascension = 0

	await _slippery(grunt, jim, jim_boss)
	await _bomb_duo(grunt, duo_boss)
	await _fat_man(grunt, fat_boss)
	await _later_changes(grunt, jim_boss, fat_boss)

	if is_instance_valid(_main):
		_main.queue_free()
	print("\n%s" % ("ALL OK" if _fails.is_empty() else "FAILED: %s" % ", ".join(_fails)))
	quit(1 if not _fails.is_empty() else 0)


func _slippery(grunt, jim, jim_boss) -> void:
	print("Slippery Jim")
	await _start([_entry(grunt, 0, Vector2(540, 1500)), _entry(jim, 1, Vector2(540, 800))])
	var jimf = _main._enemies[0]
	var shooter = _main._players[0]
	var start: Vector2 = jimf.global_position
	_flick(shooter, Vector2(0, 600))
	await _until(func(): return _settled(), 20.0)
	print("    shooter y %.0f (Jim %.0f), players %d" % [shooter.global_position.y, start.y, _main._players.size()])
	_check(jimf.ability.stacks_left() == 4, "a player hit takes exactly one stack (left %d)" % jimf.ability.stacks_left())
	_check(jimf.global_position.distance_to(start) < 40.0, "the hit does not move him (%.0f px)" % jimf.global_position.distance_to(start))
	_check(shooter.global_position.y > start.y + 100.0, "the hitter bounced back like off a wall")
	var ability = jimf.ability
	var hitter = _main._players[0]
	var other_hitter = _main._players[0]
	ability._left = 5
	ability._max = 5
	ability._touching.clear()
	ability._lose_stack(jimf, hitter)
	ability._lose_stack(jimf, hitter)
	_check(ability.stacks_left() == 4, "the same continuous contact counts once (left %d)" % ability.stacks_left())
	ability._lose_stack(jimf, null)
	ability._lose_stack(jimf, null)
	_check(ability.stacks_left() == 2, "separate hits / explosions in the same instant each take a stack (left %d)" % ability.stacks_left())
	hitter.global_position = jimf.global_position + Vector2(0, 500)
	ability.on_physics_process(jimf, 0.016)
	ability._lose_stack(jimf, hitter)
	_check(ability.stacks_left() == 1, "after separating, the same figure can hit again")
	ability._touching.clear()
	ability._lose_stack(jimf, hitter)
	_check(ability.stacks_left() == 0, "the last stack goes")
	ability._lose_stack(jimf, null)
	_check(ability.stacks_left() == 0, "stacks never regenerate")
	# own side's turn: nullified but free
	var own = jim.ability.duplicate()
	own._left = 5
	own._max = 5
	_main.turret_side = 1
	own.on_impact(jimf, other_hitter, 900.0, Vector2.ZERO)
	_check(own.stacks_left() == 5, "a hit on his own side's turn costs no stack")
	_main.turret_side = 0
	own.on_exploded(jimf, null)
	_check(own.stacks_left() == 4, "an explosion on the player's turn costs one stack")
	_check(own.get_explosion_multiplier(jimf, null) == 0.0, "explosions do not push him while slippery")
	# a real enemy turn: he attacks like a strong Grunt
	await _start([_entry(grunt, 0, Vector2(540, 1000)), _entry(jim, 1, Vector2(540, 600))], null, false)
	var before: int = _main.enemy_flicks_made
	_flick(_main._players[0], Vector2(0, 40))
	await _until(func(): return _main._enemy_turns_taken >= 1 and _settled(), 40.0)
	_check(_main.enemy_flicks_made - before == 1, "Jim takes his 1 flick")
	# at 0 he is a normal figure
	await _start([_entry(grunt, 0, Vector2(540, 1500)), _entry(jim, 1, Vector2(540, 800))])
	jimf = _main._enemies[0]
	jimf.ability._left = 0
	start = jimf.global_position
	_flick(_main._players[0], Vector2(0, 600))
	await _until(func(): return _settled(), 20.0)
	_check(not is_instance_valid(jimf) or jimf.knocked_off or jimf.global_position.distance_to(start) > 60.0, "with no stacks he is knocked around like anyone")


func _bomb_duo(grunt, duo_boss) -> void:
	print("Bomb Duo")
	await _start([_entry(grunt, 0, Vector2(540, 1500))], duo_boss, false)
	var bomb = null
	var miner = null
	for e in _main._enemies:
		if e.data.ability is AggroBomAbility:
			bomb = e
		else:
			miner = e
	_check(bomb != null and miner != null, "both bodies are on the table")
	_check(bomb.ability.collisions_needed == 3, "Aggro-bom carries Hair Trigger (3 collisions)")
	_check(is_equal_approx(miner.ability.mine_spacing, 400.0 * 0.67), "Land Miner carries More Mines (spacing x0.67)")
	_check(_main._enemy_flicks_now() == 2, "two flicks a turn while both live")
	var ai = _main.ai
	ai._prepare()
	_check(ai._support_partner(miner) == bomb, "the miner supports the bomb while it lives")
	var shot: Dictionary = ai._best_shot_for(miner, _main._players, _main.board.get_table_rect(), _main.max_flick_force)
	_check(shot.kind == "reposition", "the miner does not attack while the bomb lives (%s)" % shot.kind)
	bomb.knock_off(0.1)
	_main._enemies.erase(bomb)
	await _frames(2)
	_check(ai._support_partner(miner) == null, "no partner: the miner plays normally")
	_check(_main._enemy_flicks_now() == 1, "one flick once only one body is left")
	# a real enemy turn: two flicks, and the miner lays mines
	await _start([_entry(grunt, 0, Vector2(540, 1500)), _entry(grunt, 0, Vector2(300, 1500))], duo_boss, false)
	var flicks_before: int = _main.enemy_flicks_made
	_flick(_main._players[0], Vector2(0, 100))
	await _until(func(): return _main._enemy_turns_taken >= 1 and _settled(), 60.0)
	_check(_main.enemy_flicks_made - flicks_before == 2, "the enemy took 2 flicks (got %d)" % (_main.enemy_flicks_made - flicks_before))
	if _main._players.is_empty():
		_main._spawn_figure(Figure.Team.PLAYER, grunt, Vector2(540, 1500))
	_flick(_main._players[_main._players.size() - 1], Vector2(0, 100))
	await _until(func(): return _main._enemy_turns_taken >= 2 and _settled(), 60.0)
	_check(get_nodes_in_group("mines").size() > 0, "the miner laid mines (%d)" % get_nodes_in_group("mines").size())
	# explosions of the duo push each other (enemy explosions push everyone)
	var a = _main._enemies[0]
	_check(not Figure.blast_immune(a, Figure.Team.ENEMY), "enemy explosions push their own side")


func _fat_man(grunt, fat_boss) -> void:
	print("Fat Man")
	await _start([_entry(grunt, 0, Vector2(540, 1500)), _entry(grunt, 0, Vector2(300, 1500)), _entry(grunt, 0, Vector2(780, 1500))], fat_boss, false)
	var fat = _main._fat_man
	_check(fat != null and fat.stomach.remaining() == 5 and fat.hands.size() == 2, "stomach (5 hits) and two hands are built")
	_check(_main._enemies.is_empty(), "no enemy figures")
	var stomach = fat.stomach
	var p0 = _main._players[0]
	var stomach_pos: Vector2 = stomach.global_position
	# a soft touch does not count
	stomach.hit_by(p0, Vector2(0, -300))
	_check(stomach.hits == 0, "a gentle touch does not count")
	# a real shot up the middle
	_flick(p0, Vector2(0, 700))
	await _until(func(): return stomach.hits >= 1, 20.0)
	_check(stomach.hits == 1, "a hard hit counts")
	var shot_flick = _main.player_flicks
	stomach.hit_by(p0, Vector2(0, -2000))
	_check(stomach.hits == 1, "only one counted hit per flick")
	# wait for Fat Man's grab
	await _until(func(): return not fat.held_figures().is_empty(), 40.0)
	var held: Figure = fat.held_figures()[0] if not fat.held_figures().is_empty() else null
	_check(held != null, "a hand grabbed a figure")
	if held == null:
		return
	await _until(func(): return _main._state == 0, 20.0)
	_check(held.held and _main._players.has(held) and not held.knocked_off, "the held figure still counts as alive")
	_check(not _main._flick_pool().has(held), "a held figure cannot be flicked")
	_check(held.collision_layer == 0, "a held figure cannot be hit")
	var hand = fat._holder()
	_check(hand != null and hand.collision_layer != 0, "the hand is solid again at its resting spot")
	_check(hand.global_position.distance_to(hand.home) < 5.0, "the hand went back home with it")
	# counterplay: a hard hit on the holding hand drops the figure
	var hitter = _main._players[0] if _main._players[0] != held else _main._players[1]
	hand.hit_by(hitter, Vector2(0, -300))
	_check(hand.is_holding(), "a soft hit does not make it drop the figure")
	hand.hit_by(hitter, Vector2(0, -1500))
	await _frames(2)
	_check(not held.held and not hand.is_holding(), "a hard hit makes the hand drop it")
	_check(held.collision_layer != 0 and not held.freeze, "a dropped figure is a normal figure again")
	# second grab then the throw
	await _until(func(): return _main._state == 0, 20.0)
	_flick(_main._players[1], Vector2(0, 200))
	await _until(func(): return not fat.held_figures().is_empty(), 40.0)
	await _until(func(): return _main._state == 0, 20.0)
	var held2: Figure = fat.held_figures()[0] if not fat.held_figures().is_empty() else null
	_check(held2 != null, "he grabs again after a drop")
	if held2 != null:
		_flick(_main._players[0] if _main._players[0] != held2 else _main._players[2], Vector2(0, 150))
		await _until(func(): return not held2.held, 40.0)
		_check(not held2.held and _main._players.has(held2) or held2.knocked_off, "the next turn the hand throws it (it stays the player's)")
		await _until(func(): return _main._state == 0, 30.0)
	# the lone figure: grabbed, then thrown toward an edge
	await _start([_entry(grunt, 0, Vector2(540, 1000))], fat_boss, false)
	fat = _main._fat_man
	var lone = _main._players[0]
	await _until(func(): return not fat.held_figures().is_empty() or _main._state == 0, 5.0)
	_flick(lone, Vector2(0, 80))  # a little nudge to pass the turn
	var grabbed := await _until(func(): return lone.held, 40.0)
	_check(grabbed, "a lone figure is grabbed too")
	var gone := await _until(func(): return lone.knocked_off or (not lone.held and _main._state == 0 and lone.global_position.distance_to(fat.hands[0].home) > 100.0), 60.0)
	_check(gone and (lone.knocked_off or not lone.held), "a lone figure is thrown (toward the nearest edge)")
	_check(not _main._players.has(lone) or not lone.knocked_off, "the player's figure list stays consistent")


func _later_changes(grunt, jim_boss, fat_boss) -> void:
	print("Swap refuses boss figures, Shrink Ray 25%, opening shield, Fat Man on the deck")
	var SW = load("res://scripts/powers/swap_effect.gd").new()
	await _start([_entry(grunt, 0, Vector2(540, 1500))], jim_boss)
	var jimf = _main._enemies[0]
	_check(SW.target_problem(_main, jimf, null) != "", "Slippery Jim can't be swapped")
	_check(SW.target_problem(_main, _main._players[0], null) == "", "a player figure can")
	for path in ["slime_medium", "slime_small", "skull_ball", "slime_large", "wall_piece", "trangle", "skull_o_tron", "mad_creator"]:
		var d = load("res://resources/figures/%s.tres" % path)
		_check(d.swap_immune or d.boss_body, "%s is swap-immune" % path)
	_check(not grunt.swap_immune and not grunt.boss_body, "a Grunt (Mad Creator summon) can be swapped")
	var duo = load("res://resources/figures/boss_bomb_duo.tres")
	await _start([_entry(grunt, 0, Vector2(540, 1500))], duo)
	_check(_main._enemies.all(func(e): return SW.target_problem(_main, e, null) != ""), "both Bomb Duo bodies are refused")
	var shrink = load("res://scripts/powers/shrink_ray_effect.gd").new()
	_check(is_equal_approx(shrink.size_factor, 0.75) and is_equal_approx(shrink.mass_factor, 0.75), "Shrink Ray factors 0.75")
	var e = _main._enemies[0]
	var r: float = e.radius
	var m: float = e.mass
	shrink.apply(_main, [e])
	_check(is_equal_approx(e.radius, r * 0.75) and is_equal_approx(e.mass, m * 0.75), "Shrink Ray: radius and mass x0.75")
	var us = load("res://resources/figures/ultimate_shieldon.tres")
	await _start([_entry(grunt, 0, Vector2(540, 1000)), _entry(us, 1, Vector2(540, 500))])
	await _frames(5)
	var usf = _main._enemies[0]
	_check(usf.ability._up and usf.ability.intact_count() == usf.ability.segment_count, "Ultimate Shieldon starts with its shield up (all segments)")
	# Fat Man: grab a figure still on the deck, throw it into another deck figure
	await _start([_entry(grunt, 0, Vector2(540, 1500)), _entry(grunt, 0, Vector2(300, 1500))], fat_boss)
	var fat = _main._fat_man
	var a = _main._players[0]
	var b = _main._players[1]
	_check(a.on_deck and b.on_deck, "both figures start on the deck")
	var hand = fat.hands[0]
	fat._hold(a, hand)
	_check(a.held and a.on_deck, "a figure still on the deck can be held")
	var start: Vector2 = b.global_position
	# the throw's own release code, aimed straight at the deck figure
	hand.held = null
	a.teleport_to(Vector2(540, 1000))
	fat._release(a)
	a.on_deck = false
	a.launch((b.global_position - a.global_position).normalized() * fat.throw_speed * a.mass)
	a.collision_layer = Figure.LAYER_ENEMY
	a.collision_mask = Figure.LAYER_ENEMY | Figure.LAYER_FLICKED | Figure.LAYER_ON_DECK | Figure.LAYER_ARENA
	await _until(func(): return _main._all_figures_resting(), 20.0)
	_check(not is_instance_valid(b) or b.knocked_off or b.global_position.distance_to(start) > 40.0, "the thrown figure knocked back a figure on the deck")
