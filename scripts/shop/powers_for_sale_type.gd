class_name PowersForSaleType
extends ShopItemType
## Sells random powers. You need a free power slot to buy one.

@export var count := 1
@export var price := 4


func create_offers(_registry: FigureRegistry) -> Array[ShopOffer]:
	var offers: Array[ShopOffer] = []
	var pool := RunManager.config.power_pool.duplicate()
	pool.shuffle()
	for i in mini(count, pool.size()):
		var power: PowerData = pool[i]
		var offer := ShopOffer.new()
		offer.title = "Power: %s" % power.display_name
		offer.description = power.description
		offer.price = price
		offer.blocked = func() -> String:
			return "" if RunManager.has_free_power_slot() else "No free power slot"
		offer.on_buy = func(_slot: int) -> String:
			RunManager.add_power(power)
			return "Bought %s!" % power.display_name
		offers.append(offer)
	return offers
