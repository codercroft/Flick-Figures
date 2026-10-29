extends Node
## Autoload: holds the state of the current run (deck, which combat, which boss) and builds
## each combat's enemy lineup. Scenes read from it and call its functions; it never touches scenes.

## The run rules. Loaded in _ready(), NOT preloaded: a preload here makes RunManager's script wait for
## run_config.tres, which loads the shop/relic/power scripts, which read RunManager.config. In an exported
## build that cycle fails ("Could not resolve external class member config"), the shop's item types
## don't load and the shop comes up empty.
var config: RunConfig

var deck: Array[FigureData] = []
## The equipment item on each deck figure (same slots as `deck`; null = none).
var deck_equipment: Array[EquipmentData] = []
## Equipment the player holds but has not attached to a figure yet.
var equipment_inventory: Array[EquipmentData] = []
## The toy finish and the figure-specific upgrade on each deck figure (same slots as `deck`).
## They belong to the figure: replacing the figure removes them.
var deck_finish: Array[FinishData] = []
var deck_upgrade: Array[UpgradeData] = []
## Which act the run is in (0 = act 1). A run is config.acts acts, each with its own map and boss.
var act := 0
## The boss of each act (different bosses, picked when the run starts).
var act_bosses: Array[BossData] = []
## This act's boss.
var boss: BossData
## This act's branching map.
var map: ActMap
## The map node last finished (-1 = still at the start of the act).
var current_node := -1
## The map node being played right now (combat, shop...), or null while on the map.
var node: MapNode
## The enemies for the current combat, and which of them are "elite" (stronger).
var enemies: Array[FigureData] = []
var enemy_elite: Array[bool] = []
## Named encounter (elite fights): its name, shown at the start of combat, and each enemy's own
## stat boosts (parallel to `enemies`; {} = none).
var encounter_name := ""
var enemy_boosts: Array[Dictionary] = []
## Where each enemy starts in board space (parallel to `enemies`; Vector2.INF = the default spread-out row).
var enemy_positions: Array[Vector2] = []
## The arena the current encounter asks for (null = random), and the regular encounters used this run.
var encounter_arena: ArenaData
var used_encounters: Array[EncounterData] = []
## Finishes, equipment and upgrades each enemy carries (parallel to `enemies`): {finish, equipment, upgrade}.
var enemy_gear: Array[Dictionary] = []
## What the player is being offered after a win: a list of steps like {"kind": "figures"}.
var reward_steps: Array[Dictionary] = []
## How many flicks the enemy side takes each turn in the current combat.
var enemy_flicks_per_turn := 1
## True when the enemies start in one straight row (The Wall).
var enemies_in_row := false
## The arena layout for the current combat.
var arena: ArenaData
var money := 0
## What the last won combat paid: {figures, base, bonus, total}.
var last_income := {"figures": 0, "base": 0, "bonus": 0, "total": 0}
var shop_offers: Array[ShopOffer] = []
## The relics held this run (passive effects; never the same relic twice).
var relics: Array[RelicData] = []
## The Main node while a combat is running (null otherwise): relic effects read the board from it.
var combat: Node
## Short messages from relics after the last won combat (shown on the reward screen).
var relic_notes: Array[String] = []
## The player's power slots (null = empty). They persist across combats until used.
var powers: Array[PowerData] = []


func _ready() -> void:
	config = load("res://resources/run_config.tres")
	start_new_run()


func start_new_run() -> void:
	deck.clear()
	deck_equipment.clear()
	deck_finish.clear()
	deck_upgrade.clear()
	equipment_inventory.clear()
	for i in config.deck_size:
		deck.append(config.starting_figure)
		deck_equipment.append(null)
		deck_finish.append(null)
		deck_upgrade.append(null)
	if config.start_with_equipment:
		var items := config.equipment_pool.duplicate()
		items.shuffle()
		for i in mini(config.starting_equipment_count, items.size()):
			equipment_inventory.append(items[i])
	money = config.starting_money
	last_income = {"figures": 0, "base": 0, "bonus": 0, "total": 0}
	shop_offers.clear()
	reward_steps.clear()
	used_encounters.clear()
	_reset_powers()
	_reset_relics()
	act = 0
	act_bosses = config.registry.random_bosses(config.acts)
	_start_act()


func _reset_relics() -> void:
	relics.clear()
	relic_notes.clear()
	if config.start_with_relics:
		for i in config.starting_relic_count:
			var relic := random_new_relic()
			if relic != null:
				add_relic(relic)


## Adds a relic to the run. Returns false (and does nothing) if it is already held.
func add_relic(relic: RelicData) -> bool:
	if relic == null or relics.has(relic):
		return false
	relics.append(relic)
	if relic.effect != null:
		relic.effect.on_acquired(self)
	return true


## A relic from the pool that the run does not hold yet (never a Boss relic), or null.
func random_new_relic() -> RelicData:
	var found := random_new_relics(1)
	return found[0] if not found.is_empty() else null


## One more deck slot, filled with the starting figure (Extra Pocket).
func add_deck_slot() -> void:
	deck.append(config.starting_figure)
	deck_equipment.append(null)
	deck_finish.append(null)
	deck_upgrade.append(null)


func random_power() -> PowerData:
	return config.power_pool.pick_random() if not config.power_pool.is_empty() else null


# --- Relic queries: every held relic gets a say -------------------------------

func _relic_product(method: StringName, args := []) -> float:
	var result := 1.0
	for relic in relics:
		if relic.effect != null:
			result *= relic.effect.callv(method, args)
	return result


func relic_explosion_multiplier() -> float:
	return _relic_product(&"get_explosion_radius_multiplier")


func relic_flick_multiplier(main, figure: Figure) -> float:
	return _relic_product(&"get_flick_power_multiplier", [main, figure])


func relic_player_damping() -> float:
	return _relic_product(&"get_player_damping_multiplier")


## Shared strength of every explosion's push (RunConfig.explosion_force_multiplier).
func explosion_force_multiplier() -> float:
	return config.explosion_force_multiplier if config != null else 1.0


func relic_knockback_taken(figure: Figure, source: Figure) -> float:
	return _relic_product(&"get_knockback_taken_multiplier", [figure, source])


func relic_pull_multiplier() -> float:
	return _relic_product(&"get_pull_multiplier")


func relic_enables_reload() -> bool:
	for relic in relics:
		if relic.effect != null and relic.effect.enables_reload():
			return true
	return false


func relic_shows_aim_bounce() -> bool:
	for relic in relics:
		if relic.effect != null and relic.effect.shows_aim_bounce():
			return true
	return false


## True if a relic saves a player's figure that was about to be knocked off.
func relic_saves_figure(main, figure: Figure) -> bool:
	for relic in relics:
		if relic.effect != null and relic.effect.on_player_figure_falling(main, figure):
			return true
	return false


## Tells the relics a combat was won; their messages go to relic_notes.
func notify_combat_won(info: Dictionary) -> void:
	for relic in relics:
		if relic.effect != null:
			var note := relic.effect.on_combat_won(self, info)
			if note != "":
				relic_notes.append(note)


func _reset_powers() -> void:
	powers.clear()
	for i in config.power_slots:
		powers.append(null)
	if config.start_with_powers:
		var pool := config.power_pool.duplicate()
		pool.shuffle()
		for i in mini(config.starting_power_count, pool.size()):
			add_power(pool[i])


## Puts a power in the first empty slot. Returns false if all slots are full.
func add_power(power: PowerData) -> bool:
	for i in powers.size():
		if powers[i] == null:
			powers[i] = power
			return true
	return false


## Uses up the power in a slot.
func use_power(slot: int) -> void:
	if slot >= 0 and slot < powers.size():
		powers[slot] = null


# --- Acts, the map and nodes ---------------------------------------------------

func _start_act() -> void:
	boss = act_bosses[act] if act < act_bosses.size() else config.registry.random_boss()
	map = ActMap.generate(config.map)
	current_node = -1
	node = null
	enemies.clear()
	enemy_elite.clear()
	arena = null


func is_last_act() -> bool:
	return act >= config.acts - 1


## The map nodes the player can go to now: the first column at the start of an act, otherwise
## the next steps from the last finished node.
func reachable_nodes() -> Array[int]:
	if current_node == -1:
		return map.column_ids(0)
	return map.nodes[current_node].next.duplicate()


func is_reachable(id: int) -> bool:
	return reachable_nodes().has(id)


## Goes to a map node. Returns false if it can't be reached from here. Combat, elite and boss
## nodes build their enemy lineup; shops roll their stock. The caller changes the scene.
func enter_node(id: int) -> bool:
	if not is_reachable(id):
		return false
	node = map.nodes[id]
	match node.type:
		MapNode.Type.COMBAT, MapNode.Type.ELITE, MapNode.Type.BOSS:
			_build_lineup()
		MapNode.Type.SHOP:
			shop_offers = ShopConfig.make_offers_for(config.shop, config.registry)
		MapNode.Type.TREASURE:
			reward_steps = [{"kind": "treasure"}]
	return true


## The node has been dealt with (fought, shopped, looted): you are now standing on it.
func finish_node() -> void:
	if node != null:
		node.visited = true
		current_node = node.id
		node = null


## Call when the player wins a combat. Builds the reward steps. Returns true if that was the
## last act's boss (the run is won); the caller then shows the end screen instead of rewards.
func combat_won() -> bool:
	if node.type == MapNode.Type.BOSS and is_last_act():
		return true
	build_rewards()
	return false


## What a won combat offers, by node type (RewardConfig has every chance and amount). Chance drops are
## rolled here and marked "lucky" so the reward screen can celebrate them. See reward.gd for the steps.
func build_rewards() -> void:
	var rewards := config.rewards
	reward_steps.clear()
	match node.type:
		MapNode.Type.ELITE:
			for i in rewards.elite_guaranteed_relics:
				reward_steps.append({"kind": "relic"})
			reward_steps.append({"kind": "figures"})
			_add_bonus_items()
			_roll_drop("power", rewards.elite_power_chance)
			_roll_drop("equipment", rewards.elite_equipment_chance)
			_roll_drop("finish", rewards.elite_finish_chance)
		MapNode.Type.BOSS:
			reward_steps.append({"kind": "relics"})
			reward_steps.append({"kind": "upgrade_item"})
			reward_steps.append({"kind": "figures", "boss": true})
			# One guaranteed extra: a power or an equipment item.
			reward_steps.append({"kind": "power" if randf() < rewards.boss_power_chance else "equipment"})
		_:
			reward_steps.append({"kind": "figures"})
			_add_bonus_items()
			_roll_drop("power", rewards.combat_power_chance)
			_roll_drop("equipment", rewards.combat_equipment_chance)


## The act's bonus rewards after the figure draft: each a random power, equipment item or upgrade.
func _add_bonus_items() -> void:
	for i in config.rewards.bonus_items(act):
		reward_steps.append({"kind": ["power", "equipment", "upgrade_item"].pick_random()})


## Adds a "lucky" drop step with the given chance.
func _roll_drop(kind: String, chance: float) -> void:
	if randf() < chance:
		reward_steps.append({"kind": kind, "lucky": true})


## Called when the reward screens are done. After a boss the run moves on to the next act.
func finish_rewards() -> void:
	reward_steps.clear()
	if node != null and node.type == MapNode.Type.BOSS:
		act += 1
		_start_act()
	else:
		finish_node()


## Enemy stat multipliers for the enemy at `index` of the current lineup: {accuracy, power, mass}.
func enemy_scale(index := -1) -> Dictionary:
	var is_boss := node != null and node.type == MapNode.Type.BOSS
	var is_elite := index >= 0 and index < enemy_elite.size() and enemy_elite[index]
	var scale := config.difficulty.scale_for(act, is_boss, is_elite)
	# An encounter's own boosts for this enemy stack on top of the act's multipliers.
	if index >= 0 and index < enemy_boosts.size() and not enemy_boosts[index].is_empty():
		var boost := enemy_boosts[index]
		scale.accuracy *= boost.accuracy
		scale.power *= boost.power
		scale.mass *= boost.mass
		scale["bounce"] = boost.bounce
		scale["ability"] = boost.ability
	return scale


# --- Reward helpers ----------------------------------------------------------

## `count` different relics the run doesn't hold yet, for chests, elites and the shop: the rarity of
## each is rolled with RewardConfig.relic_weights (mostly Common/Uncommon, rarely Rare), never Boss.
func random_new_relics(count: int) -> Array[RelicData]:
	var picked: Array[RelicData] = []
	var weights := config.rewards.relic_weights
	for i in count:
		var by_rarity: Array = []
		var total := 0.0
		for rarity in 3:
			var options := _unheld_relics([rarity], picked)
			by_rarity.append(options)
			if not options.is_empty():
				total += weights[rarity]
		var roll := randf() * total
		for rarity in 3:
			if by_rarity[rarity].is_empty():
				continue
			roll -= weights[rarity]
			if roll <= 0.0 or rarity == 2:
				picked.append(by_rarity[rarity].pick_random())
				break
	return picked


## The act 1 chest: an unheld Rare relic (any other unheld relic if every Rare one is held).
func random_rare_relic() -> RelicData:
	var rare := _unheld_relics([RelicData.Rarity.RARE], [])
	if not rare.is_empty():
		return rare.pick_random()
	var other := random_new_relics(1)
	return other[0] if not other.is_empty() else null


## Boss reward: `count` relics, taken from the Boss and Rare ones first (then any other unheld relic
## if there are not enough).
func random_boss_relics(count: int) -> Array[RelicData]:
	var top := _unheld_relics([RelicData.Rarity.BOSS, RelicData.Rarity.RARE], [])
	top.shuffle()
	var picked: Array[RelicData] = top.slice(0, count)
	if picked.size() < count:
		var rest := _unheld_relics([RelicData.Rarity.COMMON, RelicData.Rarity.UNCOMMON], [])
		rest.shuffle()
		picked.append_array(rest.slice(0, count - picked.size()))
	return picked


## Pool relics of the given rarities that the run doesn't hold and `taken` doesn't contain.
func _unheld_relics(rarities: Array, taken: Array) -> Array[RelicData]:
	var found: Array[RelicData] = []
	for relic in config.relic_pool:
		if rarities.has(relic.rarity) and not relics.has(relic) and not taken.has(relic):
			found.append(relic)
	return found


func random_equipment() -> EquipmentData:
	return config.equipment_pool.pick_random() if not config.equipment_pool.is_empty() else null


func random_finish() -> FinishData:
	return config.finish_pool.pick_random() if not config.finish_pool.is_empty() else null


## For the boss reward: a figure-specific upgrade that one of your figures can take (chance from
## RewardConfig), otherwise a finish. Returns an UpgradeData, a FinishData or null.
func random_upgrade_item() -> Resource:
	if randf() < config.rewards.boss_specific_upgrade_chance:
		var options: Array[UpgradeData] = []
		for slot in deck.size():
			for upgrade in upgrades_for(deck[slot]):
				if deck_upgrade[slot] != upgrade and not options.has(upgrade):
					options.append(upgrade)
		if not options.is_empty():
			return options.pick_random()
	return random_finish()


func has_free_power_slot() -> bool:
	return powers.has(null)


## The figures a figure reward offers: different from each other, weighted by rarity for this act
## (act 1 is mostly common figures, later acts lean rarer).
func offer_rewards(boss := false) -> Array[FigureData]:
	var count := config.rewards.boss_figure_choices if boss else config.rewards.figure_choices(act)
	for relic in relics:
		if relic.effect != null:
			count += relic.effect.get_reward_choice_bonus()
	if boss:
		# Boss rewards: Rare figures you don't own (Uncommon, then Common, only if there are not enough).
		var owned: Array[FigureData] = []
		owned.append_array(deck)
		return config.registry.random_draftable_top(count, owned)
	return draft_figures(count)


func draft_figures(count: int) -> Array[FigureData]:
	return config.registry.random_draftable_weighted(count, config.rewards.rarity_weights(act))


## Puts a new figure in a deck slot. Equipment the old figure held goes back to the inventory.
func replace_figure(slot: int, new_figure: FigureData) -> void:
	if deck_equipment[slot] != null:
		equipment_inventory.append(deck_equipment[slot])
		deck_equipment[slot] = null
	deck_finish[slot] = null
	deck_upgrade[slot] = null
	deck[slot] = new_figure


## The figure-specific upgrades in the pool that fit this figure.
func upgrades_for(figure: FigureData) -> Array[UpgradeData]:
	var found: Array[UpgradeData] = []
	for upgrade in config.upgrade_pool:
		if upgrade.figure == figure:
			found.append(upgrade)
	return found


## Puts a toy finish on the figure in `slot` (null removes it). It replaces any earlier finish.
func set_finish(slot: int, finish: FinishData) -> void:
	deck_finish[slot] = finish


## Puts a figure-specific upgrade on the figure in `slot` (null removes it). Returns false if the
## upgrade is not for that figure.
func set_upgrade(slot: int, upgrade: UpgradeData) -> bool:
	if upgrade != null and upgrade.figure != deck[slot]:
		return false
	deck_upgrade[slot] = upgrade
	return true


## Attaches an inventory item to the figure in `slot`. If that figure already holds one, the old
## item goes back to the inventory. Returns false if the item is not in the inventory.
func equip(item: EquipmentData, slot: int) -> bool:
	var index := equipment_inventory.find(item)
	if index == -1 or slot < 0 or slot >= deck.size():
		return false
	equipment_inventory.remove_at(index)
	if deck_equipment[slot] != null:
		equipment_inventory.append(deck_equipment[slot])
	deck_equipment[slot] = item
	return true


## Adds an item to the inventory (rewards and shops can call this).
func add_equipment(item: EquipmentData) -> void:
	equipment_inventory.append(item)


## Pays for a won combat: income_per_figure for each figure still on the table, plus each figure's
## own income_bonus (Cha-ching), plus `equipment_bonus` (Coin Purse). Call it before combat_won().
func award_income(figures_on_table: Array[FigureData], equipment_bonus := 0) -> void:
	var base := figures_on_table.size() * config.income_per_figure
	var bonus := equipment_bonus
	for figure in figures_on_table:
		bonus += figure.income_bonus
	for relic in relics:
		if relic.effect != null:
			bonus += relic.effect.get_income_bonus()
	if node != null and node.type == MapNode.Type.ELITE:
		bonus += config.rewards.elite_bonus_money
	elif node != null and node.type == MapNode.Type.BOSS:
		bonus += config.rewards.boss_bonus_money
	relic_notes.clear()
	last_income = {"figures": figures_on_table.size(), "base": base, "bonus": bonus, "total": base + bonus}
	money += base + bonus


func income_text() -> String:
	var text := "$%d earned, you have $%d total" % [last_income.total, money]
	for note in relic_notes:
		text += "\n" + note
	return text


func spend(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	return true


func progress_text() -> String:
	var where := "Act %d of %d" % [act + 1, config.acts]
	if node == null:
		return where
	if node.type == MapNode.Type.BOSS:
		return "%s | Boss: %s" % [where, boss.display_name]
	return "%s | %s" % [where, MapNode.type_name(node.type)]


func run_over_text(won: bool) -> String:
	var result := ""
	if won:
		result = "Run complete!\nYou beat all %d acts" % config.acts
	elif node != null and node.type == MapNode.Type.BOSS:
		result = "Run over\nAct %d: beaten by %s" % [act + 1, boss.display_name]
	else:
		result = "Run over\nAct %d: defeated at a %s" % [act + 1, MapNode.type_name(node.type).to_lower() if node != null else "combat"]
	return result + "\nTap to start a new run"


## Builds the enemies for the current node. Within an act the lineup ramps from all grunts at the
## first column to all non-grunts at the last; elites have stronger figures and an extra flick.
func _build_lineup() -> void:
	enemies.clear()
	enemy_elite.clear()
	enemy_boosts.clear()
	enemy_positions.clear()
	enemy_gear.clear()
	encounter_name = ""
	encounter_arena = null
	var registry := config.registry
	var difficulty := config.difficulty
	var encounter: EncounterData = null
	if node.type == MapNode.Type.ELITE:
		encounter = _pick_encounter()
	elif node.type == MapNode.Type.COMBAT:
		encounter = _pick_regular_encounter()
	if encounter != null:
		_build_encounter(encounter)
	elif node.type == MapNode.Type.BOSS:
		enemies.append_array(boss.enemies)
		for i in enemies.size():
			enemy_elite.append(false)
		enemy_flicks_per_turn = boss.enemy_flicks_per_turn
		enemies_in_row = boss.straight_row
	else:
		var count := difficulty.enemy_count(act)
		var progress := float(node.column) / maxf(map.columns - 1, 1)
		var non_grunts := clampi(roundi(count * progress), 0, count)
		if node.type == MapNode.Type.ELITE:
			non_grunts = maxi(non_grunts, difficulty.elite_figures_max)
		for i in count - non_grunts:
			enemies.append(registry.random_grunt())
		var specials := registry.random_non_grunts(non_grunts)
		enemies.append_array(specials)
		for i in enemies.size():
			enemy_elite.append(false)
		enemy_flicks_per_turn = difficulty.flicks_per_turn(act)
		enemies_in_row = false
		if node.type == MapNode.Type.ELITE:
			# 1-2 of the non-grunts (the last entries) become elite.
			var elite_count := mini(randi_range(difficulty.elite_figures_min, difficulty.elite_figures_max), specials.size())
			for i in elite_count:
				enemy_elite[enemies.size() - 1 - i] = true
			enemy_flicks_per_turn += difficulty.elite_extra_flicks
	while enemy_boosts.size() < enemies.size():
		enemy_boosts.append({})
	while enemy_positions.size() < enemies.size():
		enemy_positions.append(Vector2.INF)
	# Later acts: enemies may carry finishes, equipment and upgrades (elites and bosses roll a step higher).
	var tougher := node.type == MapNode.Type.ELITE or node.type == MapNode.Type.BOSS
	for figure in enemies:
		enemy_gear.append(_roll_enemy_gear(figure, tougher))
	_pick_arena()


## Rolls what one enemy carries. Never economy or player-only equipment, and only gear that does
## something for this figure (GearRules), preferring gear that fits its role.
func _roll_enemy_gear(figure: FigureData, tougher: bool) -> Dictionary:
	var gear := {"finish": null, "equipment": null, "upgrade": null}
	if config.enemy_gear == null:
		return gear
	var rates := config.enemy_gear.rates(act, tougher)
	if randf() < rates.finish:
		gear.finish = GearRules.pick(config.finish_pool, figure)
	if randf() < rates.equipment:
		var items: Array[EquipmentData] = []
		for item in config.equipment_pool:
			if not item.economy and not item.player_only:
				items.append(item)
		gear.equipment = GearRules.pick(items, figure)
	if randf() < rates.upgrade:
		var upgrades := upgrades_for(figure)  # only upgrades made for this exact figure
		if not upgrades.is_empty():
			gear.upgrade = upgrades.pick_random()
	return gear


## A named elite encounter that can appear in this act (random), or null if there is none.
func _pick_encounter() -> EncounterData:
	var choices: Array[EncounterData] = []
	for encounter in config.elite_encounters:
		if encounter.available_in(act):
			choices.append(encounter)
	return choices.pick_random() if not choices.is_empty() else null


## A hand-made regular encounter for this act that the run has not played yet (if all of them have been
## played, the used ones become available again), or null if the act has none.
func _pick_regular_encounter() -> EncounterData:
	var fresh: Array[EncounterData] = []
	var all_here: Array[EncounterData] = []
	for encounter in config.regular_encounters:
		if encounter.available_in(act):
			all_here.append(encounter)
			if not used_encounters.has(encounter):
				fresh.append(encounter)
	if fresh.is_empty() and not all_here.is_empty():
		for encounter in all_here:
			used_encounters.erase(encounter)
		fresh = all_here
	if fresh.is_empty():
		return null
	var chosen: EncounterData = fresh.pick_random()
	used_encounters.append(chosen)
	return chosen


func _build_encounter(encounter: EncounterData) -> void:
	encounter_name = encounter.display_name
	encounter_arena = encounter.arena
	for entry in encounter.enemies:
		for i in entry.count:
			enemies.append(entry.figure)
			enemy_elite.append(false)
			enemy_boosts.append(entry.boost())
			enemy_positions.append(entry.positions[i] if i < entry.positions.size() else Vector2.INF)
	if encounter.mirror_deck:
		_add_mirror_enemies(encounter)
	if encounter.fill_with_grunts:
		_fill_with_grunts(encounter)
	enemy_flicks_per_turn = maxi(encounter.enemy_flicks_per_turn, config.difficulty.flicks_per_turn(act))
	enemies_in_row = false


## Mirror Match: one enemy per slot of the act's enemy count, cycling through the figure types of the
## player's current deck (economy figures, which enemies never use, become Grunts), all boosted.
func _add_mirror_enemies(encounter: EncounterData) -> void:
	var types: Array[FigureData] = []
	for figure in deck:
		types.append(config.registry.random_grunt() if config.registry.economy.has(figure) else figure)
	types.shuffle()
	var boost := {"mass": encounter.mirror_mass_multiplier, "power": encounter.mirror_power_multiplier,
			"accuracy": encounter.mirror_accuracy_multiplier, "bounce": 0.0, "ability": 1.0}
	for i in config.difficulty.enemy_count(act):
		enemies.append(types[i % types.size()])
		enemy_elite.append(false)
		enemy_boosts.append(boost.duplicate())
		enemy_positions.append(Vector2.INF)


## Tops the lineup up to the act's enemy count with Grunts in free spots: the spot farthest from
## everything already placed, clear of the arena's walls and pins.
func _fill_with_grunts(encounter: EncounterData) -> void:
	var want := config.difficulty.enemy_count(act)
	var grunt_radius := config.registry.grunts[0].radius
	var spots: Array[Vector2] = []
	for y in [150.0, 270.0, 390.0]:
		for x in [130.0, 290.0, 450.0, 610.0, 770.0]:
			spots.append(Vector2(x, y))
	while enemies.size() < want:
		var grunt := config.registry.random_grunt()
		var best := Vector2.INF
		var best_gap := -1.0
		var any_auto := enemy_positions.has(Vector2.INF)
		if not any_auto:
			for spot in spots:
				if encounter.arena != null and encounter.arena.blocks_circle(spot, grunt_radius + 10.0):
					continue
				var gap := INF
				for i in enemies.size():
					gap = minf(gap, spot.distance_to(enemy_positions[i]) - enemies[i].radius)
				if gap > best_gap:
					best_gap = gap
					best = spot
			if best_gap < grunt_radius + 20.0:
				best = Vector2.INF  # no room: it takes a default slot
		enemies.append(grunt)
		enemy_elite.append(false)
		enemy_boosts.append({})
		enemy_positions.append(best)


## Random layout from the pool, not the same as last time, and only ones a creeping boss can use
## when there is one.
func _pick_arena() -> void:
	# Boss fights are always on the fully open layout (no walls, pins or patches).
	if node != null and node.type == MapNode.Type.BOSS and config.boss_arena != null:
		arena = config.boss_arena
		return
	if encounter_arena != null:  # a hand-made encounter brings its own layout
		arena = encounter_arena
		return
	var has_creeper := false
	for enemy in enemies:
		if enemy.creep_distance > 0.0:
			has_creeper = true
	var candidates: Array[ArenaData] = []
	for candidate in config.arenas:
		if candidate != arena and (candidate.creeper_safe or not has_creeper):
			candidates.append(candidate)
	if candidates.is_empty():
		candidates = config.arenas
	arena = candidates.pick_random() if not candidates.is_empty() else null
