class_name RecyclerEvent
extends EventScreen
## Recycler: give up one figure (the deck keeps at least 1). Reward by its rarity (MinigameConfig.recycler_kinds / recycler_money):
## Common a power, Uncommon an equipment item + $5, Rare a relic (never a Boss relic). Its finish and upgrades are lost, its
## equipment goes to storage (a permanently attached item is lost with it).


func start() -> void:
	frame.title.text = "Recycler"
	frame.subtitle.text = "Feed it a figure: Common = a power, Uncommon = equipment + $5, Rare = a relic."
	if RunManager.deck.size() <= 1:
		frame.subtitle.text = "You only have one figure."
	for slot in RunManager.deck.size():
		var figure: FigureData = RunManager.deck[slot]
		add_card("%s (%s)\nGives: %s" % [figure.display_name, figure.rarity_name(), _reward_text(figure.rarity)], figure, 150.0, _recycle.bind(slot), RunManager.deck.size() <= 1)
	frame.add_action("Leave", leave)


func _cfg() -> MinigameConfig:
	return RunManager.config.minigames if RunManager.config.minigames != null else MinigameConfig.new()


func _reward_text(rarity: int) -> String:
	var cfg := _cfg()
	var kind: String = cfg.recycler_kinds[clampi(rarity, 0, cfg.recycler_kinds.size() - 1)]
	var money: int = cfg.recycler_money[clampi(rarity, 0, cfg.recycler_money.size() - 1)]
	var text: String = {"power": "a power", "equipment": "an equipment item", "relic": "a relic", "finish": "a finish"}.get(kind, kind)
	return text + (" and $%d" % money if money > 0 else "")


func _recycle(slot: int) -> void:
	var cfg := _cfg()
	var figure: FigureData = RunManager.deck[slot]
	var rarity := clampi(figure.rarity, 0, cfg.recycler_kinds.size() - 1)
	var text := _reward_text(figure.rarity)
	if not RunManager.remove_deck_slot(slot):
		return
	RunManager.money += cfg.recycler_money[clampi(rarity, 0, cfg.recycler_money.size() - 1)]
	follow_up_steps = [{"kind": cfg.recycler_kinds[rarity]}]
	show_result("%s was recycled into %s." % [figure.display_name, text])
