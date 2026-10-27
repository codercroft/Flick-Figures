class_name UpgradesForSaleType
extends ShopItemType
## Sells figure upgrades: figure-specific ones for figures you hold (they apply right away), and
## toy finishes (you pick which figure gets it).

## How many figure-specific upgrades and how many finishes are offered.
@export var specific_count := 1
@export var finish_count := 1
@export var specific_price := 6
@export var finish_price := 7


func create_offers(_registry: FigureRegistry) -> Array[ShopOffer]:
	var offers: Array[ShopOffer] = []
	var candidates: Array[UpgradeData] = []
	for slot in RunManager.deck.size():
		for upgrade in RunManager.upgrades_for(RunManager.deck[slot]):
			if RunManager.deck_upgrade[slot] != upgrade and not candidates.has(upgrade):
				candidates.append(upgrade)
	candidates.shuffle()
	for i in mini(specific_count, candidates.size()):
		var upgrade: UpgradeData = candidates[i]
		var offer := ShopOffer.new()
		offer.title = "Upgrade: %s (%s)" % [upgrade.display_name, upgrade.figure.display_name]
		offer.description = upgrade.description
		offer.price = specific_price
		offer.figure = upgrade.figure
		offer.blocked = func() -> String:
			return "" if _slot_for(upgrade) != -1 else "You no longer have %s" % upgrade.figure.display_name
		offer.on_buy = func(_slot: int) -> String:
			RunManager.set_upgrade(_slot_for(upgrade), upgrade)
			return "%s got %s!" % [upgrade.figure.display_name, upgrade.display_name]
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


## The first deck slot that holds the upgrade's figure and doesn't have the upgrade yet, or -1.
func _slot_for(upgrade: UpgradeData) -> int:
	for slot in RunManager.deck.size():
		if RunManager.deck[slot] == upgrade.figure and RunManager.deck_upgrade[slot] != upgrade:
			return slot
	return -1
