class_name BossData
extends Resource
## One boss fight. Its enemy figures carry the stats you tune (mass, accuracy, flick power,
## creep distance), so edit those in resources/figures/ (e.g. wall_piece.tres, sniper.tres).

@export var display_name := "Boss"
@export_multiline var description := ""
## Placeholder text and color for this boss's node on the run map.
@export var map_label := "B"
@export var map_color := Color(0.8, 0.2, 0.2)
## Optional little icon drawn above the label on the map (FigureIcons.Icon, 0 = none).
@export var map_icon: FigureIcons.Icon = FigureIcons.Icon.NONE
## The enemy figures for the boss fight, left to right.
@export var enemies: Array[FigureData] = []
## How many flicks the enemy side takes per turn in this fight (each one is the best shot of
## any enemy figure; the same figure can't flick twice in a row).
@export var enemy_flicks_per_turn := 1
## The enemy side flicks once per turn for each of its units on the table (Slime: every piece; Skull-o-tron:
## the core and each Skull Ball), up to Main.max_enemy_flicks, instead of `enemy_flicks_per_turn`.
@export var flick_per_unit := false
## Line the enemies up in one straight row across the board (The Wall) instead of staggering them.
@export var straight_row := false
## A solid wall along the whole top edge of the table, behind the boss, so it cannot be knocked straight
## off the back in one shot (Slime, Skull-o-tron).
@export var back_wall := false
## The Mad Creator's setup: a box of four breakable walls at the top with the boss inside (see CreatorBox), the four
## figures its floor spaces summon (top-left, top-right, bottom-left, bottom-right), each wall's health, and the most
## summoned figures that may be on the table at once.
@export var creator_box := false
@export var summons: Array[FigureData] = []
@export var box_wall_health := 8000.0
@export var max_summons := 5

## Optional per-body tuning, parallel to `enemies` (0 = keep the figure's own value): radius, mass and flick power. Lets a boss
## use a stock figure (so its upgrade tree still applies) at another size (Bomb Duo's big Aggro-bom and Land Miner).
@export var body_radius: Array[float] = []
@export var body_mass: Array[float] = []
@export var body_power: Array[float] = []
## Exact ability values per body, parallel to `enemies` (a dictionary of property name -> value; {} = none).
@export var body_ability_values: Array[Dictionary] = []
## Upgrade-tree state each body carries, parallel to `enemies`: x = path (0 = A, 1 = B, -1 none), y = tier. `base_upgrades`
## always; `ascended_upgrades` instead from the Boss Upgrades Ascension level (empty = same as base).
@export var base_upgrades: Array[Vector2i] = []
@export var ascended_upgrades: Array[Vector2i] = []
## Fat Man: no figure bodies, a fixed stomach with two hands (see FatMan). `fat_man_hits` = player hits on the stomach to win.
@export var fat_man := false
@export var fat_man_hits := 5
## The figure shown for this boss in the Compendium (and the sandbox) when `enemies` is empty (Fat Man).
@export var display_figure: FigureData


## The figure drawn for this boss on the Compendium page: `display_figure`, else the first body.
func badge_figure() -> FigureData:
	if display_figure != null:
		return display_figure
	return enemies[0] if not enemies.is_empty() else null
