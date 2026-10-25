class_name FigureAbility
extends Resource
## Base class for figure abilities. Make a new ability by extending this script and
## overriding any of the hooks below. There are event hooks (on_*) and one modifier hook. Every figure gets its own copy of its ability,
## so it is safe to keep per-figure state in variables.


## This figure was just flicked (by the player or an enemy).
func on_flicked(_figure: Figure, _impulse: Vector2) -> void:
	pass


## This figure bumped into another figure. Called on both figures involved.
func on_hit(_figure: Figure, _other: Figure) -> void:
	pass


## This figure was moving and has now come to rest.
func on_stopped(_figure: Figure) -> void:
	pass


## This figure was pushed by an explosion set off by `source`.
func on_exploded(_figure: Figure, _source: Figure) -> void:
	pass


## Called every physics frame (for abilities that act continuously, like a magnet).
func on_physics_process(_figure: Figure, _delta: float) -> void:
	pass


## Modifier, not an event: how much knockback `figure` takes from `source` (a figure that hit
## it or exploded next to it; null if unknown). 1.0 = normal, 2.0 = double.
func get_knockback_multiplier(_figure: Figure, _source: Figure) -> float:
	return 1.0
