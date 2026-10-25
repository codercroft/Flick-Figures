class_name ShopConfig
extends Resource
## What the shop sells. `item_types` is the list of kinds of thing for sale; each one makes its own
## offers (and has its own prices) when the shop opens. Edit resources/shop_config.tres.

@export var item_types: Array[ShopItemType] = []


func make_offers(registry: FigureRegistry) -> Array[ShopOffer]:
	var offers: Array[ShopOffer] = []
	for item_type in item_types:
		offers.append_array(item_type.create_offers(registry))
	return offers
