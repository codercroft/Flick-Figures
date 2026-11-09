class_name UpgradesForSaleType
extends ShopItemType
## Sells ONE Upgrade and toy finishes (you pick the figure). The Upgrade can be used on any figure that has a tier
## left: you pick the figure and then the next box of its tree (the first pick chooses the path). One flat price.

## Upgrade offers per shop.
@export var upgrade_count := 1
@export var finish_count := 1
## Price of the Upgrade (before Ascension markups).
@export var upgrade_price := 20
@export var finish_price := 7


func create_offers(_registry: FigureRegistry) -> Array[ShopOffer]:
	var offers: Array[ShopOffer] = []
	for i in upgrade_count:  # (always offered; greyed out while no figure can take one)
		var offer := ShopOffer.new()
		offer.title = "Upgrade"
		offer.description = "Upgrade any of your figures (the next tier on its path)"
		offer.price = upgrade_price
		offer.is_upgrade = true
		offer.blocked = func() -> String:
			return "" if not RunManager.upgradable_slots().is_empty() else "No figure can take an upgrade"
		offers.append(offer)
	var finishes := RunManager.config.finish_pool.duplicate()
	finishes.shuffle()
	for i in mini(finish_count, finishes.size()):
		var finish: FinishData = finishes[i]
		var offer := ShopOffer.new()
		offer.title = "Finish: %s" % finish.display_name
		offer.description = finish.description
		offer.price = finish_price
		offer.needs_slot = true
		offer.slot_prompt = "Give which figure the %s finish?" % finish.display_name
		offer.on_buy = func(slot: int) -> String:
			RunManager.set_finish(slot, finish)
			return "%s is now %s!" % [RunManager.deck[slot].display_name, finish.display_name]
		offers.append(offer)
	return offers
