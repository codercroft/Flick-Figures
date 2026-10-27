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
## Shops: this many (1-3) are placed at random nodes each act, chosen so that EVERY path from the
## start to the boss passes at least one. (If that is impossible with this few, the map is rerolled.)
@export var shop_count_min := 1
@export var shop_count_max := 3
## The chest row: this whole column (0 = first) is made of treasure chests, so every path passes
## exactly one chest, at the same place on every act's map (the middle). Chests always give a relic.
@export var chest_column := 2
