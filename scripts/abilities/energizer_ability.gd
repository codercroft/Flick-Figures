class_name EnergizerAbility
extends FigureAbility
## The first allied figure it hits during its own flick is recharged: it can be flicked again this cycle
## (a small spark effect shows it).
## Charge path: it recharges EVERY ally it hits (`recharge_all`), recharged allies flick with +x power next time
## (`ally_power_bonus`) and can flick right now (`instant_recharge`: they get a flick as soon as this one settles).
## Shock path: enemies it hits flick with this share of power (`shock_flick`) until they next flick, the shock chains to
## enemies within `chain_radius` of the one hit, and `stun` stops them flicking for a round.

@export var recharge_all := false
@export var ally_power_bonus := 0.0
@export var instant_recharge := false
@export var shock_flick := 1.0
@export var shock_chain := false
@export var chain_radius := 260.0
@export var stun := false

var _flicking := false
var _used := false


func on_flicked(_figure: Figure, _impulse: Vector2) -> void:
	_flicking = true
	_used = false


func on_stopped(_figure: Figure) -> void:
	_flicking = false


func on_hit(figure: Figure, other: Figure) -> void:
	if not _flicking or other.knocked_off or figure.knocked_off:
		return
	if other.team != figure.team:
		_shock(figure, other)
		return
	if _used and not recharge_all:
		return
	var combat = RunManager.combat
	if combat == null:
		return
	_used = true
	combat.recharge_figure(other)
	if ally_power_bonus > 0.0:
		other.charge_power = 1.0 + ally_power_bonus
	if instant_recharge:
		combat.grant_bonus_flick(other)
	SparkEffect.spawn(other.get_parent(), other.position)
	other.show_popup("Recharged!", Color(1.0, 0.95, 0.4))


func _shock(figure: Figure, victim: Figure) -> void:
	if shock_flick >= 1.0 and not stun:
		return
	var victims: Array[Figure] = [victim]
	if shock_chain:
		for node in figure.get_tree().get_nodes_in_group("figures"):
			var other := node as Figure
			if other != null and other != victim and not other.knocked_off and other.team == victim.team \
					and other.global_position.distance_to(victim.global_position) <= chain_radius:
				victims.append(other)
	for target in victims:
		if shock_flick < 1.0:
			target.shock_flick = shock_flick
		if stun:
			target.stunned_rounds = 1
			if target.team == Figure.Team.PLAYER:
				target.flickable = false
			elif RunManager.combat != null:
				RunManager.combat._enemy_cycle[target.get_instance_id()] = true
		target.show_popup("Shocked!", Color(1.0, 0.95, 0.4))


func recharges_first_ally(_figure: Figure) -> bool:
	return true
