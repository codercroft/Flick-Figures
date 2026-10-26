extends Control
## A shop node on the map. It sells whatever the ShopConfig's item types offer (figures, a swap
## service, relics, powers, equipment and upgrades). The offers scroll in the middle of the screen;
## Leave / Back are pinned at the bottom. (See ScreenFrame.)

const MAP_SCENE := "res://scenes/map.tscn"
const CARD_HEIGHT := 140.0

var frame := ScreenFrame.new()
var column: VBoxContainer  # the offer cards (frame.content)
var title: Label
var money_label: Label

var _pending: ShopOffer  # the offer waiting for the player to pick a figure


func _ready() -> void:
	add_child(frame)
	column = frame.content
	title = frame.title
	money_label = frame.subtitle
	_show_offers()


func _show_offers(message := "") -> void:
	frame.clear()
	_pending = null
	title.text = message if message != "" else "Shop"
	money_label.text = "You have $%d" % RunManager.money
	if RunManager.shop_offers.is_empty():
		title.text = "The shop is empty today"
		push_warning("[shop] shop screen opened with no offers")
	for offer in RunManager.shop_offers:
		var reason := offer.blocked_reason()
		var label := "%s - $%d\n%s" % [offer.title, offer.price, offer.description]
		if reason != "":
			label = "%s - $%d\n%s" % [offer.title, offer.price, reason]
		if offer.sold:
			label = "%s - SOLD" % offer.title
		var card := FigureCard.new()
		card.setup(offer.figure, CARD_HEIGHT, label)
		card.disabled = offer.sold or offer.price > RunManager.money or reason != ""
		card.pressed.connect(_on_offer_pressed.bind(offer))
		column.add_child(card)
	frame.add_action("Leave the shop", _on_leave_pressed)


func _on_offer_pressed(offer: ShopOffer) -> void:
	if offer.needs_slot:
		_pending = offer
		_show_slots()
	else:
		_buy(offer, -1)


## Pick which of your figures the offer applies to (grunts first, the usual sacrifice).
func _show_slots() -> void:
	frame.clear()
	title.text = _pending.slot_prompt
	var slots: Array[int] = []
	for i in RunManager.deck.size():
		if RunManager.config.registry.is_grunt(RunManager.deck[i]):
			slots.append(i)
	for i in RunManager.deck.size():
		if not slots.has(i):
			slots.append(i)
	for slot in slots:
		var card := FigureCard.new()
		card.setup(RunManager.deck[slot], 120.0)
		card.pressed.connect(_buy.bind(_pending, slot))
		column.add_child(card)
	frame.add_action("Back", _show_offers)


func _buy(offer: ShopOffer, slot: int) -> void:
	if not RunManager.spend(offer.price):
		_show_offers("Not enough money.")
		return
	_show_offers(offer.buy(slot))


func _on_leave_pressed() -> void:
	RunManager.finish_node()
	get_tree().change_scene_to_file(MAP_SCENE)
