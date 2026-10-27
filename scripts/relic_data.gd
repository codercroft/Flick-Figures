class_name RelicData
extends Resource
## A relic: a passive effect that lasts the whole run. What it does lives in its `effect`
## (a RelicEffect subclass in scripts/relics/). Make a new one by duplicating a .tres in
## resources/relics/ and listing it in RunConfig.relic_pool. A run never holds the same relic twice.

enum Rarity { COMMON, UNCOMMON, RARE, BOSS }

## Icon border colors by rarity.
const RARITY_COLORS := [Color(0.85, 0.86, 0.9), Color(0.35, 0.85, 0.45), Color(0.4, 0.62, 1.0), Color(1.0, 0.6, 0.15)]
const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Boss"]

@export var display_name := "Relic"
## One or two characters shown on its little icon.
@export var label := "?"
@export_multiline var description := ""
@export var color := Color(0.8, 0.7, 0.4)
## How good it is: chests, elites and shops mostly offer Common/Uncommon; Boss relics only come from
## boss rewards (with Rare ones); shops never sell Boss relics and price the rest by rarity.
@export var rarity := Rarity.COMMON
## Economy relics pay money.
@export var economy := false
@export var effect: RelicEffect


func rarity_color() -> Color:
	return RARITY_COLORS[rarity]


func rarity_name() -> String:
	return RARITY_NAMES[rarity]
