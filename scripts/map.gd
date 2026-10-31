extends Control
## The act map screen: a Slay-the-Spire style branching map, from the first stops at the bottom to the
## boss at the top (MapView draws it and scrolls if the screen is short). Pick one of the glowing next
## stops. Layout: the status bar on top (TopBar), the map filling the middle of the screen, and the
## Equipment / Upgrades buttons pinned at the bottom.

const EQUIP_SCENE := "res://scenes/equip.tscn"
const UPGRADE_SCENE := "res://scenes/upgrade.tscn"
## Height reserved at the bottom for the hint and buttons (before the gesture-bar inset).
const BOTTOM_AREA := 200.0

var top_bar := TopBar.new()
var scroll := ScrollContainer.new()
var view := MapView.new()


func _ready() -> void:
	RunManager.autosave()  # arriving at the map saves the run
	add_child(top_bar)
	var insets := SafeArea.insets()
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = insets.left
	column.offset_right = -insets.right
	column.offset_top = TopBar.height()
	column.offset_bottom = -(16.0 + insets.bottom)
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var available: float = get_viewport_rect().size.y - TopBar.height() - BOTTOM_AREA - insets.bottom
	view.custom_minimum_size = Vector2(0.0, view.required_height(available))
	view.node_tapped.connect(_go_to)
	scroll.add_child(view)

	var hint := Label.new()
	hint.text = "Choose your next stop"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 32)
	hint.add_theme_color_override("font_color", Color(0.6, 0.63, 0.72))
	column.add_child(hint)
	if RunManager.minigame_penalty:
		# A warning while the penalty is set: the next fight is harder.
		var warning := Label.new()
		warning.text = "!  The next fight will be harder"
		warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warning.add_theme_font_size_override("font_size", 32)
		warning.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
		column.add_child(warning)

	# Equip / upgrade buttons, side by side along the bottom (thumb reach).
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	var held := RunManager.equipment_inventory.size()
	var equipment := _bottom_button(buttons, "Equipment (%d)" % held, EQUIP_SCENE)
	if held > 0:
		equipment.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	if RunManager.config.show_upgrade_screen:
		_bottom_button(buttons, "Upgrades", UPGRADE_SCENE)
	_scroll_to_position.call_deferred()


func _bottom_button(parent: Control, text: String, scene: String) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, 92.0)
	button.add_theme_font_size_override("font_size", 36)
	button.pressed.connect(func(): get_tree().change_scene_to_file(scene))
	parent.add_child(button)
	return button


## Start looking at where you are: the bottom at the start of an act, otherwise around your node.
func _scroll_to_position() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var target := view.size.y  # the bottom
	if RunManager.current_node != -1:
		target = view.node_center(RunManager.map.nodes[RunManager.current_node]).y + scroll.size.y * 0.35
	scroll.scroll_vertical = int(clampf(target - scroll.size.y, 0.0, view.size.y))


func _go_to(id: int) -> void:
	if not RunManager.enter_node(id):
		return
	NodeScenes.open_current_node(get_tree())
