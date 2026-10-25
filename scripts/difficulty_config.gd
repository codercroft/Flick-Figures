class_name DifficultyConfig
extends Resource
## How hard each act is. Every array has one entry per act (act 1, act 2, act 3...).
## Edit resources/difficulty_config.tres in the Inspector.

@export_group("Regular combats")
## Enemies in each regular combat.
@export var enemies_per_combat: Array[int] = [4, 5, 6]
## How many flicks the enemy side takes each turn.
@export var enemy_flicks_per_turn: Array[int] = [1, 1, 1]
## Multipliers on every regular enemy's stats, ramping up a bit each act.
@export var accuracy_multiplier: Array[float] = [1.0, 1.05, 1.1]
@export var flick_power_multiplier: Array[float] = [1.0, 1.1, 1.2]
@export var mass_multiplier: Array[float] = [1.0, 1.1, 1.25]

@export_group("Bosses")
## The same three multipliers for the act's boss (applied to each of its figures).
@export var boss_accuracy_multiplier: Array[float] = [1.0, 1.05, 1.1]
@export var boss_flick_power_multiplier: Array[float] = [1.0, 1.1, 1.2]
@export var boss_mass_multiplier: Array[float] = [1.0, 1.15, 1.3]

@export_group("Elites")
## 1 or 2 of an elite fight's non-grunts are "elite": stronger than the rest.
@export var elite_figures_min := 1
@export var elite_figures_max := 2
## Extra multipliers on an elite figure's stats (on top of the act's).
@export var elite_mass_multiplier := 1.3
@export var elite_flick_power_multiplier := 1.2
@export var elite_accuracy_multiplier := 1.1
## The enemy side takes this many extra flicks per turn in an elite fight.
@export var elite_extra_flicks := 1
## Extra money for winning an elite fight.
@export var elite_extra_money := 3


func _entry(values: Array, act: int, fallback: float) -> float:
	if values.is_empty():
		return fallback
	return values[clampi(act, 0, values.size() - 1)]


## The stat multipliers for an enemy figure in `act` (0 = act 1): {accuracy, power, mass}.
func scale_for(act: int, is_boss: bool, is_elite: bool) -> Dictionary:
	var scale := {}
	if is_boss:
		scale = {"accuracy": _entry(boss_accuracy_multiplier, act, 1.0), "power": _entry(boss_flick_power_multiplier, act, 1.0),
				"mass": _entry(boss_mass_multiplier, act, 1.0)}
	else:
		scale = {"accuracy": _entry(accuracy_multiplier, act, 1.0), "power": _entry(flick_power_multiplier, act, 1.0),
				"mass": _entry(mass_multiplier, act, 1.0)}
	if is_elite:
		scale.accuracy *= elite_accuracy_multiplier
		scale.power *= elite_flick_power_multiplier
		scale.mass *= elite_mass_multiplier
	return scale


func enemy_count(act: int) -> int:
	return int(_entry(enemies_per_combat, act, 4.0))


func flicks_per_turn(act: int) -> int:
	return int(_entry(enemy_flicks_per_turn, act, 1.0))
