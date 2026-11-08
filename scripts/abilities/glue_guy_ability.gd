class_name GlueGuyAbility
extends FigureAbility
## Sticks to the figure it collides with: the two then move as one heavier body (a goo link is drawn
## between them). While stuck it ignores other figures. When the figure it is stuck to is knocked off (or an
## explosion breaks the glue) Glue Guy is free again and sticks to the next figure it collides with.
##
## Upgrade (Goo Chain, `chain_sticky`): it can stick to several figures, and every figure stuck to it
## (or to those) becomes sticky too, so chains form. The whole chain never exceeds `chain_size_cap`.

## Upgrade switch: stick to several figures and make stuck figures sticky.
@export var chain_sticky := false
## The biggest chain (figures glued together, Glue Guy included). Keeps the physics stable.
@export var chain_size_cap := 5
## Sticky path: +1 flick per figure it is stuck to, and opposing figures stuck to it weigh this much (x) while stuck.
@export var flick_per_stuck := false
@export var stuck_enemy_mass := 1.0
## Tar path: x flick power of an enemy stuck to it (0 = can't flick), and Glue Guy's own mass and flick power (x) while
## it is stuck to something.
@export var stuck_enemy_flick := 1.0
@export var self_stuck_mass := 1.0
@export var self_stuck_power := 1.0

var _squeezed := {}  # instance id -> [figure, original mass]
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
	if stuck_enemy_mass != 1.0:
		for partner in partners:
			if partner.team != figure.team and not _squeezed.has(partner.get_instance_id()):
				_squeezed[partner.get_instance_id()] = [partner, partner.mass]
				partner.set_size(partner.radius, partner.mass * stuck_enemy_mass)
		for id in _squeezed.keys():
			var entry: Array = _squeezed[id]
			if not is_instance_valid(entry[0]) or not partners.has(entry[0]):
				if is_instance_valid(entry[0]):
					entry[0].set_size(entry[0].radius, entry[1])
				_squeezed.erase(id)
	if self_stuck_mass != 1.0 and _base_mass > 0.0:
		figure.set_size(figure.radius, _base_mass * (self_stuck_mass if not partners.is_empty() else 1.0))


func on_hit(figure: Figure, other: Figure) -> void:
	if figure.knocked_off or other.knocked_off:
		return
	var cluster := figure.glue_cluster()
	if cluster.has(other):
		return  # already stuck together
	if figure.is_glued() and not chain_sticky:
		return  # one figure at a time
	var merged := cluster.duplicate()
	for member in other.glue_cluster():
		if not merged.has(member):
			merged.append(member)
	var cap := chain_size_cap if chain_sticky else 2
	if merged.size() > cap:
		return
	figure.glue_to(other)


func get_glue_chain_cap(_figure: Figure) -> int:
	return chain_size_cap if chain_sticky else 0
