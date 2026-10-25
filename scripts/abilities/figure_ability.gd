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


## This figure hit another figure at `speed` px/s (relative speed just before the hit) at `point`.
## Called on both figures involved. Like on_hit, but with how hard it was.
func on_impact(_figure: Figure, _other: Figure, _speed: float, _point: Vector2) -> void:
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


## Modifier: how much of an explosion's push `figure` takes (applied before the normal push).
## 1.0 = normal, 0.0 = immune. Collisions use get_knockback_multiplier instead.
func get_explosion_multiplier(_figure: Figure, _source: Figure) -> float:
	return 1.0


## Modifier: how many flicks this figure gets per turn (the extra ones come after the board settles).
func get_flicks_per_turn(_figure: Figure) -> int:
	return 1


## The figure's center just left the table. Return true to save it (e.g. move it back on);
## return false and it is knocked off.
func on_left_table(_figure: Figure, _table: Rect2) -> bool:
	return false


## The figure was knocked off the table (not when it is retired, e.g. a Splitter splitting).
func on_knocked_off(_figure: Figure) -> void:
	pass


## Modifier: multiplies this figure's flick force (Jet Pack's extra flick is half power).
func get_flick_power_multiplier(_figure: Figure) -> float:
	return 1.0


## Modifier: extra aim error (degrees) for enemy shots aimed at this figure (Lucky Charm).
func get_incoming_aim_error_degrees(_figure: Figure) -> float:
	return 0.0


## Modifier for collisions only (not explosions): how much of a hit from `other` this figure
## takes, given the relative `impact_speed`. 0 = ignores it (Anchor).
func get_hit_multiplier(_figure: Figure, _other: Figure, _impact_speed: float) -> float:
	return 1.0


## Helper: call from on_impact. Gives the figure `other` that `figure` just hit extra speed equal to
## `bonus` times the speed it gained from the hit (0.4 = +40% knockback). Only when `figure` is
## the one doing the hitting.
func extra_hit_knockback(figure: Figure, other: Figure, bonus: float) -> void:
	var direction := (other.global_position - figure.global_position).normalized()
	if figure._prev_velocity.dot(direction) + other._prev_velocity.dot(direction) <= 0.0:
		return
	other.nudge((other.linear_velocity - other._prev_velocity) * bonus)
