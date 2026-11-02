class_name EliteConfig
extends Resource
## How elite encounters scale by act (one entry per act: act 1, act 2, act 3). Edit resources/elite_config.tres.
## Act 1 elites: a small stat boost. Act 2: every enemy also carries a compatible equipment item or finish that
## suits its role. Act 3: the same, plus one "enemy relic" for the whole enemy side, and the elite reward is a choice
## of 1 of 3 relics.

## Extra multipliers on every enemy of an elite encounter (on top of the encounter's own boosts and the act's).
@export var boost_mass: Array[float] = [1.05, 1.0, 1.0]
@export var boost_power: Array[float] = [1.05, 1.0, 1.0]
@export var boost_accuracy: Array[float] = [1.05, 1.0, 1.0]
## Every enemy gets one guaranteed gear item (equipment or a finish that suits its role).
@export var guaranteed_gear: Array[bool] = [false, true, true]
## Of the guaranteed gear, the share that is equipment (the rest are finishes; the other kind is the fallback).
@export_range(0.0, 1.0) var equipment_share := 0.5
## How many enemy relics the enemy side carries (shown at the start of the fight and in the combat UI).
@export var enemy_relic_count: Array[int] = [0, 0, 1]
## The relics enemies can carry: only ones that make sense for them, never economy relics.
@export var enemy_relic_pool: Array[RelicData] = []
## The elite reward: how many relics to choose from (1 = one random relic, as before).
@export var relic_choices: Array[int] = [1, 1, 3]


func _at(values: Array, act: int, fallback):
	return values[clampi(act, 0, values.size() - 1)] if not values.is_empty() else fallback


## The stat boost {mass, power, accuracy} for elite enemies in `act` (0-based).
func boost_for(act: int) -> Dictionary:
	return {"mass": _at(boost_mass, act, 1.0), "power": _at(boost_power, act, 1.0), "accuracy": _at(boost_accuracy, act, 1.0)}


func gear_guaranteed(act: int) -> bool:
	return _at(guaranteed_gear, act, false)


func relics_for(act: int) -> int:
	return _at(enemy_relic_count, act, 0)


func reward_choices(act: int) -> int:
	return _at(relic_choices, act, 1)
