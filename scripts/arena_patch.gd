class_name ArenaPatch
extends Resource
## A patch on the floor. Figures pass over it (it is not solid) and it only affects figures that
## are already moving, so a resting figure is never nudged. Rectangle, in board space
## ((0, 0) = top-left corner of the board).

enum Kind { SLOW, BOOST, TURN }
enum Turn { LEFT, RIGHT }

@export var kind := Kind.SLOW
## Center of the rectangle.
@export var position := Vector2.ZERO
@export var size := Vector2(240.0, 200.0)
## BOOST only: the direction figures are pushed, in degrees. 0 = right, -90 = up (toward the
## enemies), 90 = down (toward your deck), 180 = left.
@export_range(-180.0, 180.0) var direction_degrees := -90.0
## TURN only: which way a moving figure's path curves (as seen on screen).
@export var turn := Turn.RIGHT
## Multiplies the strength set on the Arena node (slow drag, boost push or turn rate).
@export var strength := 1.0
