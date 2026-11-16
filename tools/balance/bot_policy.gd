extends RefCounted
## The run policy the PlayerBot uses in sim 4 (full runs): the simple draft / shop / path rules. It is the DEFAULT policy ("rarity").
## To compare strategies, copy this file (see policy_random.gd), change the decisions you care about and pass --policy=<name>
## (run_sims.py --policy=...; the names are listed in POLICIES in run_sim.gd). Every decision the bot makes during a run is one of
## the methods below, and each returns plain data, so a policy never touches the game itself.
##
## Default rules: prefer higher rarity; prefer upgrading figures it already has; never take a second copy of an economy figure;
## buy relics whenever it can afford one; paths are picked at random.

var run  # RunManager
var rng := RandomNumberGenerator.new()


func _init(run_manager, seed_value: int) -> void:
	run = run_manager
	rng.seed = seed_value


func policy_name() -> String:
	return "rarity"


# --- The map -----------------------------------------------------------------------------------------------------------

## Which reachable node to walk to (map node ids).
func pick_node(options: Array) -> int:
	return options[rng.randi() % options.size()]


# --- Figures ---------------------------------------------------------------------------------------------------------

## How good the figure in a deck slot is to keep: Grunts are worth nothing, then rarity and every upgrade tier it carries.
func slot_value(slot: int) -> float:
	var figure: FigureData = run.deck[slot]
	if figure == run.config.starting_figure:
		return 0.0
	return 1.0 + figure.rarity + 0.75 * run.deck_upgrade[slot].y


func worst_slot() -> int:
	var worst := 0
	for slot in run.deck.size():
		if slot_value(slot) < slot_value(worst):
			worst = slot
	return worst


func figure_value(figure: FigureData) -> float:
	return 1.0 + figure.rarity


## A figure reward (or boss reward) with these offers. Returns {} to skip, {mode: "recruit", figure, slot} or
## {mode: "upgrade", slot, path} (an offered figure you already own: upgrade your copy instead of taking another).
func choose_figure(offers: Array) -> Dictionary:
	var best_upgrade: Dictionary = {}
	for offer in offers:
		if run.owns(offer):
			var copies: Array = run.upgradable_copies(offer)
			if not copies.is_empty() and (best_upgrade.is_empty() or offer.rarity > best_upgrade.rarity):
				var pick := _upgrade_choice(copies)
				best_upgrade = {"mode": "upgrade", "slot": pick.slot, "path": pick.path, "rarity": offer.rarity}
	if not best_upgrade.is_empty():
		return best_upgrade
	var best: FigureData = null
	for offer in offers:
		if run.owns(offer):
			continue  # (a copy it cannot upgrade, or an economy figure it already has)
		if best == null or offer.rarity > best.rarity or (offer.rarity == best.rarity and rng.randf() < 0.5):
			best = offer
	if best == null:
		return {}
	var slot := worst_slot()
	if figure_value(best) <= slot_value(slot):
		return {}  # nothing in the deck is worth swapping out for it
	return {"mode": "recruit", "figure": best, "slot": slot}


## Which deck slot takes the next upgrade tier and on which path ({} if none can). `copies` limits the choice (a duplicate pick).
func choose_upgrade(copies: Array = []) -> Dictionary:
	var slots: Array = copies if not copies.is_empty() else run.upgradable_slots()
	if slots.is_empty():
		return {}
	return _upgrade_choice(slots)


func _upgrade_choice(slots: Array) -> Dictionary:
	var best: int = slots[0]
	for slot in slots:
		if slot_value(slot) > slot_value(best):
			best = slot
	var state: Vector2i = run.deck_upgrade[best]
	var path := state.x
	if path < 0:  # the first pick chooses the path: at random
		path = rng.randi() % 2
		if run.next_tier(best, path) == 0:
			path = 1 - path
	return {"slot": best, "path": path}


## The relic to take out of a choice (null = none).
func choose_relic(choices: Array):
	var best = null
	for relic in choices:
		if best == null or relic.rarity > best.rarity:
			best = relic
	return best


## The deck slot that gets a finish (-1 = leave it): the best figure that has none yet.
func choose_finish_slot(_finish) -> int:
	var best := -1
	for slot in run.deck.size():
		if run.deck_finish[slot] == null and (best == -1 or slot_value(slot) > slot_value(best)):
			best = slot
	return best


## The deck slot that gets an equipment item (-1 = keep it in the bag).
func choose_equipment_slot(item) -> int:
	var best := -1
	for slot in run.deck.size():
		if run.deck_equipment[slot] == null and GearRules.fits(item, run.deck[slot]) and (best == -1 or slot_value(slot) > slot_value(best)):
			best = slot
	return best


## Power slot to replace when all are full (-1 = discard the new power).
func choose_power_replace(_power) -> int:
	return -1


# --- The shop --------------------------------------------------------------------------------------------------------

## The next thing to buy right now, or {} to stop shopping. Returns {offer, slot, mode, path}: `slot` is the deck slot the
## offer acts on (-1 when it needs none), `mode` "recruit" / "upgrade" for an offered figure that is already owned.
func next_purchase(offers: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_priority := -1.0
	for offer in offers:
		if offer.sold or offer.blocked_reason() != "" or offer.price > run.money:
			continue
		var plan := _plan_offer(offer)
		if plan.is_empty():
			continue
		if plan.priority > best_priority:
			best_priority = plan.priority
			best = plan
	return best


func _plan_offer(offer: ShopOffer) -> Dictionary:
	var title := offer.title
	if title.begins_with("Relic:"):  # buy relics whenever it can afford them (rarer first)
		return {"offer": offer, "slot": -1, "mode": "buy", "priority": 100.0 + offer.price}
	if offer.is_upgrade:
		var pick := choose_upgrade()
		if pick.is_empty():
			return {}
		return {"offer": offer, "slot": pick.slot, "mode": "upgrade", "path": pick.path, "priority": 80.0}
	if offer.is_figure:
		var figure: FigureData = offer.figure
		if run.owns(offer.figure):
			var copies: Array = run.upgradable_copies(figure)
			if copies.is_empty():
				return {}
			var pick := _upgrade_choice(copies)
			return {"offer": offer, "slot": pick.slot, "mode": "upgrade", "path": pick.path, "priority": 70.0 + figure.rarity}
		var slot := worst_slot()
		if figure_value(figure) <= slot_value(slot):
			return {}
		return {"offer": offer, "slot": slot, "mode": "buy", "priority": 40.0 + 10.0 * figure.rarity}
	if title.begins_with("Finish:"):
		var slot := choose_finish_slot(null)
		return {} if slot < 0 else {"offer": offer, "slot": slot, "mode": "buy", "priority": 30.0}
	if title.begins_with("Equipment:"):
		return {"offer": offer, "slot": -1, "mode": "buy", "priority": 20.0}
	if title.begins_with("Power:"):
		return {"offer": offer, "slot": -1, "mode": "buy", "priority": 10.0}
	return {}  # (Swap a figure and anything else new: not bought)


## The shop category of an offer for the report ("relic", "upgrade", "figure", "finish", "equipment", "power", "swap", "other").
func shop_category(offer: ShopOffer) -> String:
	var title := offer.title
	if title.begins_with("Relic:"):
		return "relic"
	if offer.is_upgrade:
		return "upgrade"
	if offer.is_figure:
		return "figure"
	for key in ["Finish", "Equipment", "Power", "Swap"]:
		if title.begins_with(key):
			return key.to_lower()
	return "other"
