class_name MinigameConfig
extends Resource
## Rewards and opponent strength for the minigame events (Bocce, Curling, Bowling).
## Edit resources/minigame_config.tres.

@export_group("Bocce, Curling and Mini-Golf")
## Money for beating the opponent (Bocce, Curling and Mini-Golf; on top of the item below). A loss gives nothing and makes the
## next fight harder (RunManager.minigame_penalty).
@export var win_money := 6
## A win also gives ONE random item of one of these kinds: "power", "equipment" or "finish".
@export var win_item_kinds: Array[String] = ["power", "equipment", "finish"]
## The opponent's accuracy (1 = perfect, 0.6 = about 8 degrees of aim error either way).
@export_range(0.0, 1.0) var ai_accuracy := 0.6
## Random error on the opponent's power (0.05 = up to 5% stronger or weaker).
@export var ai_power_error := 0.05
## Pause (seconds) before the opponent flicks.
@export var ai_think_time := 0.8

@export_group("Mini-Golf")
## The golf opponent's accuracy (1 = perfect, 0.7 = about 6 degrees of aim error either way).
@export_range(0.0, 1.0) var golf_ai_accuracy := 0.7
## Random error on the golf opponent's power (0.04 = up to 4%).
@export var golf_ai_power_error := 0.04

@export_group("Bowling")
## Money by number of pins knocked over (entry 0 = none, entry 10 = all ten). Smaller than the
## contests above.
@export var bowling_money_by_pins: Array[int] = [0, 0, 1, 1, 1, 2, 2, 3, 3, 4, 5]
## A strike (all ten with the first flick) or a spare (all ten with two) also gives a random power.
@export var bowling_power_on_clear := true
