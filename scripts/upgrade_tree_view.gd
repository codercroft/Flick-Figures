class_name UpgradeTreeView
extends VBoxContainer
## A figure's upgrade tree drawn as two rows of three boxes (one row per path). Box colors: owned (green),
## available (gold), locked (grey). Tap a box to read its description; `box_selected` tells the parent which one.
## Used by the Inventory, the Compendium figure page and the Upgrade reward step.

signal box_selected(path: int, tier: int, state: String)

const OWNED := Color(0.55, 1.0, 0.6)
const AVAILABLE := Color(1.0, 0.88, 0.35)
const LOCKED := Color(0.5, 0.5, 0.56)

@export var box_height := 120.0
@export var font_size := 26

var selected := Vector2i(-1, 0)  # (path, tier) of the tapped box
var _boxes: Array[Dictionary] = []
var _buttons := {}
var _tree: UpgradeTree
var _description: Label


## `state` = (path, tier) the figure has now (RunManager.NO_UPGRADE for none).
func setup(figure: FigureData, state: Vector2i) -> void:
	for child in get_children():
		child.queue_free()
	_buttons.clear()
	_tree = RunManager.tree_for(figure)
	if _tree == null:
		var none := Label.new()
		none.text = "No upgrades for this figure."
		add_child(none)
		return
	_boxes = RunManager.upgrade_boxes(figure, state)
	add_theme_constant_override("separation", 6)
	for path in 2:
		var title := Label.new()
		title.text = "%s%s" % [_tree.path_name(path), "  (locked)" if state.x >= 0 and state.x != path else ""]
		title.add_theme_font_size_override("font_size", font_size)
		add_child(title)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		add_child(row)
		for box in _boxes:
			if box.path != path:
				continue
			var button := Button.new()
			button.text = "%d\n%s" % [box.tier, box.upgrade.display_name]
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size = Vector2(0.0, box_height)
			button.add_theme_font_size_override("font_size", font_size)
			button.modulate = {"owned": OWNED, "available": AVAILABLE, "locked": LOCKED}[box.state]
			button.pressed.connect(_on_box.bind(box.path, box.tier))
			row.add_child(button)
			_buttons[Vector2i(box.path, box.tier)] = button
	_description = Label.new()
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.add_theme_font_size_override("font_size", font_size)
	_description.custom_minimum_size = Vector2(0.0, 110.0)
	_description.text = "Tap a box for details."
	add_child(_description)


func _on_box(path: int, tier: int) -> void:
	selected = Vector2i(path, tier)
	for key in _buttons:
		_buttons[key].self_modulate = Color(1.3, 1.3, 1.3) if key == selected else Color.WHITE
	var box := _box(path, tier)
	_description.text = "%s (tier %d, %s)\n%s" % [box.upgrade.display_name, tier, box.state, box.upgrade.description]
	box_selected.emit(path, tier, box.state)


func _box(path: int, tier: int) -> Dictionary:
	for box in _boxes:
		if box.path == path and box.tier == tier:
			return box
	return {}


## The state ("owned", "available", "locked") of the tapped box, or "".
func selected_state() -> String:
	return _box(selected.x, selected.y).get("state", "")
