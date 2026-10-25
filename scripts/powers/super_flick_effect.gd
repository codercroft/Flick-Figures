class_name SuperFlickEffect
extends PowerEffect
## Your next flick has extra power.

## The next flick's force is multiplied by this.
@export var multiplier := 3.0


func can_use(main) -> String:
	return "Super Flick is already ready" if main.flick_boost > 1.0 else ""


func apply(main, _targets: Array) -> bool:
	main.flick_boost = multiplier
	return true
