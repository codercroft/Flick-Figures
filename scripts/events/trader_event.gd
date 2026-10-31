class_name TraderEvent
extends EventScreen
## The Trader: three trades, take one or leave.
## Low: give a power or an equipment item, get a different random power or equipment item.
## Medium: give one of your figures, get a random Common or Uncommon figure (shown first).
## High: give money plus one or two figures, get an Uncommon (one figure) or Rare (two figures) figure
## that comes with a finish, upgrade or equipment item. The deck never drops below one figure.

## Money the high trade costs (on top of the figures).
@export var high_trade_cost := 6
## Rarities the medium trade can give (0 common, 1 uncommon, 2 rare).
@export var medium_rarities: Array[int] = [0, 1]

var _medium_offer: FigureData
var _high_offers := {}  # figures given (1 or 2) -> {figure, finish, upgrade, equipment}
var _high_picks: Array[int] = []  # deck slots chosen for the high trade


func start() -> void:
	_medium_offer = _random_figure(medium_rarities)
	_high_offers = {1: _roll_high_offer(1), 2: _roll_high_offer(2)}
	RunHistory.mark_seen(_medium_offer)
	for offer in _high_offers.values():
		if offer != null:
			RunHistory.mark_seen(offer.figure)
	_show_menu()


func _show_menu() -> void:
	frame.clear()
	_high_picks.clear()
	frame.title.text = "The Trader"
	frame.subtitle.text = "Take one trade, or leave."
	var gives := _low_gives()
	add_card("Low trade\nGive a power or an equipment item, get a different random one.\n%s" % (
			"" if not gives.is_empty() else "You have no power or unequipped equipment."), null, 190.0, _show_low_picker, gives.is_empty())
	if _medium_offer != null:
		add_card("Medium trade\nGive one of your figures, get\n%s (%s)\n%s" % [_medium_offer.display_name, _medium_offer.rarity_name(), _medium_offer.description],
				_medium_offer, 250.0, _show_medium_picker)
	var cheap = _high_offers[1]  # (untyped: null if there is no figure of that rarity)
	var rich = _high_offers[2]
	var reason := ""
	if RunManager.money < high_trade_cost:
		reason = "Needs $%d." % high_trade_cost
	if cheap != null and rich != null:
		add_card("High trade\nGive $%d and 1 figure: get %s (%s) with %s.\nGive $%d and 2 figures: get %s (%s) with %s.\n%s" % [
				high_trade_cost, cheap.figure.display_name, cheap.figure.rarity_name(), _gear_name(cheap),
				high_trade_cost, rich.figure.display_name, rich.figure.rarity_name(), _gear_name(rich), reason],
				null, 330.0, _show_high_picker, reason != "")
	frame.add_action("Leave", leave)


# --- Low trade: a power or equipment item for another -------------------------------

func _low_gives() -> Array:
	var gives: Array = []
	for power in RunManager.powers:
		if power != null:
			gives.append(power)
	gives.append_array(RunManager.equipment_inventory)
	return gives


func _show_low_picker() -> void:
	frame.clear()
	frame.title.text = "Give which item?"
	frame.subtitle.text = ""
	for item in _low_gives():
		var kind := "Power" if item is PowerData else "Equipment"
		add_card("%s: %s\n%s" % [kind, item.display_name, item.description], null, 150.0, _do_low.bind(item))
	frame.add_action("Back", _show_menu)


func _do_low(give: Resource) -> void:
	# Take the given item away first (a power frees its slot).
	if give is PowerData:
		RunManager.powers[RunManager.powers.find(give)] = null
	else:
		RunManager.equipment_inventory.erase(give)
	var candidates: Array[Resource] = []
	if RunManager.has_free_power_slot():
		for power in RunManager.config.power_pool:
			if power != give:
				candidates.append(power)
	for item in RunManager.config.equipment_pool:
		if item != give:
			candidates.append(item)
	var got: Resource = candidates.pick_random()
	if got is PowerData:
		RunManager.add_power(got)
	else:
		RunManager.add_equipment(got)
	show_result("You gave %s and got %s.\n%s" % [give.display_name, got.display_name, got.description])


# --- Medium trade: a figure for a Common or Uncommon one ---------------------------------

func _show_medium_picker() -> void:
	frame.clear()
	frame.title.text = "Give which figure?"
	frame.subtitle.text = "You get %s (%s)." % [_medium_offer.display_name, _medium_offer.rarity_name()]
	for slot in _slots_grunts_first():
		var figure: FigureData = RunManager.deck[slot]
		add_card("%s (%s)\n%s" % [figure.display_name, figure.rarity_name(), _gear_summary(slot)], figure, 170.0, _do_medium.bind(slot))
	frame.add_action("Back", _show_menu)


func _do_medium(slot: int) -> void:
	var given: FigureData = RunManager.deck[slot]
	RunManager.replace_figure(slot, _medium_offer)
	show_result("You gave %s and got %s." % [given.display_name, _medium_offer.display_name])


# --- High trade: money and one or two figures for a figure with gear --------------------------

func _show_high_picker() -> void:
	frame.clear()
	_render_high_picker()


func _render_high_picker() -> void:
	frame.clear()
	frame.title.text = "Give 1 or 2 figures"
	frame.subtitle.text = "Costs $%d. 1 figure: %s. 2 figures: %s." % [high_trade_cost,
			_high_offers[1].figure.rarity_name(), _high_offers[2].figure.rarity_name()]
	for slot in _slots_grunts_first():
		var figure: FigureData = RunManager.deck[slot]
		var mark := "[x] " if _high_picks.has(slot) else "[  ] "
		# At most two figures can be given (the new figure always joins the deck, so it never empties).
		var blocked := not _high_picks.has(slot) and _high_picks.size() >= 2
		add_card("%s%s (%s)\n%s" % [mark, figure.display_name, figure.rarity_name(), _gear_summary(slot)], figure, 170.0, _toggle_high.bind(slot), blocked)
	if _high_picks.size() >= 1:
		var offer: Dictionary = _high_offers[_high_picks.size()]
		frame.add_action("Trade $%d + %d figure(s) for %s" % [high_trade_cost, _high_picks.size(), offer.figure.display_name], _do_high)
	frame.add_action("Back", _show_menu)


func _toggle_high(slot: int) -> void:
	if _high_picks.has(slot):
		_high_picks.erase(slot)
	else:
		_high_picks.append(slot)
	_render_high_picker()


func _do_high() -> void:
	if _high_picks.is_empty() or RunManager.money < high_trade_cost:
		return
	var offer: Dictionary = _high_offers[_high_picks.size()]
	_high_picks.sort()
	var keep: int = _high_picks[0]  # the new figure takes the first chosen slot
	if _high_picks.size() == 2 and not RunManager.remove_deck_slot(_high_picks[1]):
		return  # (cannot happen: the deck has at least two figures here)
	RunManager.spend(high_trade_cost)
	RunManager.replace_figure(keep, offer.figure)
	if offer.finish != null:
		RunManager.set_finish(keep, offer.finish)
	if offer.upgrade != null:
		RunManager.set_upgrade(keep, offer.upgrade)
	if offer.equipment != null:
		RunManager.deck_equipment[keep] = offer.equipment
	show_result("You paid $%d and got %s with %s." % [high_trade_cost, offer.figure.display_name, _gear_name(offer)])


# --- Helpers -----------------------------------------------------------------------------

func _slots_grunts_first() -> Array[int]:
	var slots: Array[int] = []
	for i in RunManager.deck.size():
		if RunManager.config.registry.is_grunt(RunManager.deck[i]):
			slots.append(i)
	for i in RunManager.deck.size():
		if not slots.has(i):
			slots.append(i)
	return slots


func _gear_summary(slot: int) -> String:
	var parts: Array[String] = []
	if RunManager.deck_finish[slot] != null:
		parts.append(RunManager.deck_finish[slot].display_name)
	if RunManager.deck_upgrade[slot] != null:
		parts.append(RunManager.deck_upgrade[slot].display_name)
	if RunManager.deck_equipment[slot] != null:
		parts.append(RunManager.deck_equipment[slot].display_name)
	return "Gear: " + (", ".join(parts) if not parts.is_empty() else "none")


func _gear_name(offer: Dictionary) -> String:
	for key in ["finish", "upgrade", "equipment"]:
		if offer[key] != null:
			return "%s (%s)" % [offer[key].display_name, key]
	return "nothing"


## A random draftable figure (never a Grunt) of one of the given rarities, or null.
func _random_figure(rarities: Array) -> FigureData:
	var pool: Array[FigureData] = []
	for figure in RunManager.config.registry.draftable:
		if rarities.has(figure.rarity) and not RunManager.config.registry.is_grunt(figure):
			pool.append(figure)
	return pool.pick_random() if not pool.is_empty() else null


## What the high trade gives for `given` figures: 1 = Uncommon, 2 = Rare, with one random piece of gear
## that fits it (a finish, a figure-specific upgrade or an equipment item).
func _roll_high_offer(given: int) -> Variant:
	var figure := _random_figure([1] if given == 1 else [2])
	if figure == null:
		return null
	var options: Array[String] = []
	var finish: FinishData = GearRules.pick(RunManager.config.finish_pool, figure)
	if finish != null:
		options.append("finish")
	var upgrades := RunManager.upgrades_for(figure)
	if not upgrades.is_empty():
		options.append("upgrade")
	var item: EquipmentData = GearRules.pick(RunManager.config.equipment_pool, figure)
	if item != null:
		options.append("equipment")
	var offer := {"figure": figure, "finish": null, "upgrade": null, "equipment": null}
	if options.is_empty():
		return offer
	match options.pick_random():
		"finish":
			offer.finish = finish
		"upgrade":
			offer.upgrade = upgrades.pick_random()
		"equipment":
			offer.equipment = item
	return offer
