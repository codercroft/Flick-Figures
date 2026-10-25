class_name EquipmentForSaleType
extends ShopItemType
## Sells random equipment (it goes to your inventory; attach it on the equip screen).

@export var count := 1
@export var price := 5


func create_offers(_registry: FigureRegistry) -> Array[ShopOffer]:
	var offers: Array[ShopOffer] = []
	var pool := RunManager.config.equipment_pool.duplicate()
	pool.shuffle()
	for i in mini(count, pool.size()):
		var item: EquipmentData = pool[i]
		var offer := ShopOffer.new()
		offer.title = "Equipment: %s" % item.display_name
		offer.description = item.description
		offer.price = price
		offer.on_buy = func(_slot: int) -> String:
			RunManager.add_equipment(item)
			return "Bought %s! Equip it from the map." % item.display_name
		offers.append(offer)
	return offers
