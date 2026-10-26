extends Control
## Test screen for figure upgrades (free, until rewards or the shop hand them out): pick a figure,
## then give it a toy finish (one per figure) and/or its figure-specific upgrade (if it has one).
## The choices scroll in the middle of the screen; Done/Back are pinned at the bottom. Turn it off with RunConfig.show_upgrade_screen.

const MAP_SCENE := "res://scenes/map.tscn"
const FIGURE_CARD_HEIGHT := 125.0
const OPTION_CARD_HEIGHT := 105.0

var _slot := -1

var frame := ScreenFrame.new()
var column: VBoxContainer
var title: Label


func _ready() -> void:
	add_child(frame)
	column = frame.content
	title = frame.title
	_show_figures()


func _show_figures() -> void:
	_clear_cards()
	title.text = "Upgrade which figure?"
	for slot in RunManager.deck.size():
		var card := _add_card(RunManager.deck[slot], _describe(slot), FIGURE_CARD_HEIGHT)
		card.pressed.connect(_show_options.bind(slot))
	_add_button("Done", _leave)


func _describe(slot: int) -> String:
	var finish: FinishData = RunManager.deck_finish[slot]
	var upgrade: UpgradeData = RunManager.deck_upgrade[slot]
	return "%s\nfinish: %s | upgrade: %s" % [RunManager.deck[slot].display_name,
			finish.display_name if finish != null else "none", upgrade.display_name if upgrade != null else "none"]


func _show_options(slot: int) -> void:
	_slot = slot
	_clear_cards()
	var figure: FigureData = RunManager.deck[slot]
	title.text = "%s: pick a finish or upgrade" % figure.display_name
	var upgrades := RunManager.upgrades_for(figure)
	if upgrades.is_empty():
		title.text += "\n(no figure-specific upgrade yet)"
	for upgrade in upgrades:
		var mark := " (on)" if RunManager.deck_upgrade[slot] == upgrade else ""
		var card := _add_card(null, "%s%s\n%s" % [upgrade.display_name, mark, upgrade.description], OPTION_CARD_HEIGHT)
		card.pressed.connect(_on_upgrade.bind(upgrade))
	for finish in RunManager.config.finish_pool:
		var mark := " (on)" if RunManager.deck_finish[slot] == finish else ""
		var card := _add_card(null, "%s%s\n%s" % [finish.display_name, mark, finish.description], OPTION_CARD_HEIGHT)
		card.pressed.connect(_on_finish.bind(finish))
	_add_button("Clear", _on_clear)
	_add_button("Back", _show_figures)


func _on_upgrade(upgrade: UpgradeData) -> void:
	RunManager.set_upgrade(_slot, upgrade)
	_show_options(_slot)


func _on_finish(finish: FinishData) -> void:
	RunManager.set_finish(_slot, finish)
	_show_options(_slot)


func _on_clear() -> void:
	RunManager.set_finish(_slot, null)
	RunManager.set_upgrade(_slot, null)
	_show_options(_slot)


func _leave() -> void:
	get_tree().change_scene_to_file(MAP_SCENE)


func _add_card(data: FigureData, text: String, card_height: float) -> FigureCard:
	var card := FigureCard.new()
	card.setup(data, card_height, text)
	column.add_child(card)
	return card


func _add_button(text: String, action: Callable) -> void:
	frame.add_action(text, action)


func _clear_cards() -> void:
	frame.clear()
