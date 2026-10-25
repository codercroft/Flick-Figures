extends CanvasLayer
## Bottom-of-screen UI: the turn label and the win/lose panel. main.gd drives it.

@export var your_turn_color := Color(1, 1, 1)
@export var enemy_turn_color := Color(1, 0.45, 0.4)

@onready var turn_label: Label = $TurnLabel
@onready var progress_label: Label = $ProgressLabel
@onready var result_panel: Control = $ResultPanel
@onready var result_label: Label = $ResultPanel/ResultLabel


func show_your_turn(text := "Your turn") -> void:
	turn_label.text = text
	turn_label.add_theme_color_override("font_color", your_turn_color)


func show_enemy_turn() -> void:
	turn_label.text = "Enemy turn"
	turn_label.add_theme_color_override("font_color", enemy_turn_color)


func show_progress(text: String) -> void:
	progress_label.text = text


func show_result(text: String) -> void:
	turn_label.hide()
	progress_label.hide()
	result_label.text = text
	result_panel.show()
