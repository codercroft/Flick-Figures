class_name FinisherEvent
extends EventScreen
## The Finisher: offers a few different random finishes (each fits at least one figure of the deck). Pick one,
## then the figure that gets it (its old finish is replaced), or leave.

var _offers: Array[FinishData] = []


func start() -> void:
	var fitting: Array[FinishData] = []
	for finish in RunManager.config.finish_pool:
		if not _fitting_slots(finish).is_empty():
			fitting.append(finish)
	fitting.shuffle()
	var count: int = RunManager.config.minigames.finisher_choices if RunManager.config.minigames != null else 3
	_offers.assign(fitting.slice(0, count))
	_show_menu()


func _show_menu() -> void:
	frame.clear()
	frame.title.text = "The Finisher"
	frame.subtitle.text = "Pick a toy finish for one of your figures."
	if _offers.is_empty():
		frame.subtitle.text = "No finish fits any of your figures."
	for finish in _offers:
		add_card("%s\n%s" % [finish.display_name, finish.description], null, 160.0, _pick_figure.bind(finish))
	frame.add_action("Leave", leave)


func _fitting_slots(finish: FinishData) -> Array[int]:
	var slots: Array[int] = []
	for slot in RunManager.deck.size():
		if GearRules.fits(finish, RunManager.deck[slot]):
			slots.append(slot)
	return slots


func _pick_figure(finish: FinishData) -> void:
	frame.clear()
	frame.title.text = "Give %s to which figure?" % finish.display_name
	frame.subtitle.text = finish.description
	var fitting := _fitting_slots(finish)
	for slot in RunManager.deck.size():
		var figure: FigureData = RunManager.deck[slot]
		var held: FinishData = RunManager.deck_finish[slot]
		var note := ("\nreplaces %s" % held.display_name) if held != null else ""
		if not fitting.has(slot):
			note = "\nwould do nothing for it"
		add_card(figure.display_name + note, figure, 150.0, _apply.bind(finish, slot), not fitting.has(slot))
	frame.add_action("Back", _show_menu)


func _apply(finish: FinishData, slot: int) -> void:
	RunManager.set_finish(slot, finish)
	show_result("%s got %s!" % [RunManager.deck[slot].display_name, finish.display_name])
