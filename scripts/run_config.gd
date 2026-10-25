class_name RunConfig
extends Resource
## The rules of a run. Edit resources/run_config.tres in the Inspector to tune it.

## Where grunts, draftable figures and bosses come from.
@export var registry: FigureRegistry
## The player's deck starts as `deck_size` copies of this.
@export var starting_figure: FigureData
@export var deck_size := 4
## How many acts a run has. Each act is its own map ending in its own boss.
@export var acts := 3
## How hard each act is (enemy counts and stat multipliers per act, elites).
@export var difficulty: DifficultyConfig
## The named encounters elite nodes pick from (instead of a random lineup).
@export var elite_encounters: Array[EncounterData] = []
## How each act's branching map is built.
@export var map: MapConfig
## The arena layouts a combat can use (one is picked at random for each combat).
@export var arenas: Array[ArenaData] = []
## Money the run starts with.
@export var starting_money := 0
## Money earned at the end of a won combat for each of your figures still on the table.
@export var income_per_figure := 1
## What the shop sells (see resources/shop_config.tres).
@export var shop: ShopConfig
## How many power slots the player has.
@export var power_slots := 3
## For testing: start each run with some random powers.
@export var start_with_powers := true
@export var starting_power_count := 2
## Every power that exists (add new PowerData resources here).
@export var power_pool: Array[PowerData] = []
## For testing: start each run holding some random equipment (in the inventory).
@export var start_with_equipment := true
@export var starting_equipment_count := 2
## Every equipment item that exists (add new EquipmentData resources here).
@export var equipment_pool: Array[EquipmentData] = []
## Every general toy finish and every figure-specific upgrade that exists.
@export var finish_pool: Array[FinishData] = []
@export var upgrade_pool: Array[UpgradeData] = []
## For testing: a free "Upgrades" button on the map to put finishes and upgrades on your figures
## (until rewards or the shop hand them out).
@export var show_upgrade_screen := true
## For testing: start each run with some random relics.
@export var start_with_relics := true
@export var starting_relic_count := 3
## Every relic that exists (add new RelicData resources here).
@export var relic_pool: Array[RelicData] = []
@export_group("Rewards")
## How many figures the reward screen offers.
@export var reward_choices := 3
## Elite fights: chance of a power as a reward.
@export_range(0.0, 1.0) var elite_power_chance := 0.5
## Treasure nodes: chance that the treasure is a relic (otherwise a piece of equipment).
@export_range(0.0, 1.0) var treasure_relic_chance := 0.5
## Boss rewards: how many relics to pick from.
@export var boss_relic_choices := 3
