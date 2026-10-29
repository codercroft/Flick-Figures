class_name CurlingMinigame
extends VersusMinigame
## Curling: a target is drawn at the far end of an open table. You and the AI take turns flicking 2
## Grunts each, both wearing Banana Peels so they slide a long way (a light flick goes far; a hard one
## sails off the table). The Grunt nearest the center of the target wins.

@export_group("Target")
## Center of the target, this far (px) below the top edge of the table.
@export var target_distance_from_top := 330.0
## Ring radii from the outside in, and their colors.
@export var ring_radii: Array[float] = [250.0, 175.0, 100.0, 35.0]
@export var ring_colors: Array[Color] = [Color(0.25, 0.45, 0.85), Color(0.95, 0.95, 0.95), Color(0.85, 0.2, 0.2), Color(0.95, 0.95, 0.95)]
@export var banana_peel: EquipmentData = preload("res://resources/equipment/banana_peel.tres")


func _init() -> void:
	stones_each = 2


func _goal() -> Vector2:
	return Vector2(board_rect.get_center().x, board_rect.position.y + target_distance_from_top)


func _item() -> EquipmentData:
	return banana_peel


func _draw_table() -> void:
	for i in ring_radii.size():
		draw_circle(_goal(), ring_radii[i], ring_colors[i % ring_colors.size()])
	draw_arc(_goal(), ring_radii[0], 0.0, TAU, 64, Color(0, 0, 0, 0.35), 5.0, true)


func _setup_table() -> void:
	status_label.text = "Slidey Grunts! Aim for the center."
	await get_tree().create_timer(0.6).timeout
