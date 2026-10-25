class_name EncounterData
extends Resource
## A named fight: its enemy figures (each with optional stat boosts), how many flicks the enemy side
## takes per turn, and which acts it can appear in. Elite nodes pick from RunConfig.elite_encounters.
## The act's difficulty multipliers still apply on top. Make a new one by duplicating a .tres in
## resources/encounters/ and listing it in the pool.

@export var display_name := "Encounter"
@export var enemies: Array[EncounterEnemy] = []
@export var enemy_flicks_per_turn := 1
## Which acts it can appear in (1 = act 1, 2 = act 2, 3 = act 3).
@export var acts: Array[int] = [1, 2, 3]


## `act` is 0-based (RunManager.act).
func available_in(act: int) -> bool:
	return acts.has(act + 1)


func enemy_count() -> int:
	var total := 0
	for entry in enemies:
		total += entry.count
	return total
