class_name TopBar
extends CanvasLayer
## The status bar at the top of every screen: an Info button (opens the run info overlay), which
## act and stop you are on, your relic icons and your money. It sits below the camera cutout
## (SafeArea). Add one to a scene with `add_child(TopBar.new())`.

const BAR_HEIGHT := 104.0
const BACKGROUND := Color(0.08, 0.09, 0.12, 0.97)

var _panel := PanelContainer.new()
var _act_label := Label.new()
var _money_label := Label.new()
var _relics := RelicBar.new()
var _relic_count := -1


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

	var info := Button.new()
	info.text = "i"
	info.custom_minimum_size = Vector2(72.0, 72.0)
	info.add_theme_font_size_override("font_size", 40)
	info.pressed.connect(RunInfo.open.bind("map", null))
	row.add_child(info)

	_act_label.add_theme_font_size_override("font_size", 30)
	_act_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	_act_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_act_label)

	_relics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_relics.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_relics)

	_money_label.add_theme_font_size_override("font_size", 40)
	_money_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	_money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_money_label)
	refresh()


func _process(_delta: float) -> void:
	refresh()


## Updates the texts (cheap: called every frame).
func refresh() -> void:
	var where := "Act %d/%d" % [RunManager.act + 1, RunManager.config.acts]
	if RunManager.node != null:
		if RunManager.node.type == MapNode.Type.BOSS:
			where += "  Boss"
		else:
			where += "  " + MapNode.type_name(RunManager.node.type)
	_act_label.text = where
	_money_label.text = "$%d" % RunManager.money
	if _relic_count != RunManager.relics.size():
		_relic_count = RunManager.relics.size()
		_relics.refresh()


## How tall the bar is on this device (including the cutout), in game units.
static func height() -> float:
	return SafeArea.insets().top + BAR_HEIGHT


## True if a screen position is over the bar (so combat doesn't treat it as aiming).
func is_over(screen_pos: Vector2) -> bool:
	return _panel.get_global_rect().has_point(screen_pos)
