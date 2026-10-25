extends CanvasLayer
## Bottom-of-screen UI: the turn label and the win/lose panel. main.gd drives it.

@export var your_turn_color := Color(1, 1, 1)
@export var enemy_turn_color := Color(1, 0.45, 0.4)

## A power slot button was pressed (slot index).
signal power_pressed(slot: int)

@onready var power_bar: HBoxContainer = $PowerBar
@onready var relic_bar: RelicBar = $RelicBar
@onready var turn_label: Label = $TurnLabel
@onready var progress_label: Label = $ProgressLabel
@onready var debug_label: Label = $DebugLabel
@onready var arena_label: Label = $ArenaLabel
@onready var result_panel: Control = $ResultPanel
@onready var result_label: Label = $ResultPanel/ResultLabel


func show_your_turn(text := "Your turn") -> void:
	turn_label.text = text
	turn_label.add_theme_color_override("font_color", your_turn_color)


func show_enemy_turn() -> void:
	turn_label.text = "Enemy turn"
	turn_label.add_theme_color_override("font_color", enemy_turn_color)


## Shows the arena's name big in the middle of the lower half, then fades it out.
func show_arena_name(text: String) -> void:
	arena_label.text = text
	arena_label.modulate.a = 0.0
	arena_label.show()
	var tween := create_tween()
	tween.tween_property(arena_label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.4)
	tween.tween_property(arena_label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(arena_label.hide)


## Small orange readout (empty text hides it). Used to show what the turn is waiting for.
func show_debug(text: String) -> void:
	debug_label.text = text
	debug_label.visible = text != ""


func show_progress(text: String) -> void:
	progress_label.text = text


func show_result(text: String) -> void:
	power_bar.hide()
	relic_bar.hide()
	turn_label.hide()
	progress_label.hide()
	result_label.text = text
	result_panel.show()


# --- Power bar (bottom of the screen) ---------------------------------------

var _power_buttons: Array[Button] = []


## Shows the player's power slots. `active_slot` is highlighted (the power waiting for a target).
func set_powers(powers: Array, active_slot := -1) -> void:
	for button in _power_buttons:
		button.queue_free()
	_power_buttons.clear()
	for i in powers.size():
		var power: PowerData = powers[i]
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 28)
		button.disabled = power == null
		button.text = "Empty" if power == null else power.display_name
		var color := Color(0.18, 0.19, 0.24) if power == null else power.color.darkened(0.45)
		var border := Color(1.0, 0.9, 0.3) if i == active_slot else color.lightened(0.25)
		for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(style_name, _power_box(color, border, i == active_slot))
		button.add_theme_color_override("font_disabled_color", Color(0.45, 0.47, 0.53))
		button.pressed.connect(power_pressed.emit.bind(i))
		power_bar.add_child(button)
		_power_buttons.append(button)


## Powers can only be used on the player's turn: grey the bar out otherwise.
func set_powers_enabled(enabled: bool) -> void:
	power_bar.modulate.a = 1.0 if enabled else 0.45
	for button in _power_buttons:
		button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


## True if a screen position is over the power bar or the relic icons (so main.gd doesn't treat
## it as aiming).
func is_over_power_bar(screen_pos: Vector2) -> bool:
	if relic_bar.is_over(screen_pos):
		return true
	return power_bar.visible and power_bar.get_global_rect().has_point(screen_pos)


func _power_box(background: Color, border: Color, thick: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.set_corner_radius_all(14)
	box.set_border_width_all(6 if thick else 3)
	box.border_color = border
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	return box
