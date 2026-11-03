class_name TopBar
extends CanvasLayer
## The status bar at the top of every screen: a Map button (view-only map overlay), an Inventory button
## (full-screen roster, equipment, powers and relics), which act and map row you are on, the Ascension level
## and your money. It sits below the camera cutout (SafeArea). Add one to a scene with `add_child(TopBar.new())`.

const BAR_HEIGHT := 104.0
const BACKGROUND := Color(0.08, 0.09, 0.12, 0.97)

var _panel := PanelContainer.new()
var _act_label := Label.new()
var _money_label := Label.new()
var _sound_button := Button.new()  # sound on / off, saved between sessions (AudioManager)


func _ready() -> void:
	layer = 20
	var insets := SafeArea.insets()
	_panel.anchor_right = 1.0
	_panel.offset_bottom = insets.top + BAR_HEIGHT
	var box := StyleBoxFlat.new()
	box.bg_color = BACKGROUND
	box.border_width_bottom = 3
	box.border_color = Color(0.25, 0.27, 0.34)
	box.content_margin_left = 20.0 + insets.left
	box.content_margin_right = 20.0 + insets.right
	box.content_margin_top = insets.top + 8.0
	box.content_margin_bottom = 8.0
	_panel.add_theme_stylebox_override("panel", box)
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_panel.add_child(row)

	var map_button := Button.new()
	map_button.text = "Map"
	map_button.custom_minimum_size = Vector2(130.0, 72.0)
	map_button.add_theme_font_size_override("font_size", 32)
	map_button.pressed.connect(RunInfo.open_map)
	row.add_child(map_button)

	var inventory := Button.new()
	inventory.text = "Inventory"
	inventory.custom_minimum_size = Vector2(190.0, 72.0)
	inventory.add_theme_font_size_override("font_size", 32)
	inventory.pressed.connect(RunInfo.open_inventory)
	row.add_child(inventory)

	_sound_button.custom_minimum_size = Vector2(72.0, 72.0)
	_sound_button.add_theme_font_size_override("font_size", 22)
	_sound_button.add_to_group("no_ui_sound")  # (it plays its own tap when it turns sound on)
	_sound_button.pressed.connect(AudioManager.toggle_mute)
	row.add_child(_sound_button)

	_act_label.add_theme_font_size_override("font_size", 28)
	_act_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_act_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_act_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	_act_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_act_label)

	_money_label.add_theme_font_size_override("font_size", 40)
	_money_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	_money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_money_label)
	refresh()


func _process(_delta: float) -> void:
	refresh()


## Updates the texts (cheap: called every frame).
func refresh() -> void:
	_act_label.text = _where_text()
	_money_label.text = "$%d" % RunManager.money
	_sound_button.text = "OFF" if AudioManager.muted else "SND"
	_sound_button.modulate = Color(1.0, 0.55, 0.55) if AudioManager.muted else Color.WHITE


## "Act 2/3  Row 4  A5": the act, the map row you are on (the node being played, else the last one you finished)
## and the Ascension level.
func _where_text() -> String:
	var text := "Act %d/%d" % [RunManager.act + 1, RunManager.config.acts]
	var shown: MapNode = RunManager.node
	if shown == null and RunManager.current_node >= 0 and RunManager.map != null:
		shown = RunManager.map.nodes[RunManager.current_node]
	if shown != null:
		text += "  Boss" if shown.type == MapNode.Type.BOSS else "  Row %d" % (shown.column + 1)
	if RunManager.ascension > 0:
		text += "  A%d" % RunManager.ascension
	return text


## How tall the bar is on this device (including the cutout), in game units.
static func height() -> float:
	return SafeArea.insets().top + BAR_HEIGHT


## True if a screen position is over the bar (so combat doesn't treat it as aiming).
func is_over(screen_pos: Vector2) -> bool:
	return _panel.get_global_rect().has_point(screen_pos)
