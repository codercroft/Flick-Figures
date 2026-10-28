class_name FigureData
extends Resource
## Everything that makes one kind of figure different. Make a new figure by
## duplicating a .tres in resources/figures/ and changing the values in the Inspector.

@export var display_name := "Figure"
## Short text drawn on the figure (e.g. "CM"). Empty = first letter of the name.
@export var label := ""
## One line shown on the reward screen.
@export_multiline var description := ""
## Small picture drawn under the label that hints at what the figure does.
@export var icon := FigureIcons.Icon.NONE
@export var color := Color.WHITE
@export var radius := 60.0
@export var mass := 1.0
@export_range(0.0, 1.0) var bounce := 0.7
## Multiplies the base damping set on the Main node. Below 1 = slides farther.
@export var damping_multiplier := 1.0
## Multiplies the flick force. Launch speed = force * this / mass.
@export var flick_power_multiplier := 1.0
## Multiplies the speed this figure gains from being hit or blasted. 0.5 = half knockback.
@export var knockback_taken_multiplier := 1.0
## Enemy aim quality: 1 = perfect, 0 = the widest aim error (set on the EnemyAI node).
@export_range(0.0, 1.0) var accuracy := 0.8
## Enemy AI: false means this figure never flicks.
@export var can_flick := true
## After every enemy turn this figure slides this far (px) toward the player's deck. 0 = it never does.
## If it reaches the deck line, the player loses.
@export var creep_distance := 0.0
## How rare it is (shop prices depend on it): 0 common, 1 uncommon, 2 rare.
@export_enum("Common", "Uncommon", "Rare") var rarity := 0
## Extra money earned at the end of a won combat if this figure is still on the table.
@export var income_bonus := 0
## False for figures that should not earn the $1-per-figure income (e.g. Splitter's minis).
@export var pays_income := true
## Optional special behavior. Pick a FigureAbility subclass (e.g. BomboAbility) in the Inspector.
@export var ability: FigureAbility
## Bosses with a big body: distance (px) from the top of the board where it starts (0 = the normal margin).
@export var spawn_margin := 0.0


## The colored border used for this figure's rarity (same colors as relics: white, green, blue).
func rarity_color() -> Color:
	return RelicData.RARITY_COLORS[clampi(rarity, 0, 2)]


func rarity_name() -> String:
	return RelicData.RARITY_NAMES[clampi(rarity, 0, 2)]
