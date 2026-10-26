extends Control
## The equip screen: pick an item you hold, then pick which figure gets it. If that figure already
## holds an item, the old one goes back to the inventory. The choices scroll in the middle of the screen; Done/Back are pinned at the bottom.

const MAP_SCENE := "res://scenes/map.tscn"
const ITEM_CARD_HEIGHT := 120.0
const FIGURE_CARD_HEIGHT := 135.0

var _chosen: EquipmentData

var frame := ScreenFrame.new()
var column: VBoxContainer
var title: Label


func _ready() -> void:
	add_child(frame)
	column = frame.content
	title = frame.title
	_show_items()


func _show_items(message := "") -> void:
	_clear_cards()
	title.text = message if message != "" else "Pick an item to equip"
	if RunManager.equipment_inventory.is_empty() and message == "":
		title.text = "No unequipped items"
	for item in RunManager.equipment_inventory:
		var card := _add_card(null, "%s\n%s" % [item.display_name, item.description], ITEM_CARD_HEIGHT)
		card.pressed.connect(_on_item_chosen.bind(item))
	_add_button("Done", _leave)


func _on_item_chosen(item: EquipmentData) -> void:
	_chosen = item
	_clear_cards()
	title.text = "Give %s to which figure?" % _chosen.display_name
	for slot in RunManager.deck.size():
		var figure: FigureData = RunManager.deck[slot]
		var held: EquipmentData = RunManager.deck_equipment[slot]
		var text := figure.display_name + ("\nholds: %s (goes back)" % held.display_name if held != null else "\nno item")
		var card := _add_card(figure, text, FIGURE_CARD_HEIGHT)
		card.pressed.connect(_on_figure_chosen.bind(slot))
	_add_button("Back", _show_items)


func _on_figure_chosen(slot: int) -> void:
	var figure_name := RunManager.deck[slot].display_name
	RunManager.equip(_chosen, slot)
	_show_items("%s now carries %s" % [figure_name, _chosen.display_name])


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
