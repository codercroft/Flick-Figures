class_name RunConfig
extends Resource
## The rules of a run. Edit resources/run_config.tres in the Inspector to tune it.

## Where grunts, draftable figures and bosses come from.
@export var registry: FigureRegistry
## The player's deck starts as `deck_size` copies of this.
@export var starting_figure: FigureData
@export var deck_size := 4
## One entry per combat before the boss: how many of that combat's enemies are grunts.
## The rest are random non-grunts (never economy figures). Default: 4 grunts, then 3+1, 2+2, 1+3, 0+4.
@export var grunts_per_combat: Array[int] = [4, 3, 2, 1, 0]
## One entry per combat before the boss: how many flicks the enemy side takes each turn.
@export var enemy_flicks_per_combat: Array[int] = [1, 1, 1, 1, 1]
## How many enemies each regular combat has.
@export var enemies_per_combat := 4
## The arena layouts a combat can use (one is picked at random for each combat).
@export var arenas: Array[ArenaData] = []
## Money the run starts with.
@export var starting_money := 0
## Money earned at the end of a won combat for each of your figures still on the table.
@export var income_per_figure := 1
## What the shop sells (see resources/shop_config.tres).
@export var shop: ShopConfig
## The shop sits on the map just before this combat (0 = the first combat): 3 = between combats 3 and 4.
@export var shop_position := 3
## How many power slots the player has.
@export var power_slots := 3
## For testing: start each run with some random powers.
@export var start_with_powers := true
@export var starting_power_count := 2
## Every power that exists (add new PowerData resources here).
@export var power_pool: Array[PowerData] = []
## How many figures the reward screen offers.
@export var reward_choices := 3
