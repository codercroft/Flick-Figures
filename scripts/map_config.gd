class_name MapConfig
extends Resource
## How an act's branching map is generated. Edit resources/map_config.tres.

## Columns of nodes before the boss (each step of the path is one column).
@export var columns := 6
## Lanes (side to side positions) per column. At most one lane is missing from a column.
@export var lanes := 4
## Chance that a column (after the first) is missing one lane, for variety.
@export_range(0.0, 1.0) var missing_lane_chance := 0.5
## Each node connects forward to this many nodes of the next column (2-3 where possible).
@export var min_choices := 2
@export var max_choices := 3
## Elites only appear from this column on (default: the middle of the act). Always optional.
@export var elite_from_column := 3
@export_range(0.0, 1.0) var elite_chance := 0.25
## One whole column (picked from these) is made of shops, so EVERY path has a shop.
@export var shop_columns: Array[int] = [3, 4]
## Extra shops elsewhere (not next to the shop column).
@export_range(0.0, 1.0) var extra_shop_chance := 0.08
## Treasure nodes appear in these columns...
@export var treasure_columns: Array[int] = [2, 3]
@export_range(0.0, 1.0) var treasure_chance := 0.25
