class_name ArenaWall
extends Resource
## One wall segment: a solid, bouncy rectangle. Positions are in board space: (0, 0) is the
## top-left corner of the board, x goes right, y goes down (enemies at the top, your deck below).

## Center of the rectangle.
@export var position := Vector2.ZERO
## Length and thickness (before rotating).
@export var size := Vector2(200.0, 36.0)
@export_range(-180.0, 180.0) var rotation_degrees := 0.0
