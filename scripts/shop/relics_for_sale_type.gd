class_name RelicsForSaleType
extends ShopItemType
## Sells random relics the run doesn't hold yet.

@export var count := 1
@export var price := 7


func create_offers(_registry: FigureRegistry) -> Array[ShopOffer]:
	var offers: Array[ShopOffer] = []
	for relic in RunManager.random_new_relics(count):
		var offer := ShopOffer.new()
		offer.title = "Relic: %s" % relic.display_name
		offer.description = relic.description
		offer.price = price
		offer.on_buy = func(_slot: int) -> String:
			RunManager.add_relic(relic)
			return "Bought the %s relic!" % relic.display_name
		offers.append(offer)
	return offers
