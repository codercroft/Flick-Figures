extends CanvasLayer
## The run info overlay (autoload "RunInfo"): a button in the top bar opens it on any screen. Tabs: Map
## (this act's map with your position), Roster (each figure with finish, upgrade, equipment and a short
## ability description), Relics, Powers and Inventory (unequipped equipment). Tap any entry to read its
## full description. Tap outside the panel or the Close button to go back. Opening it changes NO game
## state: it only reads RunManager (combat input is ignored while it is open, see `is_open`).

const TAB_NAMES := ["map", "roster", "relics", "powers", "inventory"]
## One color per tab (the tab buttons and their highlight).
const TAB_COLORS := [Color(0.25, 0.6, 0.85), Color(0.9, 0.5, 0.25), Color(0.7, 0.45, 0.9), Color(0.3, 0.75, 0.45), Color(0.85, 0.7, 0.2)]

## True while the overlay is showing (main.gd ignores touches then).
var is_open := false

var _root := Control.new()
var _dim := ColorRect.new()
var _panel := PanelContainer.new()
var _tabs := TabContainer.new()
var _map_mini := MapMini.new()
var _map_detail := Label.new()
var _pages := {}  # tab name -> {list: VBoxContainer, detail: Label}
var _tab_buttons: Array[Button] = []


func _ready() -> void:
	layer = 100
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false

	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.0, 0.0, 0.0, 0.72)
	_dim.gui_input.connect(_on_dim_input)
	_root.add_child(_dim)

	var insets := SafeArea.insets()
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 28.0 + insets.left
	_panel.offset_right = -(28.0 + insets.right)
	_panel.offset_top = 70.0 + insets.top
	_panel.offset_bottom = -(70.0 + insets.bottom)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.11, 0.12, 0.16)
	box.set_corner_radius_all(24)
	box.set_border_width_all(3)
	box.border_color = Color(0.3, 0.33, 0.42)
	box.set_content_margin_all(18.0)
	_panel.add_theme_stylebox_override("panel", box)
	_root.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var heading := Label.new()
	heading.text = "Run info"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 44)
	header.add_child(heading)
	var menu := Button.new()
	menu.text = "Main menu"
	menu.custom_minimum_size = Vector2(260.0, 84.0)
	menu.add_theme_font_size_override("font_size", 32)
	menu.pressed.connect(_go_to_main_menu)
	header.add_child(menu)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(190.0, 84.0)
	close.add_theme_font_size_override("font_size", 36)
	close.pressed.connect(close_overlay)
	header.add_child(close)

	# Big colored tab buttons (the TabContainer's own small tab bar is hidden).
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	column.add_child(tab_row)
	for i in TAB_NAMES.size():
		var button := Button.new()
		button.text = TAB_NAMES[i].capitalize()
		button.custom_minimum_size = Vector2(0.0, 100.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 28)
		button.pressed.connect(_select_tab.bind(i))
		tab_row.add_child(button)
		_tab_buttons.append(button)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.tabs_visible = false
	column.add_child(_tabs)
	_build_map_page()
	for tab in ["roster", "relics", "powers", "inventory"]:
		_pages[tab] = _build_list_page(tab.capitalize())


## Opens the overlay on a tab ("map", "roster", "relics", "powers", "inventory"). `selected` can be a
## relic (or anything with a description) to show right away.
func open(tab := "map", selected = null) -> void:
	_root.visible = true  # show first so the cards lay out at the real width
	is_open = true
	_refresh_all()
	_select_tab(maxi(TAB_NAMES.find(tab), 0))
	if selected is RelicData:
		_pages.relics.detail.text = _relic_text(selected)


## Shows one page and highlights its button: the active tab is bright with a white border, the others dim.
func _select_tab(index: int) -> void:
	_tabs.current_tab = index
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


## Saves and goes to the main menu. On the map the run is saved as it is now; inside a combat, shop or event the
## last save stays (it remembers that node, so Continue restarts it from the start).
func _go_to_main_menu() -> void:
	RunManager.autosave()
	close_overlay()
	get_tree().change_scene_to_file(NodeScenes.MENU_SCENE)


func close_overlay() -> void:
	_root.visible = false
	is_open = false


func _on_dim_input(event: InputEvent) -> void:
	# A tap outside the panel closes it.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _panel.get_global_rect().has_point(event.position):
			close_overlay()


# --- Pages ------------------------------------------------------------------------

func _build_map_page() -> void:
	var page := VBoxContainer.new()
	page.name = "Map"
	page.add_theme_constant_override("separation", 10)
	_tabs.add_child(page)
	_map_mini.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_mini.custom_minimum_size = Vector2(0.0, 500.0)
	_map_mini.node_picked.connect(_on_map_node_picked)
	page.add_child(_map_mini)
	_map_detail = _detail_label()
	page.add_child(_detail_box(_map_detail))


## A page with a scrolling list on top and a description box at the bottom.
func _build_list_page(tab_name: String) -> Dictionary:
	var page := VBoxContainer.new()
	page.name = tab_name
	page.add_theme_constant_override("separation", 10)
	_tabs.add_child(page)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var detail := _detail_label()
	page.add_child(_detail_box(detail))
	return {"list": list, "detail": detail}


func _detail_label() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 30)
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return label


func _detail_box(label: Label) -> PanelContainer:
	var holder := PanelContainer.new()
	holder.custom_minimum_size = Vector2(0.0, 300.0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.16, 0.18, 0.24)
	box.set_corner_radius_all(14)
	box.set_content_margin_all(14.0)
	holder.add_theme_stylebox_override("panel", box)
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_child(label)
	return holder


# --- Filling the pages from RunManager (read only) -----------------------------------

func _refresh_all() -> void:
	_map_detail.text = "Tap a stop to see what it is.\nGreen = done, glowing = you can go there next, white ring = where you are."
	_fill_roster()
	_fill_relics()
	_fill_powers()
	_fill_inventory()


func _clear(page: Dictionary, hint: String) -> void:
	for child in page.list.get_children():
		page.list.remove_child(child)
		child.queue_free()
	page.detail.text = hint


func _row(page: Dictionary, data: FigureData, text: String, detail: String, height := 110.0, font_size := 0) -> void:
	var card := FigureCard.new()
	card.setup(data, height, text, font_size)
	card.pressed.connect(func(): page.detail.text = detail)
	page.list.add_child(card)


func _fill_roster() -> void:
	var page: Dictionary = _pages.roster
	_clear(page, "Tap a figure to read all about it.")
	for slot in RunManager.deck.size():
		var figure: FigureData = RunManager.deck[slot]
		var finish: FinishData = RunManager.deck_finish[slot]
		var upgrade: UpgradeData = RunManager.deck_upgrade[slot]
		var item: EquipmentData = RunManager.deck_equipment[slot]
		# A tall card with one line per thing (the list scrolls): name and rarity, ability, then the gear.
		var summary := "%s (%s)\n%s" % [figure.display_name, figure.rarity_name(), figure.description]
		var gear := "Finish: %s\nUpgrade: %s\nItem: %s" % [finish.display_name if finish else "none",
				upgrade.display_name if upgrade else "none", item.display_name if item else "none"]
		_row(page, figure, summary + "\n" + gear, _figure_text(figure, finish, upgrade, item), 330.0, 28)


func _figure_text(figure: FigureData, finish: FinishData, upgrade: UpgradeData, item: EquipmentData) -> String:
	var lines: Array[String] = ["%s (%s)" % [figure.display_name, figure.rarity_name()], figure.description,
			"Mass %.1f, size %d, flick power x%.1f, bounce %.1f" % [figure.mass, figure.radius, figure.flick_power_multiplier, figure.bounce]]
	lines.append("Finish: %s" % ("%s - %s" % [finish.display_name, finish.description] if finish else "none"))
	lines.append("Upgrade: %s" % ("%s - %s" % [upgrade.display_name, upgrade.description] if upgrade else "none"))
	lines.append("Equipment: %s" % ("%s - %s" % [item.display_name, item.description] if item else "none"))
	return "\n".join(lines)


func _fill_relics() -> void:
	var page: Dictionary = _pages.relics
	_clear(page, "Tap a relic to read what it does." if not RunManager.relics.is_empty() else "You have no relics yet.")
	for relic in RunManager.relics:
		_row(page, null, "[%s] %s (%s)" % [relic.label, relic.display_name, relic.rarity_name()], _relic_text(relic))


func _relic_text(relic: RelicData) -> String:
	return "%s (%s)\n%s" % [relic.display_name, relic.rarity_name(), relic.description]


func _fill_powers() -> void:
	var page: Dictionary = _pages.powers
	_clear(page, "Tap a power to read what it does. Powers are used up in combat.")
	for slot in RunManager.powers.size():
		var power: PowerData = RunManager.powers[slot]
		if power == null:
			_row(page, null, "Slot %d: empty" % (slot + 1), "An empty power slot.")
		else:
			_row(page, null, "Slot %d: %s" % [slot + 1, power.display_name], "%s\n%s" % [power.display_name, power.description])


func _fill_inventory() -> void:
	var page: Dictionary = _pages.inventory
	_clear(page, "Tap an item to read it. Equip items from the map's Equipment button.")
	if RunManager.equipment_inventory.is_empty():
		page.detail.text = "No unequipped equipment."
	for item in RunManager.equipment_inventory:
		_row(page, null, "[%s] %s" % [item.label, item.display_name], "%s\n%s" % [item.display_name, item.description])


func _on_map_node_picked(node: MapNode) -> void:
	var text: String = MapIcons.DESCRIPTIONS[node.type]
	if node.type == MapNode.Type.BOSS:
		text = "Boss: %s. %s" % [RunManager.boss.display_name, RunManager.boss.description]
	var state := "You are here." if node.id == RunManager.current_node else ("Done." if node.visited else ("You can go here next." if RunManager.reachable_nodes().has(node.id) else "Not reachable yet."))
	_map_detail.text = "%s\n%s" % [text, state]
