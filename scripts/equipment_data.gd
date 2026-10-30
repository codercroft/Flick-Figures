class_name EquipmentData
extends Resource
## One equipment item: attached to a single figure for the run. Simple stat changes are plain
## numbers here; anything fancier is an `effect` (any FigureAbility subclass, see
## scripts/equipment/). Make a new item by duplicating a .tres in resources/equipment/ and
## adding it to RunConfig.equipment_pool.

@export var display_name := "Item"
## One or two characters drawn on the little badge shown on an equipped figure.
@export var label := "?"
@export_multiline var description := ""
@export var color := Color(0.8, 0.8, 0.85)
## 0 Common, 1 Uncommon, 2 Rare (same colors and names as relics and figures).
@export_enum("Common", "Uncommon", "Rare") var rarity := 0
## Economy items pay money; they are never handed to enemies (enemies carry no equipment).
@export var economy := false
## True for items that only make sense on the player's figures (Coin Purse pays the player, Lucky
## Charm bends ENEMY aim, Jet Pack's half-power flick isn't modelled by the AI). Enemies never get them.
@export var player_only := false

@export_group("Stat changes")
## The figure's mass is multiplied by this.
@export var mass_multiplier := 1.0
## Added to the figure's bounce (Godot caps the total at 1).
@export var bounce_bonus := 0.0
## The figure's damping is multiplied by this (below 1 = slides farther).
@export var damping_multiplier := 1.0
## Extra money at the end of a won combat if the figure is still on the table.
@export var income_bonus := 0

@export_group("Effect")
## Optional special behavior using the ability hooks.
@export var effect: FigureAbility

@export_group("Who it suits (enemy gear rules)")
## Only useful on figures whose ability has numbers it can scale (explosion radius, pull, bounce...).
@export var needs_ability_numbers := false
## Figures with one of these abilities never get this (it would do nothing: Wings on a Ghost).
@export var incompatible_abilities: Array[Script] = []
## Enemies favor figures that match these roles ("heavy", "light", "power", "bouncy", "explosive", "slider"):
## the weight is added to 1 for each role the figure has. See GearRules.
@export var role_weights := {}


const RARITY_NAMES := ["Common", "Uncommon", "Rare"]
const RARITY_COLORS := [Color(0.75, 0.78, 0.82), Color(0.4, 0.85, 0.45), Color(0.95, 0.75, 0.2)]


func rarity_name() -> String:
	return RARITY_NAMES[clampi(rarity, 0, 2)]


func rarity_color() -> Color:
	return RARITY_COLORS[clampi(rarity, 0, 2)]
