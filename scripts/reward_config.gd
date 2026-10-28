class_name RewardConfig
extends Resource
## Every chance and amount for rewards, in one place. Edit resources/reward_config.tres.
## (Money per surviving figure is RunConfig.income_per_figure.)

@export_group("Figure drafts")
## How many figures a figure reward offers, one entry per act (relics like Trophy Case add more).
## Act 1 is a pure figure draft; later acts swap choices for bonus items (below).
## How many figures the BOSS reward offers (Rare ones you do not own; see RunManager.offer_rewards).
@export var boss_figure_choices := 3
@export var figure_choices_by_act: Array[int] = [3, 2, 1]
## Extra random rewards after a regular combat's or elite's figure draft, one entry per act. Each is
## one of: a power, an equipment item or an upgrade (a figure-specific upgrade or a finish).
@export var bonus_items_by_act: Array[int] = [0, 1, 2]
## Rarity weights for drafted figures, one entry per act: (common, uncommon, rare). Act 1 is mostly
## common; later acts lean toward rarer figures. The shop's figures use the same weights.
@export var rarity_weights_by_act: Array[Vector3] = [Vector3(0.8, 0.18, 0.02), Vector3(0.35, 0.5, 0.15), Vector3(0.2, 0.5, 0.3)]

@export_group("Relics")
## Weights (common, uncommon, rare) for relics from chests, elites and the shop. Boss relics never
## show up there.
@export var relic_weights := Vector3(0.65, 0.3, 0.05)

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


## Figure choices for a figure reward in `act` (0 = act 1), before relic bonuses.
func figure_choices(act: int) -> int:
	return figure_choices_by_act[clampi(act, 0, figure_choices_by_act.size() - 1)] if not figure_choices_by_act.is_empty() else 3


## Bonus random items after the figure draft in `act`.
func bonus_items(act: int) -> int:
	return bonus_items_by_act[clampi(act, 0, bonus_items_by_act.size() - 1)] if not bonus_items_by_act.is_empty() else 0


## Weights (common, uncommon, rare) for drafts in `act` (0 = act 1).
func rarity_weights(act: int) -> Vector3:
	if rarity_weights_by_act.is_empty():
		return Vector3(1.0, 1.0, 1.0)
	return rarity_weights_by_act[clampi(act, 0, rarity_weights_by_act.size() - 1)]
