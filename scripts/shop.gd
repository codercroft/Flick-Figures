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
	# The deck as it sits on the table: tap a slot, then confirm.
	var strip := DeckStrip.new()
	column.add_child(strip)
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 34)
	info.text = "Tap a figure."
	column.add_child(info)
	var confirm := frame.add_action("Confirm", func(): _buy(_pending, strip.selected))
	confirm.disabled = true
	strip.slot_pressed.connect(func(slot: int):
		info.text = DeckStrip.describe_slot(slot, false)
		confirm.disabled = false)
	frame.add_action("Back", _show_offers)


func _buy(offer: ShopOffer, slot: int) -> void:
	if not RunManager.spend(offer.price):
		_show_offers("Not enough money.")
		return
	AudioManager.play_purchase()
	_show_offers(offer.buy(slot))


func _on_leave_pressed() -> void:
	RunManager.finish_node()
	get_tree().change_scene_to_file(MAP_SCENE)
