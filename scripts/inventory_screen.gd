class_name InventoryScreen
extends Control
## The full-screen Inventory (opened by the top bar's Inventory button, hosted by the RunInfo autoload).
## From the bottom up: the ROSTER in deck order (a DeckStrip, styled like the deck in combat), a details box for
## whatever was tapped, and above them big colored tabs that fill the rest: Equipment (stored items: drag one onto a
## figure to equip it; tap an equipped item's badge on a figure to unequip it), Powers (each slot has a Discard with a
## short confirm; works anywhere, also in combat) and Relics (read-only, tap for the description).
## Outside combat the roster can be reordered by dragging (that order is the starting positions on the deck).
## In combat reordering and equipping are locked unless the Costume Change relic is held, on your own idle turn (a note says so); viewing and discarding powers still work.

signal closed
signal main_menu_requested
signal powers_changed

const TAB_NAMES := ["Equipment", "Powers", "Relics"]
const TAB_COLORS := [Color(0.9, 0.5, 0.25), Color(0.3, 0.75, 0.45), Color(0.7, 0.45, 0.9)]
const BACKGROUND := Color(0.08, 0.09, 0.13)

@export var tile_size := 210.0
@export var roster_height := 190.0
@export var details_height := 660.0

var _tab := 0
var _pages: Array[Control] = []
var _tab_buttons: Array[Button] = []
var _note := Label.new()
var _details := Label.new()
var _tree_view := UpgradeTreeView.new()  # the selected figure's two upgrade paths
var _unequip_button := Button.new()
var _strip := DeckStrip.new()
var _equipment_grid := GridContainer.new()
var _powers_box := VBoxContainer.new()
var _relics_grid := GridContainer.new()
var _confirming_power := -1  # the power slot whose Discard is waiting for a confirm


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var insets := SafeArea.insets()
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 24.0 + insets.left
	column.offset_right = -(24.0 + insets.right)
	column.offset_top = 16.0 + insets.top
	column.offset_bottom = -(20.0 + insets.bottom)
	column.add_theme_constant_override("separation", 12)
	add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)
	var title := Label.new()
	title.text = "Inventory"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 48)
	header.add_child(title)
	header.add_child(_header_button("Main menu", 250.0, main_menu_requested.emit))
	header.add_child(_header_button("Close", 190.0, closed.emit))

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	column.add_child(tab_row)
	for i in TAB_NAMES.size():
		var button := Button.new()
		button.text = TAB_NAMES[i]
		button.custom_minimum_size = Vector2(0.0, 110.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 36)
		button.pressed.connect(_select_tab.bind(i))
		tab_row.add_child(button)
		_tab_buttons.append(button)

	_note.add_theme_font_size_override("font_size", 26)
	_note.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_note)

	var content := Control.new()  # the pages share this space, one visible at a time
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(content)
	_pages.append(_scrolling_page(content, _equipment_grid, 4))
	_pages.append(_scrolling_page(content, _powers_box, 0))
	_pages.append(_scrolling_page(content, _relics_grid, 5))

	var details_panel := PanelContainer.new()
	details_panel.custom_minimum_size = Vector2(0.0, details_height)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.16, 0.18, 0.24)
	box.set_corner_radius_all(14)
	box.set_content_margin_all(14.0)
	details_panel.add_theme_stylebox_override("panel", box)
	column.add_child(details_panel)
	var details_scroll := ScrollContainer.new()
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details_panel.add_child(details_scroll)
	var details_row := VBoxContainer.new()
	details_row.add_theme_constant_override("separation", 8)
	details_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll.add_child(details_row)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details.add_theme_font_size_override("font_size", 28)
	details_row.add_child(_details)
	_tree_view.box_height = 84.0
	_tree_view.font_size = 22
	_tree_view.hide()
	details_row.add_child(_tree_view)
	_unequip_button.text = "Unequip"
	_unequip_button.custom_minimum_size = Vector2(0.0, 70.0)
	_unequip_button.add_theme_font_size_override("font_size", 30)
	_unequip_button.pressed.connect(_on_unequip_pressed)
	details_row.add_child(_unequip_button)

	_strip.strip_height = roster_height
	_strip.slot_pressed.connect(_on_slot_pressed)
	_strip.item_dropped.connect(_on_item_dropped)
	_strip.item_tapped.connect(_on_item_tapped)
	_strip.reordered.connect(refresh)
	column.add_child(_strip)
	_select_tab(0)


## Rebuilds everything from RunManager (call when the screen opens).
func open(tab := 0, selected = null) -> void:
	_confirming_power = -1
	refresh()
	_select_tab(clampi(tab, 0, TAB_NAMES.size() - 1))
	_details.text = "Tap a figure to see all about it."
	_tree_view.hide()
	_strip.selected = -1
	_unequip_button.hide()
	if selected is RelicData:
		_details.text = _relic_text(selected)


func refresh() -> void:
	var in_combat := RunManager.combat != null
	var equip_locked := not RunManager.equipment_change_allowed()
	_strip.reorderable = not in_combat
	_strip.drop_enabled = not equip_locked
	_note.text = ("In combat: rearranging is locked, and equipping is locked until your turn (Costume Change)." if RunManager.relic_enables_combat_equip()
			else "In combat: rearranging and equipping are locked. You can still look around and discard powers.") if in_combat else "Drag a figure to rearrange the deck. Drag an item onto a figure to equip it; tap an item's badge on a figure to unequip it."
	_strip.refresh()
	_fill_equipment(equip_locked)
	_fill_powers()
	_fill_relics()
	_update_unequip_button()


# --- Pages -----------------------------------------------------------------------------

func _scrolling_page(parent: Control, content: Container, columns: int) -> Control:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if content is GridContainer:
		content.columns = columns
		content.add_theme_constant_override("h_separation", 12)
		content.add_theme_constant_override("v_separation", 12)
	else:
		content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	return scroll


func _select_tab(index: int) -> void:
	_tab = index
	for i in _pages.size():
		_pages[i].visible = i == index
	for i in _tab_buttons.size():
		var active := i == index
		var color: Color = TAB_COLORS[i]
		for state in ["normal", "hover", "pressed", "focus"]:
			var box := StyleBoxFlat.new()
			box.bg_color = color if active else color.darkened(0.6)
			box.set_corner_radius_all(18)
			box.set_border_width_all(6 if active else 2)
			box.border_color = Color(1, 1, 1) if active else color.darkened(0.2)
			_tab_buttons[i].add_theme_stylebox_override(state, box)
		var ink := Color(0.08, 0.08, 0.1) if active else Color(0.85, 0.87, 0.92)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			_tab_buttons[i].add_theme_color_override(state, ink)


func _fill_equipment(equip_locked: bool) -> void:
	_clear(_equipment_grid)
	if RunManager.equipment_inventory.is_empty():
		var empty := Label.new()
		empty.text = "No stored equipment."
		empty.add_theme_font_size_override("font_size", 30)
		_equipment_grid.add_child(empty)
		return
	for item in RunManager.equipment_inventory:
		var tile := EquipTile.new()
		tile.setup(item, tile_size)
		tile.locked = equip_locked
		tile.pressed.connect(func(): _details.text = _equipment_text(item); _tree_view.hide())
		_equipment_grid.add_child(tile)


func _fill_powers() -> void:
	_clear(_powers_box)
	for slot in RunManager.powers.size():
		var power: PowerData = RunManager.powers[slot]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_powers_box.add_child(row)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 30)
		row.add_child(label)
		if power == null:
			label.text = "Slot %d: empty" % (slot + 1)
			label.add_theme_color_override("font_color", Color(0.55, 0.58, 0.66))
		elif _confirming_power == slot:
			label.text = "Discard %s?" % power.display_name
			row.add_child(_row_button("Yes", Color(0.8, 0.35, 0.3), _discard_power.bind(slot)))
			row.add_child(_row_button("No", Color(0.45, 0.48, 0.58), _confirm_power.bind(-1)))
		else:
			label.text = "Slot %d: %s\n%s" % [slot + 1, power.display_name, power.description]
			row.add_child(_row_button("Discard", Color(0.55, 0.3, 0.3), _confirm_power.bind(slot)))


func _fill_relics() -> void:
	_clear(_relics_grid)
	if RunManager.relics.is_empty():
		var empty := Label.new()
		empty.text = "You have no relics yet."
		empty.add_theme_font_size_override("font_size", 30)
		_relics_grid.add_child(empty)
		return
	for relic in RunManager.relics:
		var button := Button.new()
		button.text = relic.label
		button.custom_minimum_size = Vector2(150.0, 150.0)
		button.add_theme_font_size_override("font_size", 56)
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(color_name, Color(0.1, 0.1, 0.12))
		for state in ["normal", "hover", "pressed", "focus"]:
			var box := StyleBoxFlat.new()
			box.bg_color = relic.color
			box.set_corner_radius_all(75)
			box.set_border_width_all(8)
			box.border_color = relic.rarity_color()
			button.add_theme_stylebox_override(state, box)
		button.pressed.connect(func(): _details.text = _relic_text(relic); _tree_view.hide())
		_relics_grid.add_child(button)


# --- Actions ---------------------------------------------------------------------------

func _show_tree(slot: int) -> void:
	_tree_view.show()
	_tree_view.setup(RunManager.deck[slot], RunManager.deck_upgrade[slot])


func _on_slot_pressed(slot: int) -> void:
	_details.text = _figure_text(slot)
	_show_tree(slot)
	_update_unequip_button()


func _on_item_dropped(slot: int, item: EquipmentData) -> void:
	if not RunManager.equipment_change_allowed():
		_flash_locked()
		return
	if RunManager.equip(item, slot):
		_sync_combat(slot)
		refresh()
		_strip.selected = slot
		_details.text = "%s equipped.\n\n%s" % [item.display_name, _figure_text(slot)]
		_show_tree(slot)
		_update_unequip_button()


func _on_item_tapped(slot: int) -> void:
	if not RunManager.equipment_change_allowed():
		_flash_locked()
		return
	_unequip(slot)


func _on_unequip_pressed() -> void:
	if not RunManager.equipment_change_allowed():
		_flash_locked()
		return
	if _strip.selected >= 0:
		_unequip(_strip.selected)


func _unequip(slot: int) -> void:
	var item: EquipmentData = RunManager.deck_equipment[slot]
	if RunManager.unequip(slot):
		_sync_combat(slot)
		refresh()
		_strip.selected = slot
		_details.text = "%s is back in storage.\n\n%s" % [item.display_name, _figure_text(slot)]
		_show_tree(slot)
		_update_unequip_button()


func _confirm_power(slot: int) -> void:
	_confirming_power = slot
	_fill_powers()


func _discard_power(slot: int) -> void:
	RunManager.use_power(slot)  # (the slot becomes empty)
	_confirming_power = -1
	_fill_powers()
	powers_changed.emit()  # (a running combat refreshes its power bar)


## Costume Change: the change shows on the figure in the running combat at once.
func _sync_combat(slot: int) -> void:
	if RunManager.combat != null:
		RunManager.combat.refresh_equipment(slot)


func _flash_locked() -> void:
	_note.text = "Locked during combat."


func _update_unequip_button() -> void:
	var slot := _strip.selected
	var show := slot >= 0 and slot < RunManager.deck.size() and RunManager.deck_equipment[slot] != null
	_unequip_button.visible = show
	_unequip_button.disabled = not RunManager.equipment_change_allowed()
	if show:
		_unequip_button.text = "Unequip %s" % RunManager.deck_equipment[slot].display_name


# --- Texts -----------------------------------------------------------------------------

func _figure_text(slot: int) -> String:
	var figure: FigureData = RunManager.deck[slot]
	var finish: FinishData = RunManager.deck_finish[slot]
	var item: EquipmentData = RunManager.deck_equipment[slot]
	var lines: Array[String] = ["%s (%s)" % [figure.display_name, figure.rarity_name()], figure.description,
			"Mass %.1f, size %d, flick power x%.1f, bounce %.1f" % [figure.mass, figure.radius, figure.flick_power_multiplier, figure.bounce]]
	lines.append("Finish: %s" % ("%s - %s" % [finish.display_name, finish.description] if finish else "none"))
	var summary := RunManager.upgrade_summary(slot)
	lines.append("Upgrades: %s" % (summary if summary != "" else "none"))
	lines.append("Equipment: %s" % ("%s - %s" % [item.display_name, item.description] if item else "none"))
	return "\n".join(lines)


func _equipment_text(item: EquipmentData) -> String:
	return "%s\n%s\n\nDrag it onto a figure below to equip it." % [item.display_name, item.description]


func _relic_text(relic: RelicData) -> String:
	return "%s (%s)\n%s" % [relic.display_name, relic.rarity_name(), relic.description]


# --- Little builders -------------------------------------------------------------------

func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _header_button(text: String, width: float, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 84.0)
	button.add_theme_font_size_override("font_size", 32)
	button.pressed.connect(action)
	return button


func _row_button(text: String, color: Color, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(190.0, 90.0)
	button.add_theme_font_size_override("font_size", 32)
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = color
		box.set_corner_radius_all(14)
		button.add_theme_stylebox_override(state, box)
	button.pressed.connect(action)
	return button
