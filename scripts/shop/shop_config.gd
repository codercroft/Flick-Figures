class_name ShopConfig
extends Resource
## What the shop sells. `item_types` is the list of kinds of thing for sale; each one makes its own
## offers (and has its own prices) when the shop opens. Edit resources/shop_config.tres.

@export var item_types: Array[ShopItemType] = []


func make_offers(registry: FigureRegistry) -> Array[ShopOffer]:
	var offers: Array[ShopOffer] = []
	print("[shop] building offers from %d item types" % item_types.size())
	for item_type in item_types:
		if item_type == null:
			push_warning("[shop] an item type failed to load (null); skipping it")
			continue
		var made := item_type.create_offers(registry)
		print("[shop]   %s -> %d offers %s" % [item_type.display_name, made.size(), made.map(func(o): return o.title)])
		offers.append_array(made)
	print("[shop] %d offers in total" % offers.size())
	return offers


## What the shop shows: the config's offers, or (if there are none, e.g. the config or its item types
## failed to load) a simple built-in stock so the shop is never empty. Everything it tries is logged.
static func make_offers_for(config: ShopConfig, registry: FigureRegistry) -> Array[ShopOffer]:
	var offers: Array[ShopOffer] = []
	if config == null:
		push_warning("[shop] RunConfig.shop is null: using the fallback stock")
	else:
		offers = config.make_offers(registry)
	if offers.is_empty():
		push_warning("[shop] no offers were generated: using the fallback stock")
		offers = _fallback_offers(registry)
		print("[shop] fallback stock: %s" % [offers.map(func(o): return o.title)])
	return offers


## Three drafted figures and the swap service, built in code (no resources needed).
static func _fallback_offers(registry: FigureRegistry) -> Array[ShopOffer]:
	var offers: Array[ShopOffer] = []
	var figures: Array[FigureData] = []
	if registry != null:
		figures = RunManager.draft_figures(3)
	for figure in figures:
		var offer := ShopOffer.new()
		offer.title = figure.display_name
		offer.description = figure.description
		offer.price = 3 + figure.rarity * 2
		offer.figure = figure
		offer.needs_slot = true
		offer.slot_prompt = "Replace which figure with %s?" % figure.display_name
		offer.on_buy = func(slot: int) -> String:
			RunManager.replace_figure(slot, figure)
			return "Bought %s!" % figure.display_name
		offers.append(offer)
	var swap := ShopOffer.new()
	swap.title = "Swap a figure"
	swap.description = "Trade one of your figures for a random new one."
	swap.price = 3
	swap.needs_slot = true
	swap.slot_prompt = "Swap which figure?"
	swap.on_buy = func(slot: int) -> String:
		var old: FigureData = RunManager.deck[slot]
		var choices := registry.random_draftable(1, [old] as Array[FigureData]) if registry != null else []
		if choices.is_empty():
			return "Nothing to swap in."
		RunManager.replace_figure(slot, choices[0])
		return "Swapped %s for %s!" % [old.display_name, choices[0].display_name]
	offers.append(swap)
	return offers
