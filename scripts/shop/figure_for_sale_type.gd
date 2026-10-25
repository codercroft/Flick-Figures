class_name FigureForSaleType
extends ShopItemType
## Sells random draftable figures. Buying one means choosing which of your figures it replaces.

## How many different figures are offered.
@export var count := 3
## Price by rarity: common, uncommon, rare (see FigureData.rarity).
@export var price_by_rarity: Array[int] = [3, 5, 8]


func create_offers(registry: FigureRegistry) -> Array[ShopOffer]:
	var offers: Array[ShopOffer] = []
	for figure in registry.random_draftable(count):
		var offer := ShopOffer.new()
		offer.title = figure.display_name
		offer.description = figure.description
		offer.price = price_by_rarity[clampi(figure.rarity, 0, price_by_rarity.size() - 1)]
		offer.figure = figure
		offer.needs_slot = true
		offer.slot_prompt = "Replace which figure with %s?" % figure.display_name
		offer.on_buy = func(slot: int) -> String:
			RunManager.replace_figure(slot, figure)
			return "Bought %s!" % figure.display_name
		offers.append(offer)
	return offers
