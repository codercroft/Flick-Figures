class_name VendingEvent
extends EventScreen
## Vending Machine: pay for a random power, equipment item or finish. The first buy costs `vending_first_price`, each
## later one `vending_price_step` more. Every buy can jam (`vending_jam_chance`): the money is eaten and nothing comes out.
## Buy as often as you like, leave any time.

var _bought := 0
var _message := ""


func start() -> void:
	_show_machine()


func _cfg() -> MinigameConfig:
	return RunManager.config.minigames if RunManager.config.minigames != null else MinigameConfig.new()


func _price() -> int:
	return _cfg().vending_first_price + _cfg().vending_price_step * _bought


func _show_machine() -> void:
	frame.clear()
	frame.title.text = "Vending Machine"
	frame.subtitle.text = _message if _message != "" else "A random power, equipment item or finish. It jams sometimes."
	var price := _price()
	var reason := "" if RunManager.money >= price else "\nNot enough money."
	add_card("Insert $%d%s\n(you have $%d; %d%% chance it jams)" % [price, reason, RunManager.money, roundi(_cfg().vending_jam_chance * 100.0)],
			null, 170.0, _buy, RunManager.money < price)
	frame.add_action("Leave", leave)


func _buy() -> void:
	var price := _price()
	if not RunManager.spend(price):
		return
	_bought += 1
	if randf() < _cfg().vending_jam_chance:
		_message = "It jams! $%d gone, nothing came out." % price
		_show_machine()
		return
	var kinds: Array[String] = []
	for kind in _cfg().vending_kinds:
		if kind == "power" and (not RunManager.has_free_power_slot() or RunManager.config.power_pool.is_empty()):
			continue
		if kind == "finish" and RunManager.random_finish() == null:
			continue
		kinds.append(kind)
	if kinds.is_empty():
		kinds.append("equipment")
	match kinds.pick_random():
		"power":
			var power := RunManager.random_power()
			RunManager.add_power(power)
			_message = "Out comes a power: %s." % power.display_name
			_show_machine()
		"finish":
			_pick_figure_for(RunManager.random_finish())
		_:
			var item := RunManager.random_equipment()
			RunManager.add_equipment(item)
			_message = "Out comes equipment: %s (in your inventory)." % item.display_name
			_show_machine()


## A finish came out: pick who gets it (a figure it would do nothing for is greyed out).
func _pick_figure_for(finish: FinishData) -> void:
	frame.clear()
	frame.title.text = "Out comes %s!" % finish.display_name
	frame.subtitle.text = "%s\nWho gets it?" % finish.description
	var any_fit := false
	for slot in RunManager.deck.size():
		any_fit = any_fit or GearRules.fits(finish, RunManager.deck[slot])
	for slot in RunManager.deck.size():
		var figure: FigureData = RunManager.deck[slot]
		var fits := GearRules.fits(finish, figure) or not any_fit
		var held: FinishData = RunManager.deck_finish[slot]
		add_card(figure.display_name + (("\nreplaces %s" % held.display_name) if held != null else ""), figure, 150.0, _give_finish.bind(finish, slot), not fits)


func _give_finish(finish: FinishData, slot: int) -> void:
	RunManager.set_finish(slot, finish)
	_message = "%s got %s." % [RunManager.deck[slot].display_name, finish.display_name]
	_show_machine()
