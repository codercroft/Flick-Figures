class_name GlueGuyAbility
extends FigureAbility
## Sticks to the figure it collides with: the two then move as one heavier body (a goo link is drawn
## between them). While stuck it ignores other figures. When the figure it is stuck to is knocked off (or an
## explosion breaks the glue) Glue Guy is free again and sticks to the next figure it collides with.
##
## Sticky path: it can stick to up to `max_stuck` figures at once (1 at base, 3, then 5); figures stuck to it do NOT become sticky
## themselves (no chains: every glued figure is joined straight to Glue Guy, which keeps the physics stable). Sticky Flicks
## (`flick_per_stuck`): +1 flick per figure stuck to it.
@export var max_stuck := 1
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
	return 1 + (figure.glue_partners().size() if flick_per_stuck else 0)


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
	if figure.glue_partners().has(other) or other.is_glued():
		return  # already stuck, or stuck to something else (no chains)
	if figure.glue_partners().size() >= max_stuck:
		return
	figure.glue_to(other)


## Enemy AI: how many figures it can hold (+1, so the AI's "more than 2" check means "can hold several").
func get_glue_chain_cap(_figure: Figure) -> int:
	return max_stuck + 1 if max_stuck > 1 else 0
