extends Node2D
## Draws the board and the deck strip, and holds their sizes for other scripts.
## Edges are open: main.gd knocks off any figure whose center leaves board_rect.

@export var board_rect := Rect2(90, 360, 900, 1000):
	set(value):
		board_rect = value
		queue_redraw()
@export var deck_rect := Rect2(90, 1420, 900, 240):
	set(value):
		deck_rect = value
		queue_redraw()
@export var board_color := Color(0.78, 0.66, 0.47)
@export var border_color := Color(0.42, 0.3, 0.18)
@export var deck_color := Color(0.2, 0.22, 0.28)


func _draw() -> void:
	draw_rect(board_rect, board_color)
	draw_rect(board_rect, border_color, false, 8.0)
	draw_rect(deck_rect, deck_color)
