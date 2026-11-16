extends SceneTree
## One worker process of the balance sims (tools only). run_sims.py starts several of these in parallel and merges their CSVs.
##   godot --headless -s tools/balance/sim_worker.gd -- --sim=1 --fights=50 --shard=0/4 --out=/path/sim1_0.csv [options]
## Options: --sim=1|2|3|4|check  --fights=N  --shard=K/N  --seed=S  --scale=T (Engine.time_scale)  --out=FILE
##   --filter=text (only subjects / targets whose name contains it)  --acts=1,2,3  --runs=N  --ascension=L  --policy=NAME
##   --decks=FILE  --accuracy=0.85
## Sims 1-3 write one CSV row per fight; sim 4 writes runs (see run_sim.gd). It refuses to start unless user:// points into a
## throw-away folder (run_sims.py sets XDG_DATA_HOME), so the player's saves, unlocks and run history are never read or written.

var opts := {}
var run
var cfg
var Fight
var Bot


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		opts[parts[0]] = parts[1] if parts.size() > 1 else "true"
	_go()


func _go() -> void:
	for i in 3:
		await process_frame
	if not OS.get_user_data_dir().contains("balance_sim") and not opts.has("allow-real-user-dir"):
		printerr("sim_worker: refusing to run: user:// is %s (run it through tools/balance/run_sims.py, which uses a temporary folder)" % OS.get_user_data_dir())
		quit(2)
		return
	run = root.get_node("RunManager")
	cfg = run.config
	Fight = load("res://tools/balance/fight_runner.gd")
	Bot = load("res://tools/balance/player_bot.gd")
	var scale := float(opts.get("scale", 1.0))
	if scale > 1.0:
		Engine.time_scale = scale
		Engine.max_physics_steps_per_frame = maxi(8, int(ceil(scale)) * 2)
	var sim: String = opts.get("sim", "1")
	var code := 0
	match sim:
		"1", "2", "3":
			code = await _fight_sim(sim)
		"4":
			var RunSim = load("res://tools/balance/run_sim.gd")
			code = await RunSim.new(self).play_runs()
		_:
			printerr("unknown sim " + sim)
			code = 2
	quit(code)


# --- Job lists ------------------------------------------------------------------------------------------------------

## Regular encounters available in `act`.
func _regular(act: int) -> Array:
	return cfg.regular_encounters.filter(func(e): return e.available_in(act - 1))


func _elites(act: int) -> Array:
	return cfg.elite_encounters.filter(func(e): return e.available_in(act - 1))


func _bosses_of(act: int) -> Array:
	return [cfg.registry.bosses_act1, cfg.registry.bosses_act2, cfg.registry.bosses_act3][act - 1]


func _acts() -> Array:
	var list: Array = []
	for a in str(opts.get("acts", "1,2,3")).split(","):
		list.append(int(a))
	return list


func _match(name: String) -> bool:
	return not opts.has("filter") or name.to_lower().contains(str(opts.filter).to_lower())


## Sim 1: every draftable figure + 3 Grunts vs each act's regular encounters.
## Sim 2: every figure at tier 3 of each path (+ 3 Grunts) vs act 2 and 3 encounters.
## Sim 3: the decks in decks.json vs every regular encounter, elite and boss.
func _jobs(sim: String) -> Array:
	var jobs: Array = []
	var grunt: FigureData = cfg.registry.grunts[0]
	var acts := _acts()
	if sim == "1" or sim == "2":
		var names: Array = []
		for figure in cfg.registry.draftable:
			if _match(figure.display_name):
				names.append(figure)
		for figure in names:
			var variants: Array = [{"label": figure.display_name, "slot": Fight.slot(figure)}]
			if sim == "2":
				variants = []
				for path in 2:
					var tree = run.tree_for(figure)
					if tree != null:
						variants.append({"label": "%s %s" % [figure.display_name, tree.path_name(path)], "slot": Fight.slot(figure, Vector2i(path, 3)), "path": path})
			for variant in variants:
				for act in acts:
					if sim == "2" and act == 1:
						continue
					for encounter in _regular(act):
						var deck: Array = [variant.slot]
						for i in 3:
							deck.append(Fight.slot(grunt))
						jobs.append({"subject": variant.label, "figure": figure.display_name, "target": encounter.display_name, "act": act,
								"spec": {"kind": "encounter", "encounter": encounter, "act": act, "deck": deck}})
	else:
		for deck_def in _load_decks():
			if not _match(deck_def.name):
				continue
			for act in acts:
				for encounter in _regular(act):
					jobs.append({"subject": deck_def.name, "figure": "", "target": encounter.display_name, "act": act, "group": "regular",
							"spec": {"kind": "encounter", "encounter": encounter, "act": act, "deck": deck_def.deck, "relics": deck_def.relics}})
				for encounter in _elites(act):
					jobs.append({"subject": deck_def.name, "figure": "", "target": encounter.display_name, "act": act, "group": "elite",
							"spec": {"kind": "elite", "encounter": encounter, "act": act, "deck": deck_def.deck, "relics": deck_def.relics}})
				for boss in _bosses_of(act):
					jobs.append({"subject": deck_def.name, "figure": "", "target": boss.display_name, "act": act, "group": "boss",
							"spec": {"kind": "boss", "boss": boss, "act": act, "deck": deck_def.deck, "relics": deck_def.relics}})
	return jobs.filter(func(j): return _match(j.subject) or _match(j.target))


## decks.json -> [{name, deck: [slot...], relics: [RelicData...]}], looked up by display name (an unknown name stops the sim).
func _load_decks() -> Array:
	var path: String = opts.get("decks", "res://tools/balance/decks.json")
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	var out: Array = []
	for d in data.decks:
		var deck: Array = []
		for s in d.slots:
			var upgrade := Vector2i(-1, 0)
			if s.has("upgrade"):
				upgrade = Vector2i(int(s.upgrade[0]), int(s.upgrade[1]))
			deck.append(Fight.slot(_by_name(cfg.registry.draftable + cfg.registry.grunts, s.figure), upgrade,
					_by_name(cfg.finish_pool, s.finish) if s.has("finish") else null,
					_by_name(cfg.equipment_pool, s.equipment) if s.has("equipment") else null))
		var relics: Array = []
		for r in d.get("relics", []):
			relics.append(_by_name(cfg.relic_pool, r))
		out.append({"name": d.name, "deck": deck, "relics": relics})
	return out


func _by_name(list: Array, name: String):
	for item in list:
		if item.display_name == name:
			return item
	printerr("sim_worker: unknown name '%s'" % name)
	quit(2)
	return null


# --- Running fights ---------------------------------------------------------------------------------------------------

const HEADER := ["sim", "subject", "figure", "group", "target", "act", "fight", "seed", "win", "timeout", "figures_lost", "figures_left",
		"player_turns", "enemy_turns", "sim_seconds", "wall_ms", "enemies", "arena", "kills_by", "bot_stats", "anomalies"]


func _fight_sim(sim: String) -> int:
	var jobs := _jobs(sim)
	var fights := int(opts.get("fights", 50))
	var shard := str(opts.get("shard", "0/1")).split("/")
	var shard_index := int(shard[0])
	var shard_count := int(shard[1])
	var base_seed := int(opts.get("seed", 1))
	var accuracy := float(opts.get("accuracy", 0.85))
	var out := FileAccess.open(str(opts.get("out", "/tmp/sim_%s.csv" % sim)), FileAccess.WRITE)
	out.store_line(",".join(HEADER))
	var runner = Fight.new(self)
	var done := 0
	var total := 0
	for i in jobs.size():
		if i % shard_count != shard_index:
			continue
		var job: Dictionary = jobs[i]
		for f in fights:
			var spec: Dictionary = job.spec.duplicate()
			var fight_seed := hash([base_seed, sim, job.subject, job.target, job.act, f]) & 0x7fffffff  # (the same matchup always gets the same seeds, whatever the filter)
			spec["seed"] = fight_seed
			var factory := func(main): 
				var bot = Bot.new(main)
				bot.accuracy = accuracy
				return bot
			var r: Dictionary = await runner.play(spec, factory)
			total += 1
			if r.is_empty():
				continue
			done += 1
			var kills := []
			for k in r.kills_by:
				kills.append("%s:%d" % [k, r.kills_by[k]])
			out.store_line(",".join([sim, _q(job.subject), _q(job.figure), job.get("group", "regular"), _q(job.target), str(job.act), str(f), str(fight_seed),
					str(r.win), str(r.timeout), str(r.figures_lost), str(r.figures_left), str(r.player_turns), str(r.enemy_turns), str(r.sim_seconds), str(r.wall_ms),
					str(r.enemy_count), _q(r.arena), _q("|".join(kills)), _q(JSON.stringify(runner.bot.stats)), _q("|".join(r.anomalies))]))
			out.flush()
		print("job %d/%d done: %s vs %s (act %d)" % [i + 1, jobs.size(), job.subject, job.target, job.act])
	out.close()
	print("sim %s: %d fights written" % [sim, done])
	return 0


func _q(text: String) -> String:
	if text.contains(",") or text.contains("\"") or text.contains("\n"):
		return "\"%s\"" % text.replace("\"", "\"\"")
	return text
