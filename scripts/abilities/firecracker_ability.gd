class_name FirecrackerAbility
extends FigureAbility
## Explodes when a figure on its own team hits it. The blast pushes away everything nearby except
## the friend that hit it. It also explodes when caught in another explosion (chain reactions).
## And when IT hits any figure during its own flick, every other explosive figure of its team on the table
## (Bombo, Sneaky Bomber, other Firecrackers: the registry's "explosive" tag) detonates (once per flick).
## While a Firecracker is on the table, every figure on its team is immune to explosions caused by its own team
## (a faint orange ring shows it). Explosions from the other side still push them.

@export var explosion_radius := 260.0
@export var explosion_force := 1500.0
## After exploding it ignores new triggers for this long (ms), so a chain can't loop forever.
@export var rearm_ms := 1500
## Blast Master path: Full Chains (it also sets off the team's explosives when a TEAMMATE sets it off) and Heavy
## Charges (the explosives it sets off hit this much harder).
@export var full_chains := false
@export var detonation_force := 1.0
## Safety Officer path: share of enemy explosion knockback the team ignores while it is on the table, and how many
## rounds that cover lingers after it is knocked off.
@export var team_explosion_reduction := 0.0
@export var cover_rounds_after_death := 0

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
	if full_chains and spared != null:  # set off by a teammate's hit: the team's explosives follow
		_detonate_team(figure)


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
			if detonation_force != 1.0:
				other.set_meta("detonate_force_mult", detonation_force)
			other.ability.detonate(other)


func get_team_explosion_reduction(_figure: Figure) -> float:
	return team_explosion_reduction


func on_knocked_off(figure: Figure) -> void:
	var main := figure.get_tree().current_scene
	if cover_rounds_after_death > 0 and team_explosion_reduction > 0.0 and main != null and main.has_method("add_lingering_cover"):
		main.add_lingering_cover(figure.team, team_explosion_reduction, cover_rounds_after_death)


## Only enemy Firecrackers shield their team (the player's side is immune to its own explosions by default).
func grants_explosion_immunity(figure: Figure) -> bool:
	return figure.team == Figure.Team.ENEMY


func sets_off_team_explosives(_figure: Figure) -> bool:
	return true


func get_ai_blast(_figure: Figure) -> Dictionary:
	return {"radius": explosion_radius, "force": explosion_force, "when": "ally_hit"}
