class_name BomboAbility
extends FigureAbility
## Explodes on its first hit after each flick, pushing nearby figures away.

@export var explosion_radius := 200.0
## Push at the center of the blast; fades to zero at the edge. Like a flick force.
@export var explosion_force := 900.0
## Upgrade: explode on EVERY hit instead of only the first after a flick.
@export var explode_every_hit := false
## Shrapnel path: its explosion also sets off allied explosives / it also explodes when knocked off.
@export var sets_off_allies := false
@export var explode_on_knock_off := false

var _exploded := false


func on_flicked(_figure: Figure, _impulse: Vector2) -> void:
	_exploded = false


func on_hit(figure: Figure, _other: Figure) -> void:
	if _exploded and not explode_every_hit:
		return
	_exploded = true
	figure.explode(explosion_radius, explosion_force)
	if sets_off_allies:
		detonate_allies(figure)


func on_knocked_off(figure: Figure) -> void:
	if explode_on_knock_off:
		figure.explode(explosion_radius, explosion_force)


func detonate(figure: Figure) -> void:
	figure.explode(explosion_radius, explosion_force)


func get_ai_blast(_figure: Figure) -> Dictionary:
	return {"radius": explosion_radius, "force": explosion_force, "when": "hit"}
