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
## Shops: how many each act gets (1 to 3, at random, about 2 on average). Entry 0 is the weight of
## one shop, entry 1 of two shops, entry 2 of three: [1, 2, 1] = 25% / 50% / 25%.
@export var shop_count_weights: Array[float] = [1.0, 2.0, 1.0]
## Shops only appear from this row on (0 = first row, so 2 = the 3rd row). Never two in the same row.
## Nothing guarantees that every path passes a shop.
@export var shop_from_column := 2
## The chest row: this whole column (0 = first) is made of treasure chests, so every path passes
## exactly one chest, at the same place on every act's map (the middle). Chests always give a relic.
@export var chest_column := 2
## Events: how many each act gets (entry 0 = one event, 1 = two, 2 = three; [1, 2, 1] = usually two).
@export var event_count_weights: Array[float] = [1.0, 2.0, 1.0]
## Events only appear from this row on (0 = first row, 2 = the 3rd), at most one per row.
@export var event_from_column := 2
