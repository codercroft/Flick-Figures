extends SceneTree
## Export smoke test. Run against an EXPORTED pack (not the editor) to catch things that only break in
## builds, like a script failing to load and silently leaving an empty list:
##   godot --headless --export-pack "Web" build/smoke.pck
##   godot --headless --main-pack build/smoke.pck -s tools/smoke_test.gd
## Exits with code 1 and prints what failed.

var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
		printerr("[smoke] FAIL: " + what)


## A pool that failed to load shows up as a short list or one holding nulls.
func _pool(name: String, list: Array, min_size: int) -> void:
	_check(list.size() >= min_size, "%s has %d entries (expected at least %d)" % [name, list.size(), min_size])
	_check(not list.has(null), "%s contains a null (a resource or script failed to load)" % name)


func _run() -> void:
	await create_timer(0.5).timeout
	var run = root.get_node_or_null("RunManager")
	_check(run != null, "RunManager autoload is missing")
	if run == null or run.config == null:
		_check(false, "RunManager.config did not load")
		_finish()
		return
	var config = run.config
	_pool("registry.draftable", config.registry.draftable, 10)
	_pool("registry.bosses", config.registry.bosses, 3)
	_pool("arenas", config.arenas, 5)
	_pool("powers", config.power_pool, 10)
	_pool("equipment", config.equipment_pool, 10)
	_pool("finishes", config.finish_pool, 5)
	_pool("upgrades", config.upgrade_pool, 5)
	_pool("relics", config.relic_pool, 10)
	_pool("regular encounters", config.regular_encounters, 11)
	_pool("events", config.event_pool, 1)
	_check(config.minigames != null, "RunConfig.minigames did not load")
	_check(config.event_pool.size() >= 5, "event pool is missing the minigames (Bocce, Curling, Bowling, Mini-Golf)")
	for event in config.event_pool:
		_check(event.scene != null and event.scene.instantiate() != null, "event %s has no scene" % event.display_name)
	# Enemy gear rules: nothing that does nothing for the figure. (Loaded at run time: a typed GearRules
	# reference would compile Figure before the autoloads exist when this script is run with -s.)
	var rules = load("res://scripts/gear_rules.gd")
	var grunt = config.registry.grunts[0]
	var glow = null
	for finish in config.finish_pool:
		if finish.needs_ability_numbers:
			glow = finish
	_check(glow != null and not rules.fits(glow, grunt), "Glow-in-the-dark must not fit a figure without an ability")
	for item in config.equipment_pool:
		for figure in config.registry.draftable:
			if item.effect != null and figure.ability != null and item.effect.get_script() == figure.ability.get_script():
				_check(not rules.fits(item, figure), "%s must not fit %s" % [item.display_name, figure.display_name])
			for script in item.incompatible_abilities:
				if figure.ability != null and figure.ability.get_script() == script:
					_check(not rules.fits(item, figure), "%s must not fit %s" % [item.display_name, figure.display_name])
	var rarities := {}
	for relic in config.relic_pool:
		rarities[relic.rarity] = true
	_check(rarities.size() == 4, "relic rarities missing (need Common, Uncommon, Rare and Boss relics)")
	_pool("elite encounters", config.elite_encounters, 6)
	_check(config.shop != null, "shop config did not load")
	if config.shop != null:
		_pool("shop item types", config.shop.item_types, 6)
	# Every scene loads and instantiates.
	for scene_name in ["map", "main", "shop", "reward", "equip", "upgrade"]:
		var packed = load("res://scenes/%s.tscn" % scene_name)
		_check(packed != null, "scene %s did not load" % scene_name)
		if packed != null:
			var instance = packed.instantiate()
			_check(instance != null, "scene %s did not instantiate" % scene_name)
			if instance != null:
				instance.free()
	# A shop node builds a real stock (not the fallback).
	run.map.nodes[0].type = MapNode.Type.SHOP
	run.enter_node(0)
	var offers = run.shop_offers
	_check(offers.size() >= 6, "the shop made only %d offers" % offers.size())
	var titles: Array = offers.map(func(o): return o.title)
	_check(titles.any(func(t): return t.begins_with("Relic")), "the shop offers no relic")
	_check(titles.any(func(t): return t.begins_with("Power")) or titles.any(func(t): return t.begins_with("Equipment")), "the shop offers no power or equipment")
	print("[smoke] shop offers: ", titles)
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("[smoke] all checks passed")
		quit(0)
	else:
		printerr("[smoke] %d checks failed" % _failures.size())
		quit(1)
