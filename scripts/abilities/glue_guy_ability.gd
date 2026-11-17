class_name GlueGuyAbility
extends FigureAbility
## Sticks to the figure it collides with: the two then move as one heavier body (a goo link is drawn
## between them). While stuck it ignores other figures. When the figure it is stuck to is knocked off (or an
## explosion breaks the glue) Glue Guy is free again and sticks to the next figure it collides with.
##
## Sticky path: tiers 1 and 2 (`chain_sticky`) make every figure stuck to its cluster sticky too: it glues to the next free figure
## it hits, which becomes sticky in turn, so the glue spreads as a chain. The whole cluster, not counting Glue Guy, holds at most
## `max_stuck` figures (1 at base, 3 with Sticky Grip, 5 with Sticky Mess); once full nothing else sticks. A figure is sticky only
## while it is part of Glue Guy's cluster. Sticky Flicks (`flick_per_stuck`): +1 flick per figure in the cluster.
@export var max_stuck := 1
@export var chain_sticky := false
@export var flick_per_stuck := false
## Tar path: x flick power of an enemy stuck to it (0 = can't flick; Locked Down: 0.5), and Glue Guy's own mass and flick power
## (x) while it is stuck to something.
@export var stuck_enemy_flick := 1.0
@export var self_stuck_mass := 1.0
@export var self_stuck_power := 1.0

var _base_mass := 0.0


func setup_body(figure: Figure) -> void:
	_base_mass = figure.mass


func get_flicks_per_turn(figure: Figure) -> int:
	return 1 + (stuck_count(figure) if flick_per_stuck else 0)


## Figures in Glue Guy's whole cluster, not counting Glue Guy.
func stuck_count(figure: Figure) -> int:
	return figure.glue_cluster().size() - 1


func get_stuck_enemy_flick_multiplier(_figure: Figure) -> float:
	return stuck_enemy_flick


func get_flick_power_multiplier(figure: Figure) -> float:
	return self_stuck_power if figure.is_glued() else 1.0


func on_physics_process(figure: Figure, _delta: float) -> void:
	var partners := figure.glue_partners()
	if self_stuck_mass != 1.0 and _base_mass > 0.0:
		figure.set_size(figure.radius, _base_mass * (self_stuck_mass if not partners.is_empty() else 1.0))


func on_hit(figure: Figure, other: Figure) -> void:
	if figure.knocked_off or other.knocked_off:
		return
	if figure.glue_cluster().has(other) or other.is_glued():
		return  # already stuck, or stuck to something else
	if stuck_count(figure) >= max_stuck:
		return
	figure.glue_to(other)


## Chain-sticky glue: max_stuck + 1 (so figures stuck to the cluster count as sticky and the AI can read the cap), 0 = no chains.
func get_glue_chain_cap(_figure: Figure) -> int:
	return max_stuck + 1 if chain_sticky else 0
