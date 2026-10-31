class_name RelicEffect
extends Resource
## Base class for relic effects. Override the hooks you need; every default does nothing.
## RunManager asks all held relics at the right moments (see its relic_* functions), so a new
## relic only needs a subclass here. `RunManager.combat` is the Main node while a combat runs.


## The relic was just added to the run (e.g. Extra Pocket adds a deck slot).
func on_acquired(_run) -> void:
	pass


## --- Combat: stat calculations ---

## Multiplies the size of every explosion.
func get_explosion_radius_multiplier() -> float:
	return 1.0


## Multiplies the force of a flick by the player's `figure` (main = the Main node).
func get_flick_power_multiplier(_main, _figure: Figure) -> float:
	return 1.0


## Multiplies the damping of the player's figures (above 1 = they stop sooner).
func get_player_damping_multiplier() -> float:
	return 1.0


## Multiplies how much knockback `figure` takes (`source` is whoever hit it or exploded, or null).
func get_knockback_taken_multiplier(_figure: Figure, _source: Figure) -> float:
	return 1.0


## Multiplies the strength of magnet-type pulls.
func get_pull_multiplier() -> float:
	return 1.0


## --- Combat: rules and events ---

## True turns on the old reload rule.
func enables_reload() -> bool:
	return false


## True makes the aim line show the first bounce.
func shows_aim_bounce() -> bool:
	return false


## The enemy's first turn of a combat is about to start (before its first shot). Return how many seconds the
## enemy should wait (for an animation), 0 for none.
func on_first_enemy_turn(_main) -> float:
	return 0.0


## One of the player's figures is about to be knocked off. Return true to save it.
func on_player_figure_falling(_main, _figure: Figure) -> bool:
	return false


## --- Run: rewards ---

## Extra money after every won combat.
func get_income_bonus() -> int:
	return 0


## Extra choices on a figure reward screen.
func get_reward_choice_bonus() -> int:
	return 0


## A combat was won. `info` has "figures_lost". Return a short message for the reward screen, or "".
func on_combat_won(_run, _info: Dictionary) -> String:
	return ""
