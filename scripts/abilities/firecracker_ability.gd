class_name FirecrackerAbility
extends FigureAbility
## Explodes when a figure on its own team hits it. The blast pushes away everything nearby except
## the friend that hit it. It also explodes when caught in another explosion (chain reactions).
## And when IT hits any figure during its own flick, every other explosive figure of its team on the table
## (Bombo, Sneaky Bomber, other Firecrackers: the registry's "explosive" tag) detonates (once per flick).

@export var explosion_radius := 260.0
@export var explosion_force := 1500.0
## After exploding it ignores new triggers for this long (ms), so a chain can't loop forever.
@export var rearm_ms := 1500

var _last_exploded_ms := -100000
var _flicking := false
var _set_off_team := false


func on_flicked(_figure: Figure, _impulse: Vector2) -> void:
	_flicking = true
	_set_off_team = false


func on_stopped(_figure: Figure) -> void:
	_flicking = false


func on_hit(figure: Figure, other: Figure) -> void:
	if other.team == figure.team:
		_explode(figure, other)
	if _flicking and not _set_off_team:
		_set_off_team = true
		_detonate_team(figure)


func on_exploded(figure: Figure, _source: Figure) -> void:
	_explode(figure, null)


func detonate(figure: Figure) -> void:
	_explode(figure, null)


func _explode(figure: Figure, spared: Figure) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_exploded_ms < rearm_ms:
		return
	_last_exploded_ms = now
	figure.explode(explosion_radius, explosion_force, spared)


## Sets off every other explosive figure of this figure's team that is on the table.
func _detonate_team(figure: Figure) -> void:
	var registry := RunManager.config.registry if RunManager.config != null else null
	if registry == null:
		return
	for node in figure.get_tree().get_nodes_in_group("figures"):
		var other := node as Figure
		if other == figure or other.knocked_off or other.team != figure.team or other.on_deck:
			continue
		if registry.is_explosive(other.base_data):
			other.ability.detonate(other)


func sets_off_team_explosives(_figure: Figure) -> bool:
	return true


func get_ai_blast(_figure: Figure) -> Dictionary:
	return {"radius": explosion_radius, "force": explosion_force, "when": "ally_hit"}
