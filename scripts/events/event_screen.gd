class_name EventScreen
extends Control
## Base class for event scenes. Gives you a ScreenFrame (`frame`: title, subtitle, scrolling cards in the
## middle, buttons at the bottom) and `leave()` / `show_result()` to end the event. An event never changes
## the map by itself: finishing it just marks the node as visited and returns to the map.

const MAP_SCENE := "res://scenes/map.tscn"

var frame := ScreenFrame.new()
var _done := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	start()


## Override: build the first screen of the event.
func start() -> void:
	pass


## Ends the event and goes back to the map.
func leave() -> void:
	if _done:
		return
	_done = true
	RunManager.finish_node()
	get_tree().change_scene_to_file(MAP_SCENE)


## Shows what happened and a Continue button that ends the event.
func show_result(text: String) -> void:
	frame.clear()
	frame.title.text = "Done"
	frame.subtitle.text = text
	frame.add_action("Continue", leave)


## A tappable card. `figure` (or null) gives the picture and rarity border.
func add_card(text: String, figure: FigureData, height: float, callback: Callable, disabled := false, font_size := 30) -> FigureCard:
	var card := FigureCard.new()
	card.setup(figure, height, text, font_size)
	card.disabled = disabled
	card.pressed.connect(callback)
	frame.content.add_child(card)
	return card
