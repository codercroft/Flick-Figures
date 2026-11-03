extends CanvasLayer
## The overlay host (autoload "RunInfo"). Two overlays, both opened from the top bar:
##  - the MAP: this act's map as a view-only overlay showing where you are (Close returns to where you were);
##  - the INVENTORY: a full screen (InventoryScreen) with the roster, equipment, powers and relics.
## Opening either changes nothing by itself (the Inventory edits the deck only through its own controls, outside
## combat). Combat input is ignored while one is open (`is_open`, see main.gd).

## Emitted when a power is discarded in the Inventory (a running combat refreshes its power bar).
signal powers_changed

## True while an overlay is showing (main.gd ignores touches then).
var is_open := false

var _map_root := Control.new()
var _map_panel := PanelContainer.new()
var _map_mini := MapMini.new()
var _map_detail := Label.new()
var _inventory := InventoryScreen.new()


func _ready() -> void:
	layer = 100
	_build_map_overlay()
	_inventory.visible = false
	_inventory.closed.connect(close_overlay)
	_inventory.main_menu_requested.connect(_go_to_main_menu)
	_inventory.powers_changed.connect(powers_changed.emit)
	add_child(_inventory)


## Opens the view-only map overlay.
func open_map() -> void:
	_map_root.visible = true
	_inventory.visible = false
	is_open = true
	_map_detail.text = "Tap a stop to see what it is.\nGreen = done, glowing = you can go there next, white ring = where you are."


## Opens the full-screen Inventory on a tab (0 Equipment, 1 Powers, 2 Relics); `selected` may be a relic to show.
func open_inventory(tab := 0, selected = null) -> void:
	_map_root.visible = false
	_inventory.visible = true
	is_open = true
	_inventory.open(tab, selected)


func close_overlay() -> void:
	_map_root.visible = false
	_inventory.visible = false
	is_open = false


## Saves and goes to the main menu. On the map the run is saved as it is now; inside a combat, shop or event the
## last save stays (it remembers that node, so Continue restarts it from the start).
func _go_to_main_menu() -> void:
	RunManager.autosave()
	close_overlay()
	get_tree().change_scene_to_file(NodeScenes.MENU_SCENE)


# --- The map overlay -------------------------------------------------------------------

func _build_map_overlay() -> void:
	add_child(_map_root)
	_map_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_root.visible = false
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.gui_input.connect(_on_dim_input)
	_map_root.add_child(dim)
	var insets := SafeArea.insets()
	_map_panel.anchor_right = 1.0
	_map_panel.anchor_bottom = 1.0
	_map_panel.offset_left = 28.0 + insets.left
	_map_panel.offset_right = -(28.0 + insets.right)
	_map_panel.offset_top = 70.0 + insets.top
	_map_panel.offset_bottom = -(70.0 + insets.bottom)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.11, 0.12, 0.16)
	box.set_corner_radius_all(24)
	box.set_border_width_all(3)
	box.border_color = Color(0.3, 0.33, 0.42)
	box.set_content_margin_all(18.0)
	_map_panel.add_theme_stylebox_override("panel", box)
	_map_root.add_child(_map_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_map_panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var heading := Label.new()
	heading.text = "Map"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 44)
	header.add_child(heading)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(190.0, 84.0)
	close.add_theme_font_size_override("font_size", 36)
	close.pressed.connect(close_overlay)
	header.add_child(close)
	_map_mini.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_mini.custom_minimum_size = Vector2(0.0, 500.0)
	_map_mini.node_picked.connect(_on_map_node_picked)
	column.add_child(_map_mini)
	var holder := PanelContainer.new()
	holder.custom_minimum_size = Vector2(0.0, 220.0)
	var detail_box := StyleBoxFlat.new()
	detail_box.bg_color = Color(0.16, 0.18, 0.24)
	detail_box.set_corner_radius_all(14)
	detail_box.set_content_margin_all(14.0)
	holder.add_theme_stylebox_override("panel", detail_box)
	_map_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_map_detail.add_theme_font_size_override("font_size", 30)
	holder.add_child(_map_detail)
	column.add_child(holder)


func _on_dim_input(event: InputEvent) -> void:
	# A tap outside the panel closes it.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _map_panel.get_global_rect().has_point(event.position):
			close_overlay()


func _on_map_node_picked(node: MapNode) -> void:
	var text: String = MapIcons.DESCRIPTIONS[node.type]
	if node.type == MapNode.Type.BOSS:
		text = "Boss: %s. %s" % [RunManager.boss.display_name, RunManager.boss.description]
	var state := "You are here." if node.id == RunManager.current_node else ("Done." if node.visited else ("You can go here next." if RunManager.reachable_nodes().has(node.id) else "Not reachable yet."))
	_map_detail.text = "%s\n%s" % [text, state]
