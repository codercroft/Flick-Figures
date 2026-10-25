class_name ShopItemType
extends Resource
## A kind of thing the shop can sell. To add a new kind (relics, upgrades, services...), extend this,
## override create_offers() to return ShopOffers, and add one to the item_types list in
## resources/shop_config.tres. The shop screen needs no changes.

@export var display_name := "Item"


## Called when the shop opens: returns the offers of this type for this visit.
func create_offers(_registry: FigureRegistry) -> Array[ShopOffer]:
	return []
