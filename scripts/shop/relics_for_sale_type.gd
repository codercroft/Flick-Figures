class_name RelicsForSaleType
extends ShopItemType
## Sells random relics the run doesn't hold yet. Never Boss relics; the price depends on rarity.

@export var count := 1
## Price by relic rarity: Common, Uncommon, Rare.
@export var price_by_rarity: Array[int] = [10, 12, 14]


func create_offers(_registry: FigureRegistry) -> Array[ShopOffer]:
	var offers: Array[ShopOffer] = []
	for relic in RunManager.random_new_relics(count):
		var offer := ShopOffer.new()
		offer.title = "Relic: %s (%s)" % [relic.display_name, relic.rarity_name()]
		offer.description = relic.description
		offer.price = price_by_rarity[clampi(relic.rarity, 0, price_by_rarity.size() - 1)]
		offer.on_buy = func(_slot: int) -> String:
			RunManager.add_relic(relic)
			return "Bought the %s relic!" % relic.display_name
		offers.append(offer)
	return offers
