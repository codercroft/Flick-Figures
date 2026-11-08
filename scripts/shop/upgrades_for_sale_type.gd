class_name UpgradesForSaleType
extends ShopItemType
## Sells Upgrades (the next tier on a figure's upgrade tree, applied right away) and toy finishes (you pick the
## figure). An Upgrade offer is for one of your figures: if it has no upgrade yet the offer is tier 1 of a random
## path, otherwise the next tier of its chosen path. The price depends on the tier you would take.

## How many Upgrade offers and how many finishes are offered.
@export var upgrade_count := 2
@export var finish_count := 1
## Price of an Upgrade by the tier it would take (tier 1, 2, 3), before Ascension markups.
@export var upgrade_price_by_tier: Array[int] = [5, 8, 12]
@export var finish_price := 7


func create_offers(_registry: FigureRegistry) -> Array[ShopOffer]:
	var offers: Array[ShopOffer] = []
	var slots := RunManager.upgradable_slots()
	slots.shuffle()
	for i in mini(upgrade_count, slots.size()):
		var slot: int = slots[i]
		var figure: FigureData = RunManager.deck[slot]
		var before: Vector2i = RunManager.deck_upgrade[slot]
		var path := before.x if before.x >= 0 else randi_range(0, 1)
		var tier := RunManager.next_tier(slot, path)
		var tree := RunManager.tree_for(figure)
		var upgrade: UpgradeData = tree.tiers(path)[tier - 1]
		var offer := ShopOffer.new()
		offer.title = "Upgrade: %s (%s, %s tier %d)" % [upgrade.display_name, figure.display_name, tree.path_name(path), tier]
		offer.description = upgrade.description
		offer.price = upgrade_price_by_tier[clampi(tier - 1, 0, upgrade_price_by_tier.size() - 1)]
		offer.figure = figure
		offer.blocked = func() -> String:
			if slot >= RunManager.deck.size() or RunManager.deck[slot] != figure or RunManager.deck_upgrade[slot] != before:
				return "That figure has changed"
			return ""
		offer.on_buy = func(_slot: int) -> String:
			RunManager.take_upgrade(slot, path)
			return "%s got %s!" % [figure.display_name, upgrade.display_name]
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
