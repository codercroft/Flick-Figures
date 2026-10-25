class_name RunConfig
extends Resource
## The rules of a run. Edit resources/run_config.tres in the Inspector to tune it.

## Where grunts, draftable figures and bosses come from.
@export var registry: FigureRegistry
## The player's deck starts as `deck_size` copies of this.
@export var starting_figure: FigureData
@export var deck_size := 4
## One entry per combat before the boss: how many of that combat's enemies are grunts.
## The rest are random non-grunts. (Default: 3 grunts, then 2+1, 1+2, and 0+3.)
@export var grunts_per_combat: Array[int] = [3, 2, 1, 0]
@export var enemies_per_combat := 3
## The arena layouts a combat can use (one is picked at random for each combat).
@export var arenas: Array[ArenaData] = []
## How many figures the reward screen offers.
@export var reward_choices := 3
