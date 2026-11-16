extends "res://tools/balance/bot_policy.gd"
## An example of a swapped strategy for sim 4: it ignores rarity and upgrades and decides everything at random
## (pass --policy=random). Compare its win rate with the default "rarity" policy to see how much drafting matters.


func policy_name() -> String:
	return "random"


func choose_figure(offers: Array) -> Dictionary:
	if offers.is_empty() or rng.randf() < 0.2:
		return {}
	var figure: FigureData = offers[rng.randi() % offers.size()]
	if run.owns(figure):
		return {}
	return {"mode": "recruit", "figure": figure, "slot": rng.randi() % run.deck.size()}


func choose_relic(choices: Array):
	return choices[rng.randi() % choices.size()] if not choices.is_empty() else null


func next_purchase(offers: Array) -> Dictionary:
	var affordable: Array = []
	for offer in offers:
		if not offer.sold and offer.blocked_reason() == "" and offer.price <= run.money:
			affordable.append(offer)
	if affordable.is_empty() or rng.randf() < 0.3:
		return {}
	var offer: ShopOffer = affordable[rng.randi() % affordable.size()]
	if offer.is_upgrade:
		var pick := choose_upgrade()
		return {} if pick.is_empty() else {"offer": offer, "slot": pick.slot, "mode": "upgrade", "path": pick.path}
	if offer.is_figure and run.owns(offer.figure):
		return {}
	return {"offer": offer, "slot": rng.randi() % run.deck.size() if offer.needs_slot else -1, "mode": "buy"}
