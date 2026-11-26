class_name GearManEvent
extends EventScreen
## Gear Man: offers a few random equipment items. Pick one and the figure that wears it: it is attached for good (it cannot be
## unequipped, swapped or replaced, even with Costume Change) and is only lost with the figure. A figure's old
## (not permanent) item goes to storage.

var _offers: Array[EquipmentData] = []


func start() -> void:
	var fitting: Array[EquipmentData] = []
	for item in RunManager.config.equipment_pool:
		if not _fitting_slots(item).is_empty():
			fitting.append(item)
	fitting.shuffle()
	var count: int = RunManager.config.minigames.gear_man_choices if RunManager.config.minigames != null else 3
	_offers.assign(fitting.slice(0, count))
	_show_menu()


func _show_menu() -> void:
	frame.clear()
	frame.title.text = "Gear Man"
	frame.subtitle.text = "Gear that stays on for good."
	if _offers.is_empty():
		frame.subtitle.text = "He has nothing that fits your figures."
	for item in _offers:
		add_card("%s (%s)\n%s" % [item.display_name, item.rarity_name(), item.description], null, 170.0, _pick_figure.bind(item))
	frame.add_action("Leave", leave)


## Figures that can wear it: it must do something for them and they must not already wear a permanent item.
func _fitting_slots(item: EquipmentData) -> Array[int]:
	var slots: Array[int] = []
	for slot in RunManager.deck.size():
		if GearRules.fits(item, RunManager.deck[slot]) and not RunManager.is_locked(slot):
			slots.append(slot)
	return slots


func _pick_figure(item: EquipmentData) -> void:
	frame.clear()
	frame.title.text = "Who wears %s?" % item.display_name
	frame.subtitle.text = "It cannot be taken off again."
	var fitting := _fitting_slots(item)
	for slot in RunManager.deck.size():
		var figure: FigureData = RunManager.deck[slot]
		var note := ""
		if RunManager.is_locked(slot):
			note = "\nalready wears permanent %s" % RunManager.deck_equipment[slot].display_name
		elif not fitting.has(slot):
			note = "\nwould do nothing for it"
		elif RunManager.deck_equipment[slot] != null:
			note = "\n%s goes to storage" % RunManager.deck_equipment[slot].display_name
		add_card(figure.display_name + note, figure, 150.0, _apply.bind(item, slot), not fitting.has(slot))
	frame.add_action("Back", _show_menu)


func _apply(item: EquipmentData, slot: int) -> void:
	if RunManager.attach_permanent(item, slot):
		show_result("%s now wears %s for good!" % [RunManager.deck[slot].display_name, item.display_name])
