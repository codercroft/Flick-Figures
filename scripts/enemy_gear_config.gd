class_name EnemyGearConfig
extends Resource
## How likely enemies are to carry finishes, equipment and figure-specific upgrades. One entry per act
## (act 1, act 2, act 3). Elites and bosses use the NEXT act's rates (act 1 elites roll like act 2).
## Enemies never get economy or player-only equipment (see EquipmentData). Edit resources/enemy_gear_config.tres.

## Chance (per enemy) of a general finish.
@export var finish_chance: Array[float] = [0.0, 0.25, 0.5]
## Chance (per enemy) of an equipment item.
@export var equipment_chance: Array[float] = [0.0, 0.15, 0.35]
## Chance (per enemy) of a figure-specific upgrade, if one exists for that figure.
@export var upgrade_chance: Array[float] = [0.0, 0.0, 0.1]
## Elites and bosses roll at the rates of the act this many steps later (capped at the last act).
@export var elite_boss_act_shift := 1


func _entry(values: Array, act: int) -> float:
	if values.is_empty():
		return 0.0
	return values[clampi(act, 0, values.size() - 1)]


## The rates {finish, equipment, upgrade} for an enemy in `act` (0 = act 1).
func rates(act: int, is_elite_or_boss: bool) -> Dictionary:
	var shifted := act + (elite_boss_act_shift if is_elite_or_boss else 0)
	return {"finish": _entry(finish_chance, shifted), "equipment": _entry(equipment_chance, shifted),
			"upgrade": _entry(upgrade_chance, shifted)}
