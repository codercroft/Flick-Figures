extends RefCounted
## Sets up and plays ONE combat for the balance sims (tools only: nothing in the game uses this file).
## It drives the real combat scene (main.tscn) through RunManager exactly like a run does, but never goes through the
## map, the reward scene or the main menu. run_sims.py points user:// at a temporary folder, so the saves, unlocks and
## run history RunManager writes while a combat ends are throw-away (the worker refuses to start otherwise).

const MAIN_SCENE := "res://scenes/main.tscn"
const GAME_OVER := 4  # Main.State.GAME_OVER

var tree: SceneTree
var run  # the RunManager autoload
var main: Node
var bot
var _kills_by: Dictionary = {}  # enemy display name -> player figures it knocked off (credited to the last flicker)
var _anomalies: Array[String] = []
var _watching: Dictionary = {}
var _dead_frames := 0


func _init(scene_tree: SceneTree) -> void:
	tree = scene_tree
	run = tree.root.get_node("RunManager")


## One deck slot for a spec: the figure plus its optional finish, equipment and upgrade state (path, tier).
static func slot(figure: FigureData, upgrade := Vector2i(-1, 0), finish: FinishData = null, equipment: EquipmentData = null) -> Dictionary:
	return {"figure": figure, "upgrade": upgrade, "finish": finish, "equipment": equipment}


## Fills RunManager like the map would right before a node is entered (spec keys: deck, kind "encounter" | "elite" | "boss",
## encounter, boss, act 1-3, ascension, relics, powers, seed). Returns nothing; main.tscn then reads it.
func prepare(spec: Dictionary) -> void:
	seed(int(spec.get("seed", 1)))
	var cfg = run.config
	run.ascension = int(spec.get("ascension", 0))
	run.act = int(spec.get("act", 1)) - 1
	run.in_second_boss = false
	run.deck.clear()
	run.deck_equipment.clear()
	run.deck_finish.clear()
	run.deck_upgrade.clear()
	for entry in spec.deck:
		run.deck.append(entry.figure)
		run.deck_equipment.append(entry.get("equipment", null))
		run.deck_finish.append(entry.get("finish", null))
		run.deck_upgrade.append(entry.get("upgrade", Vector2i(-1, 0)))
	run.relics.clear()
	for relic in spec.get("relics", []):
		run.relics.append(relic)
	run.powers.clear()
	var powers: Array = spec.get("powers", [])
	for i in cfg.power_slots:
		run.powers.append(powers[i] if i < powers.size() else null)
	run.enemy_relics.clear()
	run.minigame_penalty = false
	run.first_combat_played = true
	run.sandbox_encounter = null
	run.boss = null
	var node := MapNode.new()
	node.column = int(spec.get("column", 2))
	match spec.kind:
		"boss":
			node.type = MapNode.Type.BOSS
			run.boss = spec.boss
		"elite":
			node.type = MapNode.Type.ELITE
			run.sandbox_encounter = spec.encounter
		_:
			node.type = MapNode.Type.COMBAT
			run.sandbox_encounter = spec.encounter
	run.node = node
	run._build_lineup()
	for relic in spec.get("enemy_relics", []):
		if not run.enemy_relics.has(relic):
			run.enemy_relics.append(relic)


## Starts the combat scene for the prepared state. `reward_delay` is huge so the game never leaves for the reward scene.
func start_combat() -> void:
	main = load(MAIN_SCENE).instantiate()
	main.reward_delay = 1.0e9
	main.restart_tap_delay = 1.0e9
	_kills_by.clear()
	_anomalies.clear()
	_watching.clear()
	tree.root.add_child(main)
	tree.current_scene = main
	main.ai.think_budget_ms = 100000000  # (the AI stops thinking after 700 real milliseconds: that would make a result depend on the machine's speed)
	tree.node_added.connect(_on_node_added)
	for node in tree.get_nodes_in_group("figures"):
		_watch(node)


func _on_node_added(node: Node) -> void:
	if node is Figure:
		_watch.call_deferred(node)


func _watch(node) -> void:
	if not (node is Figure) or _watching.has(node.get_instance_id()) or not is_instance_valid(main) or not main.is_ancestor_of(node):
		return
	if node.fell_off.is_connected(_on_fell):
		return
	_watching[node.get_instance_id()] = true
	node.fell_off.connect(_on_fell)


## A figure fell off the table: credit the figure that made the last flick (the game's own kill attribution).
func _on_fell(fallen) -> void:
	if not is_instance_valid(fallen) or not is_instance_valid(main) or fallen.team != Figure.Team.PLAYER:
		return
	var killer = main._flicker
	var name := "unknown"
	if is_instance_valid(killer) and killer.team == Figure.Team.ENEMY:
		name = killer.data.display_name
	elif is_instance_valid(killer):
		name = "(own side)"
	_kills_by[name] = int(_kills_by.get(name, 0)) + 1


## Ends the combat scene and clears the signal hook. Call after every fight.
func finish_combat() -> void:
	if tree.node_added.is_connected(_on_node_added):
		tree.node_added.disconnect(_on_node_added)
	if is_instance_valid(main):
		main.free()  # (now, not at the end of the frame: the next fight starts in the same frame)
	main = null


## Plays the prepared combat with the bot on the player side until it ends. Returns the stats row (a Dictionary).
## `max_sim_seconds` (300 s of game time, about 55 turns: real fights end in 10-30) guards against a fight that never ends (a "stalemate": counted as a loss and reported).
func play(spec: Dictionary, bot_factory: Callable, max_sim_seconds := 300.0) -> Dictionary:
	prepare(spec)
	return await play_prepared(bot_factory, max_sim_seconds)


## Same, for a combat RunManager is already set up for (a full run enters its nodes itself).
func play_prepared(bot_factory: Callable, max_sim_seconds := 300.0) -> Dictionary:
	var started := Time.get_ticks_msec()
	var deck_size: int = run.deck.size()
	var enemy_count: int = run.enemies.size()
	start_combat()
	bot = bot_factory.call(main)
	var frames := 0
	_dead_frames = 0
	var max_frames := int(max_sim_seconds * 60.0)
	while is_instance_valid(main) and main._state != GAME_OVER and frames < max_frames:
		await tree.physics_frame
		frames += 1
		if main._state == 0 and not bot.busy:
			bot.take_turn()  # a coroutine: it runs on its own, `busy` is set until it finishes
		if frames % 120 == 0:
			_check_anomalies()
		# The game never ends a combat on its own when the LAST player figure falls after its last check: a softlock.
		if main._state == 0 and main._players.filter(func(p): return is_instance_valid(p) and not p.knocked_off).is_empty():
			_dead_frames += 1
			if _dead_frames > 180:
				_note("softlock: no player figure is left, but the combat never declared the loss (it waits for a flick nobody can make)")
				break
		else:
			_dead_frames = 0
	var timed_out := frames >= max_frames
	if timed_out and is_instance_valid(main):
		_note("timeout: state %d, bonus figure %s, power slot %d, bot busy %s (%s), %d player / %d enemy figures" % [main._state, str(main._bonus_figure != null), main._power_slot, str(bot.busy), bot.where, main._players.size(), main._enemies.size()])
	var result := {}
	if is_instance_valid(main):
		var won: bool = main._state == GAME_OVER and not timed_out and \
				(main._fat_man.defeated() if main._fat_man != null else main._enemies.is_empty())
		if _dead_frames > 180:
			won = false
		var alive := 0
		for p in main._players:
			if is_instance_valid(p) and not p.knocked_off:
				alive += 1
		result = {
			"win": 1 if won else 0,
			"timeout": 1 if timed_out else 0,
			"player_turns": main._player_turns_started,
			"enemy_turns": main._enemy_turns_taken,
			"figures_lost": main._figures_lost,
			"figures_left": alive,
			"deck_size": deck_size,
			"enemy_count": enemy_count,
			"sim_seconds": snappedf(frames / 60.0, 0.1),
			"wall_ms": Time.get_ticks_msec() - started,
			"kills_by": _kills_by.duplicate(),
			"anomalies": _anomalies.duplicate(),
			"encounter": _target_name(),
			"arena": run.arena.display_name if run.arena != null else "",
		}
	finish_combat()
	return result


## What the combat is against: the boss, the named encounter, or plain Grunts (the first combat of a run).
func _target_name() -> String:
	if run.node != null and run.node.type == MapNode.Type.BOSS and run.boss != null:
		return run.boss.display_name
	return run.encounter_name if run.encounter_name != "" else "Grunts only"


## Figures that are NaN, or far outside the table, are reported (the game's own knock-off should have caught them).
func _check_anomalies() -> void:
	if not is_instance_valid(main):
		return
	var table: Rect2 = main.board.get_table_rect()
	for f in main.get_all_figures():
		var p: Vector2 = f.global_position
		if is_nan(p.x) or is_nan(p.y):
			_note("NaN position: %s" % f.data.display_name)
		elif not table.grow(400.0).has_point(p):
			_note("%s alive, far outside the table at (%d, %d)" % [f.data.display_name, int(p.x), int(p.y)])


func _note(text: String) -> void:
	if _anomalies.size() < 5 and not _anomalies.has(text):
		_anomalies.append(text)
