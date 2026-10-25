class_name FinishData
extends Resource
## A general toy finish any figure can take (one per figure): a look plus some changes. Plain
## numbers cover the simple ones; `effect` (any FigureAbility) covers the rest.
## Add a new one by duplicating a .tres in resources/finishes/ and listing it in RunConfig.finish_pool.

enum Look { SPARKLE, SHEEN, GLOW, TRANSLUCENT, RUBBER }

@export var display_name := "Finish"
@export_multiline var description := ""
## How it is drawn on the figure.
@export var look := Look.SPARKLE
## Tint used for the sparkles / glow.
@export var color := Color(1.0, 0.9, 0.5)

@export_group("Changes")
## The figure's mass is multiplied by this.
@export var mass_multiplier := 1.0
## Multiplies the knockback the figure takes (0.75 = takes 25% less).
@export var knockback_taken_multiplier := 1.0
## Multiplies the figure's ability numbers that have a size or strength (radius, pull, bounce).
@export var ability_strength := 1.0
## Optional special behavior using the ability hooks.
@export var effect: FigureAbility
