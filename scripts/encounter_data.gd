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
## The arena layout this fight is played on (null = a random one).
@export var arena: ArenaData
## Regular encounters: if fewer figures are listed than the act's enemy count (4/5/6), the rest are
## Grunts placed in free spots. (Elite encounters leave this off.)
@export var fill_with_grunts := false

@export_group("Mirror match")
## Build the lineup from the figure types in the player's current deck (economy figures become Grunts).
@export var mirror_deck := false
## Stat boosts for the mirrored enemies (on top of the act's multipliers).
@export var mirror_mass_multiplier := 1.1
@export var mirror_power_multiplier := 1.1
@export var mirror_accuracy_multiplier := 1.1


## `act` is 0-based (RunManager.act).
func available_in(act: int) -> bool:
	return acts.has(act + 1)


func enemy_count() -> int:
	var total := 0
	for entry in enemies:
		total += entry.count
	return total
