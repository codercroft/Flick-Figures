class_name ClustlingAbility
extends FigureAbility
## A loose piece of a Cluster. When it collides with its own cluster it rejoins it (the cluster grows back).

## The cluster it was tossed from (set when it is born).
var parent: Figure
## It can't rejoin in the first moments after being tossed.
@export var rejoin_delay_ms := 400

var _born_ms := 0


func setup_body(_figure: Figure) -> void:
	_born_ms = Time.get_ticks_msec()


func on_hit(figure: Figure, other: Figure) -> void:
	if figure.knocked_off or other != parent or not is_instance_valid(parent) or parent.knocked_off:
		return
	if Time.get_ticks_msec() - _born_ms < rejoin_delay_ms:
		return
	if not parent.ability.accept_rejoin(parent):
		return
	var main := figure.get_tree().current_scene
	if main != null and main.has_method("retire_figure"):
		main.retire_figure(figure)


func get_rejoin_target(_figure: Figure) -> Figure:
	return parent if is_instance_valid(parent) and not parent.knocked_off else null
