class_name MinigameConfig
extends Resource
## Numbers for the map events: the Gamer's games, the Finisher, Gear Man, Vending Machine, Recycler and the
## Cup Toss, Duelist, King of the Hill and Punching Bag minigames (and the old games' opponent strength).
## Edit resources/minigame_config.tres.

@export_group("The Gamer's games (Bocce, Curling, Bowling, Mini-Golf)")
## Money for winning a game at The Gamer (on top of an Upgrade step and a finish). A loss gives nothing and makes the
## next fight harder (RunManager.minigame_penalty).
@export var win_money := 6

## The opponent's accuracy (1 = perfect, 0.6 = about 8 degrees of aim error either way).
@export_range(0.0, 1.0) var ai_accuracy := 0.6
## Random error on the opponent's power (0.05 = up to 5% stronger or weaker).
@export var ai_power_error := 0.05
## Pause (seconds) before the opponent flicks.
@export var ai_think_time := 0.8

@export_group("Mini-Golf")
## The golf opponent's accuracy (1 = perfect, 0.7 = about 6 degrees of aim error either way).
@export_range(0.0, 1.0) var golf_ai_accuracy := 0.7
## Random error on the golf opponent's power (0.04 = up to 4%).
@export var golf_ai_power_error := 0.04

@export_group("The Gamer")
## The Gamer offers this many of the four games (random). Win: win_money + an Upgrade step + a finish; loss: a harder next fight.
@export var gamer_choices := 3

@export_group("The Finisher and Gear Man")
## Different random finishes the Finisher offers (only ones that fit a figure in the deck).
@export var finisher_choices := 3
## Equipment items Gear Man offers.
@export var gear_man_choices := 3

@export_group("Vending Machine")
## Price of the first purchase, and how much each later purchase costs more.
@export var vending_first_price := 4
@export var vending_price_step := 2
## Chance that a purchase jams: the money is eaten and nothing comes out.
@export_range(0.0, 1.0) var vending_jam_chance := 0.15
## The kinds the machine can sell (equal odds).
@export var vending_kinds: Array[String] = ["power", "equipment", "finish"]

@export_group("Recycler")
## Reward by the recycled figure's rarity (0 Common, 1 Uncommon, 2 Rare): kinds ("power", "equipment", "relic") and money.
@export var recycler_kinds: Array[String] = ["power", "equipment", "relic"]
@export var recycler_money: Array[int] = [0, 5, 0]

@export_group("Cup Toss")
## What the near, middle and far cup win ("power", "equipment", "relic"), and the money for a miss.
@export var cup_rewards: Array[String] = ["power", "equipment", "relic"]
@export var cup_miss_money := 3
@export var cup_radius := 60.0
@export var cup_ball_radius := 24.0

@export_group("The Duelist")
## Diameter of the round platform (px).
@export var duel_platform_diameter := 500.0
## A Bruised figure's flick power multiplier (it lasts for the next combat only).
@export var bruised_power := 0.8
## Flicks each side may take before the duel is called a draw.
@export var duel_max_flicks := 8

@export_group("King of the Hill")
## Grunts arriving on each of the three enemy turns.
@export var hill_grunts: Array[int] = [2, 3, 4]
## Radius of the zone (px).
@export var hill_zone_radius := 230.0
## Money for 1+ figures in the zone at the end; the item kinds you also get for 2 and 3 figures ("equipment", "finish").
@export var hill_money := 5
@export var hill_items: Array[String] = ["equipment", "finish"]

@export_group("Punching Bag")
## Score of one full-power Grunt hit (three of them = 100).
@export var bag_grunt_score := 33.3
## The bag's momentum (mass x peak speed) after a full-power Grunt hit; measured by tools/punching_bag_test.gd.
@export var bag_grunt_momentum := 3573.0
## Score thresholds and what each unlocks (cumulative): 25 equipment, 50 + a power, 75 + a finish, 100 + an Upgrade.
@export var bag_thresholds: Array[int] = [25, 50, 75, 100]
@export var bag_rewards: Array[String] = ["equipment", "power", "finish", "upgrade"]
