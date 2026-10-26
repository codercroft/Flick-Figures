class_name RewardConfig
extends Resource
## Every chance and amount for rewards, in one place. Edit resources/reward_config.tres.
## (Money per surviving figure is RunConfig.income_per_figure.)

@export_group("Figure drafts")
## How many figures a figure reward offers (relics like Trophy Case add more).
@export var figure_choices := 3
## Rarity weights for drafted figures, one entry per act: (common, uncommon, rare). Act 1 is mostly
## common; later acts lean toward rarer figures. The shop's figures use the same weights.
@export var rarity_weights_by_act: Array[Vector3] = [Vector3(0.75, 0.22, 0.03), Vector3(0.45, 0.4, 0.15), Vector3(0.25, 0.45, 0.3)]

@export_group("Regular combat")
## Bonus drops, rolled after each regular combat win.
@export_range(0.0, 1.0) var combat_power_chance := 0.15
@export_range(0.0, 1.0) var combat_equipment_chance := 0.1

@export_group("Elite")
## Extra money on top of the per-figure income.
@export var elite_bonus_money := 3
## Guaranteed random relics.
@export var elite_guaranteed_relics := 1
@export_range(0.0, 1.0) var elite_power_chance := 0.4
@export_range(0.0, 1.0) var elite_equipment_chance := 0.3
## Chance of a general finish (the player picks which figure gets it).
@export_range(0.0, 1.0) var elite_finish_chance := 0.2

@export_group("Boss")
@export var boss_bonus_money := 10
## Pick 1 of this many relics.
@export var boss_relic_choices := 3
## One finish or figure-specific upgrade for a figure of the player's choice: chance that it is a
## figure-specific upgrade (otherwise a finish; falls back to a finish if no held figure can take one).
@export_range(0.0, 1.0) var boss_specific_upgrade_chance := 0.5
## The guaranteed extra item is a power or an equipment item: this is the power chance.
@export_range(0.0, 1.0) var boss_power_chance := 0.5


## Weights (common, uncommon, rare) for drafts in `act` (0 = act 1).
func rarity_weights(act: int) -> Vector3:
	if rarity_weights_by_act.is_empty():
		return Vector3(1.0, 1.0, 1.0)
	return rarity_weights_by_act[clampi(act, 0, rarity_weights_by_act.size() - 1)]
