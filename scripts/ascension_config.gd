class_name AscensionConfig
extends Resource
## Ascension: optional extra difficulty levels (0 = the base game). Each level includes all lower levels. Every
## number lives here (edit resources/ascension_config.tres). The base game (level 0) is FLAT: 4 enemies per regular
## combat in every act, no act stat multiplier, and no enemy finishes / equipment / upgrades, no elite stat boost,
## elite gear or enemy relics. The levels turn those systems (which stay in the code) back on, and add new ones.

## The highest level: derived from the list below, so adding a name + description adds a level (the selector, unlock
## progress, top bar, run history and per-level stats all follow). The effect of each level is wired by the level
## NUMBERS further down (change those if you reorder levels).
var max_level: int:
	get:
		return maxi(level_names.size() - 1, 0)

## One entry per level, index 0 = the base game. Short names and one-line descriptions (shown in the selector).
@export var level_names: Array[String] = [
	"Base game", "Geared Enemies", "Harsher Events", "Rising Threat", "Leaner Economy", "Upgraded Enemies",
	"Hardened Elites", "Fewer Offers", "Elite Relics", "Boss Upgrades", "Bigger Squads", "Double Boss"]
@export var level_descriptions: Array[String] = [
	"The normal game.",
	"Regular enemies roll finishes and equipment (more in later acts). Elites and bosses roll like the next act.",
	"Losing a minigame gives BOTH penalties: an extra Grunt AND enemy gear.",
	"Enemies get stronger each act (accuracy, flick power, mass; bosses too) and regular combats have 4 / 5 / 6 enemies by act.",
	"Shop prices +50%.",
	"Enemies can carry upgrade tiers (tier 1 on a path; elites roll like the next act and can reach tier 2).",
	"Elites get a stat boost and a fitting item on every enemy.",
	"Figure rewards offer 2 choices instead of 3, and chance drops are halved.",
	"Elites carry an enemy relic in every act.",
	"Bosses are tougher: The Wall creeps faster, 7 snipers, Trangle spins faster and flicks 3 times, Slimes split into 3, Skull-o-tron has 4 arms, Mad Creator summons a Bombo instead of a Grunt.",
	"+1 enemy in every regular combat (on top of Rising Threat).",
	"After the act 3 boss you fight the other act 3 boss straight away. Beat both to win."]

@export_group("Level numbers")
## Which level switches each system on (edit these if you reorder or insert levels).
@export var level_geared := 1
@export var level_events := 2
@export var level_threat := 3
@export var level_economy := 4
@export var level_upgraded := 5
@export var level_elites := 6
@export var level_offers := 7
@export var level_relics := 8
@export var level_bosses := 9
@export var level_squads := 10
@export var level_double := 11

@export_group("Geared Enemies")
## Finish / equipment chances per act (elites and bosses use the next act's rates).
@export var gear: EnemyGearConfig

@export_group("Upgraded Enemies")
## Chance (per enemy, per act) of tier 1 on one upgrade path (if its figure has an upgrade tree). Elites and bosses'
## figures use the NEXT act's entry (`EnemyGearConfig.elite_boss_act_shift`).
@export var enemy_tier1_chance: Array[float] = [0.15, 0.30, 0.45]
## Chance (per act) that an enemy that rolled tier 1 reaches tier 2. Only elites and bosses' figures can (regular
## enemies never do); they use the next act's entry. No tier 3 at this level.
@export var elite_tier2_chance: Array[float] = [0.0, 0.25, 0.5]

@export_group("Rising Threat and Bigger Squads")
## Enemies in a regular combat in the base game, in every act.
@export var base_enemies_per_combat := 4
## Bigger Squads: extra enemies in every regular combat.
@export var bigger_squads_extra := 1

@export_group("Leaner Economy")
## Shop prices are multiplied by this and rounded up.
@export var shop_price_multiplier := 1.5

@export_group("Fewer Offers")
@export var max_figure_choices := 2
## Multiplies the chance of every chance drop (power / equipment / finish from fights).
@export var chance_drop_multiplier := 0.5

@export_group("Elite Relics")
## Enemy relics an elite carries in every act.
@export var elite_relics := 1

@export_group("Boss Upgrades")
## The Wall: its creep distance is multiplied by this.
@export var wall_creep_multiplier := 1.5
## Sniper Squad (found by this boss name): total snipers.
@export var sniper_boss_name := "Sniper Squad"
@export var sniper_count := 7
## Trangle: flick spin multiplier and flicks per turn.
@export var trangle_spin_multiplier := 1.5
@export var trangle_flicks := 3
## Slime: pieces each large / medium slime splits into.
@export var slime_pieces := 3
## Skull-o-tron: arms.
@export var skull_arms := 4
## Mad Creator: the floor space that summons `creator_from` summons `creator_to` instead.
@export var creator_from: FigureData
@export var creator_to: FigureData

@export_group("Double Boss")
## The player wins only after beating both act 3 bosses.


func level_name(level: int) -> String:
	return level_names[level] if level >= 0 and level < level_names.size() else "Ascension %d" % level


func level_description(level: int) -> String:
	return level_descriptions[level] if level >= 0 and level < level_descriptions.size() else ""


## Everything that is on at `level`: one line per level from 1 up to it.
func summary(level: int) -> String:
	if level <= 0:
		return "Base game: no extra difficulty."
	var lines: Array[String] = []
	for i in range(1, level + 1):
		lines.append("%d. %s: %s" % [i, level_name(i), level_description(i)])
	return "\n".join(lines)


## The chance in `values` (one per act) for 0-based `act`, optionally shifted to the next act for elites and bosses.
func act_chance(values: Array, act: int) -> float:
	if values.is_empty():
		return 0.0
	return values[clampi(act, 0, values.size() - 1)]
