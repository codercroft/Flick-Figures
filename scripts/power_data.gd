class_name PowerData
extends Resource
## One power: a one-time-use item the player holds and uses during combat. What it does lives
## in its `effect` (a PowerEffect subclass in scripts/powers/). Make a new power by duplicating a
## .tres in resources/powers/ (or writing a new effect script) and adding it to RunConfig.power_pool.

@export var display_name := "Power"
## One line describing what it does.
@export_multiline var description := ""
## Tint of its button in the power bar.
@export var color := Color(0.3, 0.4, 0.6)
@export var effect: PowerEffect
