class_name ReplaceServiceType
extends ShopItemType
## A service: pay to swap one of your figures for a random new draftable one.

@export var price := 3


func create_offers(registry: FigureRegistry) -> Array[ShopOffer]:
	var offer := ShopOffer.new()
	offer.title = "Swap a figure"
	offer.description = "Trade one of your figures for a random new one."
	offer.price = price
	offer.needs_slot = true
	offer.slot_prompt = "Swap which figure?"
	offer.on_buy = func(slot: int) -> String:
		var old: FigureData = RunManager.deck[slot]
		var exclude: Array[FigureData] = [old]
		var choices := registry.random_draftable(1, exclude)
		if choices.is_empty():
			return "Nothing to swap in."
		RunManager.replace_figure(slot, choices[0])
		return "Swapped %s for %s!" % [old.display_name, choices[0].display_name]
	return [offer]
