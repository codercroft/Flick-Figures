extends Control
## Reward screens after a won combat, a treasure node or a boss. RunManager.reward_steps lists what
## is on offer ("figures", "relic", "relics", "power_chance", "treasure", "upgrade"); each step is
## shown in turn, and EVERY step has a skip button. Everything the player taps is in the bottom half.

const MAP_SCENE := "res://scenes/map.tscn"
const OFFER_CARD_HEIGHT := 220.0
const REPLACE_CARD_HEIGHT := 150.0
const ITEM_CARD_HEIGHT := 190.0

var _steps: Array[Dictionary] = []
var _offers: Array[FigureData] = []
var _chosen: FigureData

@onready var column: VBoxContainer = $Column
@onready var title: Label = $Column/Title
@onready var earned_label: Label = $Column/EarnedLabel


func _ready() -> void:
	_steps = RunManager.reward_steps.duplicate()
	earned_label.text = _earned_text()
	_next_step()


func _earned_text() -> String:
	if RunManager.node == null:
		return ""
	match RunManager.node.type:
		MapNode.Type.COMBAT, MapNode.Type.ELITE:
			return RunManager.income_text()
		MapNode.Type.BOSS:
			return "Boss defeated!"
	return ""


func _next_step() -> void:
	if _steps.is_empty():
		RunManager.finish_rewards()
		get_tree().change_scene_to_file(MAP_SCENE)
		return
	var step: Dictionary = _steps.pop_front()
	match step.kind:
		"figures":
			_offers = RunManager.offer_rewards()
			_show_offers()
		"relics":
			_show_relic_choices()
		"relic":
			_show_found_relic()
		"power_chance":
			_show_power_chance()
		"treasure":
			_show_treasure()
		"upgrade":
			_show_upgrade_figures()
		_:
			_next_step()


# --- Figures: pick 1 of N (or skip), then which figure it replaces --------------

func _show_offers() -> void:
	_clear_cards()
	title.text = "Pick a figure"
	# With more than 3 choices (Trophy Case) the cards shrink so they all fit.
	var card_height := minf(OFFER_CARD_HEIGHT, 560.0 / maxi(_offers.size(), 1))
	for offer in _offers:
		var card := _add_card(offer, card_height)
		card.pressed.connect(_on_offer_chosen.bind(offer))
	_add_button("Skip", _next_step)


func _on_offer_chosen(offer: FigureData) -> void:
	_chosen = offer
	_show_replacements()


func _show_replacements() -> void:
	_clear_cards()
	title.text = "Replace which figure with %s?" % _chosen.display_name
	# Grunts first, since they are the usual sacrifice. Slots keep their deck order otherwise.
	var slots: Array[int] = []
	for i in RunManager.deck.size():
		if RunManager.config.registry.is_grunt(RunManager.deck[i]):
			slots.append(i)
	for i in RunManager.deck.size():
		if not slots.has(i):
			slots.append(i)
	var card_height := minf(REPLACE_CARD_HEIGHT, 600.0 / maxi(slots.size(), 1))
	for slot in slots:
		var card := _add_card(RunManager.deck[slot], card_height)
		card.pressed.connect(_on_replace_chosen.bind(slot))
	_add_button("Back", _show_offers)


func _on_replace_chosen(slot: int) -> void:
	RunManager.replace_figure(slot, _chosen)
	_next_step()


# --- Relics --------------------------------------------------------------------

## Boss: pick 1 of N relics you don't have yet.
func _show_relic_choices() -> void:
	var choices := RunManager.random_new_relics(RunManager.config.boss_relic_choices)
	if choices.is_empty():
		_next_step()
		return
	_clear_cards()
	title.text = "Pick a relic"
	for relic in choices:
		var card := _add_card(null, ITEM_CARD_HEIGHT * 0.8, "%s\n%s" % [relic.display_name, relic.description])
		card.pressed.connect(_take_relic.bind(relic))
	_add_button("Skip", _next_step)


## Elite: a random relic you can take or skip.
func _show_found_relic() -> void:
	var found := RunManager.random_new_relics(1)
	if found.is_empty():
		_next_step()
		return
	_show_take_or_skip("You found a relic!", "%s\n%s" % [found[0].display_name, found[0].description], _take_relic.bind(found[0]))


func _take_relic(relic: RelicData) -> void:
	RunManager.add_relic(relic)
	_next_step()


# --- Powers, treasure, upgrades --------------------------------------------------

func _show_power_chance() -> void:
	var power := RunManager.random_power()
	if power == null or randf() >= RunManager.config.elite_power_chance:
		_next_step()
		return
	if not RunManager.has_free_power_slot():
		_show_message("You found a power (%s), but your power slots are full." % power.display_name)
		return
	_show_take_or_skip("You found a power!", "%s\n%s" % [power.display_name, power.description], _take_power.bind(power))


func _take_power(power: PowerData) -> void:
	RunManager.add_power(power)
	_next_step()


## Treasure node: a random relic or a piece of equipment.
func _show_treasure() -> void:
	var relic: Array[RelicData] = RunManager.random_new_relics(1)
	var equipment := RunManager.random_equipment()
	var want_relic := randf() < RunManager.config.treasure_relic_chance
	if not relic.is_empty() and (want_relic or equipment == null):
		_show_take_or_skip("Treasure: a relic!", "%s\n%s" % [relic[0].display_name, relic[0].description], _take_relic.bind(relic[0]))
	elif equipment != null:
		_show_take_or_skip("Treasure: equipment!", "%s\n%s" % [equipment.display_name, equipment.description], _take_equipment.bind(equipment))
	else:
		_next_step()


func _take_equipment(item: EquipmentData) -> void:
	RunManager.add_equipment(item)
	_next_step()


## Boss: pick one of your figures to get a random upgrade.
func _show_upgrade_figures() -> void:
	_clear_cards()
	title.text = "Upgrade which figure? (the upgrade is random)"
	var card_height := minf(REPLACE_CARD_HEIGHT, 600.0 / maxi(RunManager.deck.size(), 1))
	for slot in RunManager.deck.size():
		var card := _add_card(RunManager.deck[slot], card_height)
		card.pressed.connect(_on_upgrade_figure.bind(slot))
	_add_button("Skip", _next_step)


func _on_upgrade_figure(slot: int) -> void:
	_show_message(RunManager.grant_random_upgrade(slot))


# --- Small building blocks ---------------------------------------------------------

## One item with Take and Skip buttons.
func _show_take_or_skip(heading: String, text: String, on_take: Callable) -> void:
	_clear_cards()
	title.text = heading
	var card := _add_card(null, ITEM_CARD_HEIGHT, text)
	card.pressed.connect(on_take)
	_add_button("Take it", on_take)
	_add_button("Skip", _next_step)


func _show_message(text: String) -> void:
	_clear_cards()
	title.text = text
	_add_button("Continue", _next_step)


func _add_card(data: FigureData, card_height: float, text := "") -> FigureCard:
	var card := FigureCard.new()
	card.setup(data, card_height, text)
	column.add_child(card)
	return card


func _add_button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 90.0)
	button.add_theme_font_size_override("font_size", 40)
	button.pressed.connect(action)
	column.add_child(button)


func _clear_cards() -> void:
	for child in column.get_children():
		if child != title and child != earned_label:
			column.remove_child(child)
			child.queue_free()
