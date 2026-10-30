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
