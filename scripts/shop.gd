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
		card.owned = offer.is_figure and RunManager.owns(offer.figure) and not offer.sold
		card.disabled = offer.sold or offer.price > RunManager.money or reason != ""
		card.pressed.connect(_on_offer_pressed.bind(offer))
		column.add_child(card)
	frame.add_action("Leave the shop", _on_leave_pressed)


func _on_offer_pressed(offer: ShopOffer) -> void:
	if offer.is_upgrade:
		var slots := RunManager.upgradable_slots()
		if slots.size() == 1:
			_show_upgrade_tree(offer, slots[0])
		else:
			_show_copy_picker(offer, slots)
	elif offer.is_figure and RunManager.owns(offer.figure):
		_show_duplicate_choice(offer)  # Recruit another copy, or Upgrade the one you have (the same price)
	elif offer.needs_slot:
		_pending = offer
		_show_slots()
	else:
		_buy(offer, -1)


## You already own the figure for sale: Recruit it as usual, or Upgrade your copy instead. Either costs the price.
func _show_duplicate_choice(offer: ShopOffer) -> void:
	frame.clear()
	title.text = "You already have %s ($%d)" % [offer.figure.display_name, offer.price]
	var copies := RunManager.upgradable_copies(offer.figure)
	var recruit := FigureCard.new()
	recruit.setup(offer.figure, 200.0, "Recruit: add it as a new figure\n(you pick which figure it replaces)", 32)
	recruit.pressed.connect(func() -> void:
		_pending = offer
		_show_slots())
	column.add_child(recruit)
	var upgrade := FigureCard.new()
	upgrade.setup(offer.figure, 200.0, "Upgrade: take an upgrade step on your %s\n%s" % [
			offer.figure.display_name, "" if not copies.is_empty() else "No upgrade tiers left on your copy."], 32)
	upgrade.disabled = copies.is_empty()
	upgrade.pressed.connect(func() -> void:
		if copies.size() == 1:
			_show_upgrade_tree(offer, copies[0])
		else:
			_show_copy_picker(offer, copies))
	column.add_child(upgrade)
	frame.add_action("Back", _show_offers)


## Several copies: pick which one gets the upgrade.
func _show_copy_picker(offer: ShopOffer, copies: Array[int]) -> void:
	frame.clear()
	title.text = "Upgrade which figure ($%d)?" % offer.price if offer.is_upgrade else "Upgrade which %s?" % offer.figure.display_name
	for slot in copies:
		var summary := RunManager.upgrade_summary(slot)
		var data: FigureData = RunManager.deck[slot]
		var card := FigureCard.new()
		card.setup(data, 150.0, "%s\n%s" % [data.display_name, summary if summary != "" else "no upgrades yet"], 32)
		card.pressed.connect(_show_upgrade_tree.bind(offer, slot))
		column.add_child(card)
	frame.add_action("Back", _show_offers if offer.is_upgrade else _show_duplicate_choice.bind(offer))


## Both upgrade paths: tap an available box, then Take it (this is where the price is paid).
func _show_upgrade_tree(offer: ShopOffer, slot: int) -> void:
	frame.clear()
	title.text = "%s: choose an upgrade ($%d)" % [RunManager.deck[slot].display_name, offer.price]
	var view := UpgradeTreeView.new()
	column.add_child(view)
	view.setup(RunManager.deck[slot], RunManager.deck_upgrade[slot])
	frame.add_action("Take it", func() -> void:
		if view.selected_state() != "available":
			title.text = "Pick a gold (available) box first"
			return
		if not RunManager.spend(offer.price):
			_show_offers("Not enough money.")
			return
		AudioManager.play_purchase()
		RunManager.take_upgrade(slot, view.selected.x)
		offer.sold = true
		_show_offers("%s upgraded!" % RunManager.deck[slot].display_name))
	frame.add_action("Back", _show_offers if offer.is_upgrade else _show_duplicate_choice.bind(offer))


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
