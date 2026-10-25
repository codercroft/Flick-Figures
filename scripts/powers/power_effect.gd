class_name PowerEffect
extends Resource
## Base class for what a power does. Subclass it, set `target_mode` in _init(), and override
## can_use() / apply(). `main` is the Main node (main.gd); use its "Powers API" functions.

enum Target {
	NONE,  ## used right away
	ENEMY,  ## tap an enemy figure
	OWN_FIGURE,  ## tap one of your figures
	TWO_FIGURES,  ## tap two figures
	POINT,  ## tap a point on the board
}

## What the player has to tap (set by each subclass in _init).
var target_mode := Target.NONE
## True if the power moves figures, so the game waits for the board to settle afterwards.
var settle_after := false
## Shown in the bottom bar while choosing a target.
@export var prompt := ""


## Return "" if the power can be used right now, or a short reason why not.
func can_use(_main) -> String:
	return ""


## Do the thing. `targets` holds what was tapped: Figures, or one Vector2 for POINT.
## Return false if it could not be done (the power is not used up).
func apply(_main, _targets: Array) -> bool:
	return true
