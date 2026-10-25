extends Node2D
## Draws the board and the deck strip, and holds their sizes for other scripts.
## The deck sits right below the board; together they are the "table".
## Edges are open: main.gd knocks off any figure whose center leaves the table.

@export var board_rect := Rect2(90, 360, 900, 1000):
	set(value):
		board_rect = value
		queue_redraw()
@export var deck_rect := Rect2(90, 1360, 900, 300):
	set(value):
		deck_rect = value
		queue_redraw()
@export var board_color := Color(0.78, 0.66, 0.47)
@export var border_color := Color(0.42, 0.3, 0.18)
@export var deck_color := Color(0.2, 0.22, 0.28)
## Faint line shown when a boss creeps toward your deck: where it has to get to.
@export var deck_line_color := Color(1.0, 0.3, 0.3, 0.6)

var show_deck_line := false:
	set(value):
		show_deck_line = value
		queue_redraw()


func get_table_rect() -> Rect2:
	return board_rect.merge(deck_rect)


func _draw() -> void:
	draw_rect(board_rect, board_color)
	draw_rect(deck_rect, deck_color)
	draw_rect(get_table_rect(), border_color, false, 8.0)
	if show_deck_line:
		var y := deck_rect.position.y
		draw_dashed_line(Vector2(board_rect.position.x, y), Vector2(board_rect.end.x, y), deck_line_color, 10.0, 28.0)
