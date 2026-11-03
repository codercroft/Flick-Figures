class_name DeckStrip
extends Control
## The player's deck drawn as one row of figure slots, in the same order as the deck strip in combat (slot 1 is the
## leftmost starting position). Used by the run info Roster tab and by the reward and shop "which figure?" screens.
## `reorderable`: press and drag a figure sideways to move it to another slot (the order is saved with the run).
## A plain tap selects the slot and emits `slot_pressed`.

signal slot_pressed(slot: int)
signal reordered

## Drag to rearrange (only outside combat).
@export var reorderable := false
## Height of the strip in px.
@export var strip_height := 190.0
## A press must move this far (px) sideways before it counts as a drag.
@export var drag_slop := 16.0

## Highlighted slot (-1 = none).
var selected := -1:
	set(value):
		selected = value
		queue_redraw()

var _badges: Array[FigureBadge] = []
var _down := -1
var _down_x := 0.0
var _dragging := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	custom_minimum_size = Vector2(0.0, strip_height)
	resized.connect(_layout)
	refresh()


## Rebuilds the slots from the run's deck.
func refresh() -> void:
	for badge in _badges:
		badge.queue_free()
	_badges.clear()
	for slot in RunManager.deck.size():
		var badge := FigureBadge.new()
		badge.data = RunManager.deck[slot]
		badge.upgraded = RunManager.deck_upgrade[slot] != null
		badge.item_label = RunManager.deck_equipment[slot].label if RunManager.deck_equipment[slot] != null else ""
		add_child(badge)
		_badges.append(badge)
	_layout()
	queue_redraw()


func slot_width() -> float:
	return size.x / maxi(_badges.size(), 1)


func _slot_rect(slot: int) -> Rect2:
	return Rect2(slot_width() * slot, 0.0, slot_width(), size.y)


func _layout() -> void:
	var side := minf(slot_width() - 6.0, size.y - 6.0)
	for i in _badges.size():
		if _dragging and i == _down:
			continue
		var rect := _slot_rect(i)
		_badges[i].size = Vector2(side, side)
		_badges[i].position = rect.get_center() - Vector2(side, side) / 2.0
	queue_redraw()


func _slot_at(x: float) -> int:
	return clampi(int(x / slot_width()), 0, maxi(_badges.size() - 1, 0))


func _draw() -> void:
	for i in _badges.size():
		var rect := _slot_rect(i).grow(-3.0)
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.2, 0.22, 0.3) if i != selected else Color(0.3, 0.34, 0.5)
		box.set_corner_radius_all(14)
		if i == selected:
			box.set_border_width_all(4)
			box.border_color = Color(1.0, 0.9, 0.3)
		draw_style_box(box, rect)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(10.0, 26.0), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT,
				-1, 22, Color(1, 1, 1, 0.45))


func _gui_input(event: InputEvent) -> void:
	if _badges.is_empty():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = _slot_at(event.position.x)
			_down_x = event.position.x
			_dragging = false
		else:
			_release(event.position.x)
	elif event is InputEventMouseMotion and _down >= 0 and reorderable:
		if not _dragging and absf(event.position.x - _down_x) > drag_slop:
			_dragging = true
			_badges[_down].z_index = 10
			selected = _down
		if _dragging:
			var badge := _badges[_down]
			badge.position.x = clampf(event.position.x - badge.size.x / 2.0, 0.0, size.x - badge.size.x)


func _release(x: float) -> void:
	var from := _down
	var was_dragging := _dragging
	_down = -1
	_dragging = false
	if from < 0:
		return
	if was_dragging:
		_badges[from].z_index = 0
		var to := _slot_at(x)
		RunManager.move_deck_slot(from, to)
		selected = to
		refresh()
		reordered.emit()
		slot_pressed.emit(to)
	else:
		selected = from
		slot_pressed.emit(from)


## One line about a slot for the pickers: what is there and what would be lost by replacing it.
static func describe_slot(slot: int, replacing := true) -> String:
	var figure: FigureData = RunManager.deck[slot]
	var extras: Array[String] = []
	if RunManager.deck_finish[slot] != null:
		extras.append("finish " + RunManager.deck_finish[slot].display_name)
	if RunManager.deck_upgrade[slot] != null:
		extras.append("upgrade " + RunManager.deck_upgrade[slot].display_name)
	var text := "%s (%s)" % [figure.display_name, figure.rarity_name()]
	if replacing:
		if not extras.is_empty():
			text += "\nLoses its " + " and ".join(extras)
		if RunManager.deck_equipment[slot] != null:
			text += "\n%s goes back to your inventory" % RunManager.deck_equipment[slot].display_name
	else:
		if RunManager.deck_equipment[slot] != null:
			extras.append("item " + RunManager.deck_equipment[slot].display_name)
		if not extras.is_empty():
			text += "\nHas " + ", ".join(extras)
	return text
