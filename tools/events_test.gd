extends SceneTree
## Event tests (The Gamer, Finisher, Gear Man, Vending, Recycler, Cup Toss, Duelist, King of the Hill, Punching Bag, permanent gear,
## Bruised): godot --headless -s tools/events_test.gd --fixed-fps 60 (exit 1 on failure).

var _fails: Array[String] = []
var run


func _initialize() -> void:
	_all()


func _check(ok: bool, what: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _scene(path: String) -> Node:
	var node: Node = load(path).instantiate()
	root.add_child(node)
	current_scene = node
	await _frames(3)
	return node


func _new_run(deck_size := 4) -> void:
	run.start_new_run(0)
	run.money = 20
	while run.deck.size() > deck_size:
		run.remove_deck_slot(run.deck.size() - 1)


func _all() -> void:
	await create_timer(0.5).timeout
	run = root.get_node("RunManager")
	var cfg = run.config

	print("Event pool")
	var names: Array = cfg.event_pool.map(func(e): return e.display_name)
	print("  ", names)
	_check(names.size() == 10 and names.has("The Gamer") and names.has("Punching Bag") and not names.has("Bocce"), "10 events, the four old games are gone from the pool")
	_check(cfg.gamer_games.size() == 4, "The Gamer has 4 games to pick from")
	for event in cfg.event_pool:
		_check(event.scene != null, "%s has a scene" % event.display_name)

	print("Permanent gear")
	_new_run()
	var boots = load("res://resources/equipment/weighted_boots.tres")
	var anchor = load("res://resources/equipment/anchor.tres")
	_check(run.attach_permanent(boots, 0) and run.is_locked(0), "attach_permanent locks it")
	run.add_equipment(anchor)
	_check(not run.equip(anchor, 0), "equip onto a locked slot is refused")
	_check(not run.unequip(0), "unequip a locked item is refused")
	_check(not run.attach_permanent(anchor, 0), "Gear Man cannot replace a permanent item")
	run.attach_permanent(anchor, 1)
	run.move_deck_slot(1, 3)
	_check(run.is_locked(3) and not run.is_locked(1) and run.deck_equipment[3] == anchor, "the lock moves with its figure when reordering")
	var stored: int = run.equipment_inventory.size()
	run.replace_figure(0, cfg.registry.draftable[0])
	_check(run.deck_equipment[0] == null and not run.is_locked(0) and run.equipment_inventory.size() == stored, "replacing the figure loses the item and the lock")
	run.attach_permanent(boots, 1)
	run.deck_equipment[2] = anchor
	run.attach_permanent(boots, 2)
	_check(run.equipment_inventory.has(anchor), "the old, non-permanent item goes to storage")
	run.bruise(2)
	_check(run.is_bruised(2), "bruise")
	run.clear_bruises()
	_check(not run.is_bruised(2), "bruises clear")

	print("Gear Man / Finisher / Gamer screens")
	_new_run()
	var gear = await _scene("res://scenes/events/gear_man.tscn")
	_check(gear.frame.content.get_child_count() == 3, "Gear Man offers 3 items (%d)" % gear.frame.content.get_child_count())
	gear.queue_free()
	await _frames(2)
	var fin = await _scene("res://scenes/events/finisher.tscn")
	_check(fin.frame.content.get_child_count() == 3, "Finisher offers 3 finishes (%d)" % fin.frame.content.get_child_count())
	fin.queue_free()
	await _frames(2)
	var gamer = await _scene("res://scenes/events/gamer.tscn")
	_check(gamer.frame.content.get_child_count() == 3, "The Gamer offers 3 games (%d)" % gamer.frame.content.get_child_count())
	gamer.queue_free()
	await _frames(2)

	print("Vending Machine")
	_new_run()
	var vend = await _scene("res://scenes/events/vending_machine.tscn")
	_check(vend._price() == 4, "first buy $4")
	cfg.minigames.vending_jam_chance = 1.0
	var before: int = run.money
	vend._buy()
	_check(run.money == before - 4 and vend._price() == 6, "a jam eats the money and the next price is $6")
	cfg.minigames.vending_jam_chance = 0.0
	before = run.money
	var inv_before: int = run.equipment_inventory.size() + run.powers.count(null)
	vend._buy()
	_check(run.money == before - 6, "a normal buy costs $6")
	cfg.minigames.vending_jam_chance = 0.15
	vend.queue_free()
	await _frames(2)

	print("Recycler")
	_new_run()
	var rec = await _scene("res://scenes/events/recycler.tscn")
	run.deck[0] = cfg.registry.draftable.filter(func(f): return f.rarity == 1)[0]
	var money: int = run.money
	rec._recycle(0)
	_check(run.deck.size() == 3 and run.money == money + 5 and rec.follow_up_steps == [{"kind": "equipment"}], "Uncommon: equipment + $5, the deck shrinks")
	rec.queue_free()
	_new_run(1)
	rec = await _scene("res://scenes/events/recycler.tscn")
	rec._recycle(0)
	_check(run.deck.size() == 1, "the last figure cannot be recycled")
	rec.queue_free()
	await _frames(2)

	print("Cup Toss")
	_new_run()
	var cup = await _scene("res://scenes/events/cup_toss.tscn")
	_check(cup.cup_at(cup.cup_center(0)) == 0 and cup.cup_at(cup.cup_center(2)) == 2 and cup.cup_at(Vector2(0, 0)) == -1, "cup hit test")
	cup._ball.global_position = cup.cup_center(1)
	cup._ball.launch(Vector2.ZERO)
	cup.player_flicked.emit()
	await create_timer(2.0).timeout
	_check(run.reward_steps == [{"kind": "equipment"}], "middle cup = equipment (%s)" % [run.reward_steps])
	cup.queue_free()
	await _frames(2)

	print("Punching Bag calibration")
	_new_run()
	var bag = await _scene("res://scenes/events/punching_bag.tscn")
	bag._slot_picked.emit(0)
	await _frames(3)
	bag._hero.global_position = Vector2(540, 1270)
	var impulse: float = bag.full_force(bag._hero)
	bag._hero.launch(Vector2(0, -impulse))
	bag.player_flicked.emit()
	var t := 0.0
	while not bag._finished and t < 30.0:
		await create_timer(0.2).timeout
		t += 0.2
	var momentum: float = bag.bag.mass * bag._peak
	print("  full-power Grunt hit: momentum %.0f, score %d" % [momentum, bag._score])
	_check(bag._finished, "the bag finished")
	_check(absi(bag._score - 33) <= 3, "a full Grunt hit scores about 33 (%d)" % bag._score)
	bag.queue_free()
	await _frames(2)

	print("Duelist")
	_new_run()
	var duel = await _scene("res://scenes/events/duelist.tscn")
	duel._slot_picked.emit(0)
	await _frames(5)
	_check(duel._rival != null and duel._hero != null, "both duelists exist")
	await create_timer(0.8).timeout  # (the duel waits half a second before the first flick)
	duel._hero.global_position = duel.board_rect.get_center() + Vector2(0, 100)
	duel._rival.global_position = duel.board_rect.get_center() + Vector2(0, -100)
	duel._hero.launch(Vector2(0, -2400))
	duel._flick_figure = null
	duel.player_flicked.emit()
	await _frames(10)
	t = 0.0
	while not (duel._finished or t > 40.0):
		await create_timer(0.2).timeout
		t += 0.2
	print("  flick fig ", duel._flick_figure, " hero ", duel.alive(duel._hero), " rival ", duel.alive(duel._rival), " steps: ", run.reward_steps, " bruised: ", run.is_bruised(0), " finished ", duel._finished, " t ", t)
	_check(duel._finished and run.reward_steps == [{"kind": "upgrade", "slot": 0}], "knocking the rival off wins an Upgrade for that figure")
	duel.queue_free()
	await _frames(2)
	_new_run()
	duel = await _scene("res://scenes/events/duelist.tscn")
	duel._conclude(-1)
	_check(run.is_bruised(0), "a lost duel bruises the figure")
	duel.queue_free()

	print("King of the Hill")
	_new_run()
	var hill = await _scene("res://scenes/events/king_of_the_hill.tscn")
	hill._slot_picked.emit(0)
	await _frames(3)
	hill._slot_picked.emit(1)
	await _frames(3)
	hill._slot_picked.emit(2)
	await _frames(5)
	_check(hill._mine.size() == 3 and hill.figures_in_zone() == 3, "3 figures start in the zone")
	t = 0.0
	while not hill._finished and t < 90.0:
		if not hill._selectable.is_empty() and hill._flick_figure != null:
			var f = hill._flick_figure
			hill._selectable.clear()
			hill._flick_figure = null
			f.selected = false
			hill.player_flicked.emit()
		await create_timer(0.2).timeout
		t += 0.2
	for f in hill._mine:
		print("  figure alive ", hill.alive(f), " ", f.global_position if is_instance_valid(f) else "-", " zone center ", hill._zone_center)
	print("  held the zone: ", hill.figures_in_zone(), " steps ", run.reward_steps, " t ", t)
	_check(hill._finished, "King of the Hill runs through the three enemy turns")
	hill.queue_free()
	await _frames(2)

	print("The Gamer's win and loss")
	_new_run()
	var game = await _scene("res://scenes/events/curling.tscn")
	game.conclude_contest(1, [] as Array[String])
	_check(run.reward_steps == [{"kind": "upgrade"}, {"kind": "finish"}], "win: Upgrade + finish steps")
	game.queue_free()
	await _frames(2)
	game = await _scene("res://scenes/events/curling.tscn")
	game.conclude_contest(-1, [] as Array[String])
	_check(run.minigame_penalty, "loss: harder next fight")
	game.queue_free()

	print("\nFAILED: %s" % [_fails] if not _fails.is_empty() else "\nAll event tests passed")
	quit(1 if not _fails.is_empty() else 0)
