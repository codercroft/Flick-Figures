class_name WetExplosionsEffect
extends RelicEffect
## Explosions caused by this side (figures, rockets, landmines, Bomb Drop, implosions) Douse the opposing figures they
## hit: they take more knockback for a few rounds. It is the shared Doused status, so only the strongest Douse applies.

## Rounds the Douse lasts (one round = a player turn plus an enemy turn).
@export var douse_rounds := 2
## Knockback taken multiplier while Doused (1.3 = +30%).
@export var douse_knockback := 1.3


func get_explosion_douse() -> Dictionary:
	return {"rounds": douse_rounds, "knockback": douse_knockback}
