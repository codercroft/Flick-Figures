class_name GolfCourse
extends Resource
## One Mini-Golf course: an arena layout (walls forming the course, pins, slow / boost / turn patches)
## plus where the tee and the hole are. Positions are in board space ((0, 0) = top-left of the board,
## 900x1000). The layout should have its own outer walls. Files are in resources/golf/.

@export var display_name := "Course"
@export var description := ""
@export var layout: ArenaData
## Where both balls start.
@export var tee := Vector2(450, 890)
## Center of the hole.
@export var hole := Vector2(450, 120)
