class_name ClustlingAbility
extends FigureAbility
## A loose piece of a Cluster. When it collides with its own cluster it rejoins it (the cluster grows back).

## The cluster it was tossed from (set when it is born).
var parent: Figure
## Set by the cluster's upgrades: extra knockback dealt, and a slide back toward the cluster when the turn ends.
var knockback_bonus := 0.0
var slide_home := false
@export var slide_speed := 330.0
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
	if not parent.ability.accept_rejoin(parent, figure.global_position):
		return
	var main := figure.get_tree().current_scene
	if main != null and main.has_method("retire_figure"):
		main.retire_figure(figure)


func get_rejoin_target(_figure: Figure) -> Figure:
	return parent if is_instance_valid(parent) and not parent.knocked_off else null


func get_dealt_knockback_bonus(_figure: Figure, _other: Figure) -> float:
	return knockback_bonus


## Rebound path (Homing Pieces): when its own side's turn ends it slides toward its cluster.
func on_turn_ended(figure: Figure) -> void:
	if not slide_home or not is_instance_valid(parent) or parent.knocked_off or figure.on_deck:
		return
	var main := figure.get_tree().current_scene
	if main == null or not ("turret_side" in main) or main.turret_side != figure.team:
		return
	var offset := parent.global_position - figure.global_position
	if offset.length() > parent.radius + figure.radius + 10.0:
		figure.nudge(offset.normalized() * slide_speed)
