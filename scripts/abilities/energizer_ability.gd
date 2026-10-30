class_name EnergizerAbility
extends FigureAbility
## The first allied figure it hits during its own flick is recharged: it can be flicked again this cycle
## (a small spark effect shows it).

var _flicking := false
var _used := false


func on_flicked(_figure: Figure, _impulse: Vector2) -> void:
	_flicking = true
	_used = false


func on_stopped(_figure: Figure) -> void:
	_flicking = false


func on_hit(figure: Figure, other: Figure) -> void:
	if not _flicking or _used or other.team != figure.team or other.knocked_off or figure.knocked_off:
		return
	var combat = RunManager.combat
	if combat == null:
		return
	_used = true
	combat.recharge_figure(other)
	SparkEffect.spawn(other.get_parent(), other.position)
	other.show_popup("Recharged!", Color(1.0, 0.95, 0.4))


func recharges_first_ally(_figure: Figure) -> bool:
	return true
