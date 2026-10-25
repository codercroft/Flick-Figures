class_name RelicData
extends Resource
## A relic: a passive effect that lasts the whole run. What it does lives in its `effect`
## (a RelicEffect subclass in scripts/relics/). Make a new one by duplicating a .tres in
## resources/relics/ and listing it in RunConfig.relic_pool. A run never holds the same relic twice.

@export var display_name := "Relic"
## One or two characters shown on its little icon.
@export var label := "?"
@export_multiline var description := ""
@export var color := Color(0.8, 0.7, 0.4)
## Economy relics pay money.
@export var economy := false
@export var effect: RelicEffect
