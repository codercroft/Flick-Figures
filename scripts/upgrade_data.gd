class_name UpgradeData
extends Resource
## ONE tier of a figure's upgrade tree (see UpgradeTree). It is described by plain stat changes and an optional
## extra effect. Edit the numbers and text in the .tres files in resources/upgrades/<figure>/.
## Everything is cumulative: tier 2 is applied on top of tier 1, tier 3 on top of both.

@export var display_name := "Upgrade"
@export_multiline var description := ""
## New absolute values for FigureData properties (e.g. {"radius": 80.0}).
@export var data_overrides := {}
## Multipliers on FigureData properties, applied after the overrides (e.g. {"mass": 1.3}).
@export var data_multipliers := {}
## New absolute values for the figure's ability properties (e.g. {"collisions_needed": 3}).
@export var ability_overrides := {}
## Multipliers on the figure's ability properties, applied after the overrides (e.g. {"explosion_force": 1.25}).
@export var ability_multipliers := {}
## Optional extra behavior (any FigureAbility), run next to the figure's own ability.
@export var extra_effect: FigureAbility
## Run-wide effects while a figure with this upgrade is in the deck, summed over the deck (e.g. {"shop_discount": 0.15}).
@export var run_modifiers := {}
