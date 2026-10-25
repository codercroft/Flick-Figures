class_name UpgradeData
extends Resource
## A figure-specific upgrade: only for the one `figure` it names. It is described by property
## overrides (new values for FigureData or ability properties) and an optional extra effect.
## Add one by duplicating a .tres in resources/upgrades/ and listing it in RunConfig.upgrade_pool.

## The figure this upgrade is for.
@export var figure: FigureData
@export var display_name := "Upgrade"
@export_multiline var description := ""
## New values for the figure's stats, by FigureData property name (e.g. {"flick_power_multiplier": 2.5}).
@export var data_overrides := {}
## New values for the figure's ability, by property name (e.g. {"flicks_per_turn": 3}).
@export var ability_overrides := {}
## Optional extra behavior (any FigureAbility), run next to the figure's own ability.
@export var extra_effect: FigureAbility
