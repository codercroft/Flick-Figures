extends Control
## Reward screen after a won combat: pick 1 of 3 figures, then pick which of yours it replaces.
## Everything the player taps is in the bottom half of the screen.

const MAP_SCENE := "res://scenes/map.tscn"
const OFFER_CARD_HEIGHT := 220.0
const REPLACE_CARD_HEIGHT := 150.0

var _offers: Array[FigureData] = []
var _chosen: FigureData

@onready var column: VBoxContainer = $Column
@onready var title: Label = $Column/Title
@onready var earned_label: Label = $Column/EarnedLabel


func _ready() -> void:
	_offers = RunManager.offer_rewards()
	earned_label.text = RunManager.income_text()
	_show_offers()


func _show_offers() -> void:
	_clear_cards()
	title.text = "Combat cleared! Pick a reward"
	# With more than 3 choices (Trophy Case) the cards shrink so they all fit.
	var card_height := minf(OFFER_CARD_HEIGHT, 640.0 / maxi(_offers.size(), 1))
	for offer in _offers:
		var card := _add_card(offer, card_height)
		card.pressed.connect(_on_offer_chosen.bind(offer))


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
	for slot in slots:
		var card := _add_card(RunManager.deck[slot], REPLACE_CARD_HEIGHT)
		card.pressed.connect(_on_replace_chosen.bind(slot))
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0.0, 90.0)
	back.add_theme_font_size_override("font_size", 40)
	back.pressed.connect(_show_offers)
	column.add_child(back)


func _on_replace_chosen(slot: int) -> void:
	RunManager.replace_figure(slot, _chosen)
	get_tree().change_scene_to_file(MAP_SCENE)


func _add_card(data: FigureData, card_height: float) -> FigureCard:
	var card := FigureCard.new()
	card.setup(data, card_height)
	column.add_child(card)
	return card


func _clear_cards() -> void:
	for child in column.get_children():
		if child != title and child != earned_label:
			column.remove_child(child)
			child.queue_free()
