extends Control
## A shop node on the map. It sells whatever the ShopConfig's item types offer (figures, a swap
## service, relics, powers, equipment and upgrades); the list scrolls. Everything the player taps is
## in the bottom half of the screen.

const MAP_SCENE := "res://scenes/map.tscn"
const CARD_HEIGHT := 130.0

var _pending: ShopOffer  # the offer waiting for the player to pick a figure

@onready var column: VBoxContainer = $Column/Scroll/Cards
@onready var title: Label = $Column/Title
@onready var money_label: Label = $Column/MoneyLabel
@onready var leave_button: Button = $Column/LeaveButton


func _ready() -> void:
	leave_button.pressed.connect(_on_leave_pressed)
	_show_offers()


func _show_offers(message := "") -> void:
	_clear_cards()
	_pending = null
	title.text = message if message != "" else "Shop"
	money_label.text = "You have $%d" % RunManager.money
	leave_button.show()
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


func _on_offer_pressed(offer: ShopOffer) -> void:
	if offer.needs_slot:
		_pending = offer
		_show_slots()
	else:
		_buy(offer, -1)


## Pick which of your figures the offer applies to (grunts first, the usual sacrifice).
func _show_slots() -> void:
	_clear_cards()
	leave_button.hide()
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
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0.0, 90.0)
	back.add_theme_font_size_override("font_size", 40)
	back.pressed.connect(_show_offers)
	column.add_child(back)


func _buy(offer: ShopOffer, slot: int) -> void:
	if not RunManager.spend(offer.price):
		_show_offers("Not enough money.")
		return
	_show_offers(offer.buy(slot))


func _on_leave_pressed() -> void:
	RunManager.finish_node()
	get_tree().change_scene_to_file(MAP_SCENE)


func _clear_cards() -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
