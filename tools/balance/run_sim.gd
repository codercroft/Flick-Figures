extends RefCounted
## Sim 4: whole runs (3 acts) played by the PlayerBot with a swappable policy (bot_policy.gd). Writes four CSV files next to
## --out: <base>_runs.csv (one row per run), _nodes.csv (one per node played), _picks.csv (figures / relics / upgrades taken)
## and _shop.csv (every shop offer and whether it was bought).
## Events are skipped (the node is left at once: the Trader and the minigames are not played), shops follow the policy, paths are
## chosen by the policy (random by default), chests, elite and boss rewards are resolved with the same RunManager calls reward.gd
## makes. Nothing here changes a rule of the game.

const POLICIES := {
	"rarity": "res://tools/balance/bot_policy.gd",
	"random": "res://tools/balance/policy_random.gd",
}

var w  # the sim_worker SceneTree
var run  # RunManager
var cfg
var policy
var runner
var _runs: FileAccess
var _nodes: FileAccess
var _picks: FileAccess
var _shop: FileAccess
var _run_id := 0
var _order := 0


func _init(worker) -> void:
	w = worker
	run = worker.run
	cfg = worker.cfg


func play_runs() -> int:
	var count := int(w.opts.get("runs", 10))
	var ascension := int(w.opts.get("ascension", 0))
	var shard := str(w.opts.get("shard", "0/1")).split("/")
	var base := str(w.opts.get("out", "/tmp/sim4.csv")).trim_suffix(".csv")
	var policy_name: String = w.opts.get("policy", "rarity")
	if not POLICIES.has(policy_name):
		printerr("unknown policy '%s' (known: %s)" % [policy_name, ", ".join(POLICIES.keys())])
		return 2
	_runs = _open(base, "runs", ["run", "seed", "ascension", "policy", "result", "act_reached", "nodes", "fights", "death_type", "death_target", "death_row",
			"money_earned", "money_spent", "money_end", "deck_end", "relics_end", "upgrade_tiers", "anomalies", "wall_ms"])
	_nodes = _open(base, "nodes", ["run", "ascension", "order", "act", "row", "node_type", "target", "arena", "win", "timeout", "figures_lost", "player_turns", "sim_seconds", "deck_size", "anomalies"])
	_picks = _open(base, "picks", ["run", "ascension", "result", "kind", "name"])
	_shop = _open(base, "shop", ["run", "ascension", "category", "item", "price", "bought"])
	runner = w.Fight.new(w)
	var base_seed := int(w.opts.get("seed", 1))
	for i in count:
		if i % int(shard[1]) != int(shard[0]):
			continue
		await _one_run(i, base_seed * 104729 + i * 7919 + ascension * 31, ascension, policy_name)
		print("run %d/%d done" % [i + 1, count])
	for f in [_runs, _nodes, _picks, _shop]:
		f.close()
	return 0


func _open(base: String, suffix: String, header: Array) -> FileAccess:
	var file := FileAccess.open("%s_%s.csv" % [base, suffix], FileAccess.WRITE)
	file.store_line(",".join(header))
	return file


func _q(text) -> String:
	var s := str(text)
	return "\"%s\"" % s.replace("\"", "\"\"") if (s.contains(",") or s.contains("\"") or s.contains("\n")) else s


func _one_run(index: int, run_seed: int, ascension: int, policy_name: String) -> void:
	var started := Time.get_ticks_msec()
	_run_id = index
	_order = 0
	seed(run_seed)
	run.start_new_run(ascension)
	policy = load(POLICIES[policy_name]).new(run, run_seed)
	var start_money: int = run.money
	var accuracy := float(w.opts.get("accuracy", 0.85))
	var factory := func(main):
		var bot = w.Bot.new(main)
		bot.accuracy = accuracy
		return bot
	var result := "loss"
	var death := {"type": "", "target": "", "row": -1}
	var fights := 0
	var anomalies: Array[String] = []
	var picks: Array = []
	var shop_rows: Array = []
	var nodes_played := 0
	for guard in 150:
		var options: Array = run.reachable_nodes()
		if options.is_empty():
			break
		run.enter_node(policy.pick_node(options))
		var node = run.node
		var type_name: String = MapNode.Type.keys()[node.type]
		nodes_played += 1
		var act: int = run.act + 1
		match node.type:
			MapNode.Type.COMBAT, MapNode.Type.ELITE, MapNode.Type.BOSS:
				var r: Dictionary = await runner.play_prepared(factory)
				fights += 1
				_order += 1
				if r.is_empty():
					anomalies.append("fight returned nothing")
					break
				for a in r.anomalies:
					anomalies.append(a)
				if r.timeout == 1:
					anomalies.append("timeout in %s" % r.encounter)
				_nodes.store_line(",".join([str(index), str(ascension), str(_order), str(act), str(node.column), type_name, _q(r.encounter), _q(r.arena),
						str(r.win), str(r.timeout), str(r.figures_lost), str(r.player_turns), str(r.sim_seconds), str(r.deck_size), _q("|".join(r.anomalies))]))
				if r.win == 0:
					death = {"type": type_name, "target": r.encounter, "row": node.column}
					break
				if node.type == MapNode.Type.BOSS and run.is_last_act():
					result = "win"
					break
				_resolve_rewards(picks)
			MapNode.Type.SHOP:
				_shop_visit(shop_rows)
				run.finish_node()
			MapNode.Type.TREASURE:
				_resolve_rewards(picks)
			_:  # events (the Trader and the minigames) are not played
				run.finish_node()
	var act_reached: int = mini(run.act + 1, cfg.acts)
	var deck_names: Array = []
	var tiers := 0
	for slot in run.deck.size():
		deck_names.append(run.deck[slot].display_name + ("+%d" % run.deck_upgrade[slot].y if run.deck_upgrade[slot].y > 0 else ""))
		tiers += run.deck_upgrade[slot].y
	var relic_names: Array = run.relics.map(func(r): return r.display_name)
	_runs.store_line(",".join([str(index), str(run_seed), str(ascension), policy_name, result, str(act_reached), str(nodes_played), str(fights), death.type, _q(death.target),
			str(death.row), str(run.money + run.money_spent - start_money), str(run.money_spent), str(run.money), _q("|".join(deck_names)), _q("|".join(relic_names)),
			str(tiers), _q("|".join(anomalies.slice(0, 3))), str(Time.get_ticks_msec() - started)]))
	for pick in picks:
		_picks.store_line(",".join([str(index), str(ascension), result, pick.kind, _q(pick.name)]))
	for row in shop_rows:
		_shop.store_line(",".join([str(index), str(ascension), row.category, _q(row.item), str(row.price), str(row.bought)]))
	for f in [_runs, _nodes, _picks, _shop]:
		f.flush()


# --- Rewards (the same RunManager calls reward.gd makes) -----------------------------------------------------------------

func _resolve_rewards(picks: Array) -> void:
	var steps: Array = run.reward_steps.duplicate()
	for step in steps:
		match step.kind:
			"figures":
				var offers: Array = run.offer_rewards(step.get("boss", false))
				var choice: Dictionary = policy.choose_figure(offers)
				if choice.is_empty():
					continue
				if choice.mode == "upgrade":
					if run.take_upgrade(choice.slot, choice.path):
						picks.append({"kind": "upgrade", "name": "%s (reward duplicate)" % run.deck[choice.slot].display_name})
				else:
					run.replace_figure(choice.slot, choice.figure)
					picks.append({"kind": "figure", "name": choice.figure.display_name})
			"relics":
				var choices: Array = run.random_new_relics(int(step.get("count", 3))) if step.get("elite", false) \
						else run.random_boss_relics(cfg.rewards.boss_relic_choices)
				_take_relic(policy.choose_relic(choices), picks)
			"relic":
				_take_relic(policy.choose_relic(run.random_new_relics(1)), picks)
			"treasure":
				if not run.random_new_relics(1).is_empty():
					var found: Array = [run.random_rare_relic()] if run.act == 0 else run.random_new_relics(1)
					_take_relic(policy.choose_relic(found.filter(func(r): return r != null)), picks)
				else:
					var item = run.random_equipment()
					if item != null:
						_take_equipment(item, picks)
			"power":
				var power = run.random_power()
				if power != null and not run.add_power(power):
					var slot: int = policy.choose_power_replace(power)
					if slot >= 0:
						run.powers[slot] = power
			"equipment":
				var item = run.random_equipment()
				if item != null:
					_take_equipment(item, picks)
			"finish":
				var finish = run.random_finish()
				var slot: int = policy.choose_finish_slot(finish) if finish != null else -1
				if slot >= 0:
					run.set_finish(slot, finish)
					picks.append({"kind": "finish", "name": finish.display_name})
			"upgrade":
				var copies: Array = []
				if step.get("only_figure", null) != null:
					copies = run.upgradable_copies(step.only_figure)
				var pick: Dictionary = policy.choose_upgrade(copies)
				if not pick.is_empty() and run.take_upgrade(pick.slot, pick.path):
					picks.append({"kind": "upgrade", "name": "%s %s" % [run.deck[pick.slot].display_name, run.tree_for(run.deck[pick.slot]).path_name(pick.path)]})
	run.finish_rewards()


func _take_relic(relic, picks: Array) -> void:
	if relic != null and run.add_relic(relic):
		picks.append({"kind": "relic", "name": relic.display_name})


func _take_equipment(item, picks: Array) -> void:
	run.add_equipment(item)
	var slot: int = policy.choose_equipment_slot(item)
	if slot >= 0:
		run.equip(item, slot)
		picks.append({"kind": "equipment", "name": item.display_name})


# --- Shops ---------------------------------------------------------------------------------------------------------------

func _shop_visit(rows: Array) -> void:
	var offers: Array = run.shop_offers
	var bought: Array = []
	for guard in 30:
		var action: Dictionary = policy.next_purchase(offers)
		if action.is_empty():
			break
		var offer: ShopOffer = action.offer
		if not run.spend(offer.price):
			break
		if action.mode == "upgrade":
			run.take_upgrade(action.slot, action.path)
			offer.sold = true
		else:
			offer.buy(action.slot)
		bought.append(offer)
	for offer in offers:
		rows.append({"category": policy.shop_category(offer), "item": offer.title, "price": offer.price, "bought": 1 if bought.has(offer) else 0})
