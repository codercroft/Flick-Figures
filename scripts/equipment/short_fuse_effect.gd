class_name ShortFuseEffect
extends FigureAbility
## When its figure is knocked off the table it implodes: a short pull that sucks nearby figures toward
## the spot where it left the table (so figures near the edge may follow it over).

## How far (px) from that spot the pull reaches, and how hard it pulls at the spot (px/s per second;
## it fades to zero at the radius).
@export var implosion_radius := 300.0
@export var implosion_strength := 1800.0
## How long (seconds) the pull lasts.
@export var implosion_seconds := 0.4


func on_knocked_off(figure: Figure) -> void:
	var parent := figure.get_parent()
	if parent == null:
		return
	var pull := Implosion.new()
	pull.center = figure.global_position
	pull.radius = implosion_radius
	pull.strength = implosion_strength
	pull.seconds = implosion_seconds
	pull.source = figure
	pull.position = figure.global_position
	pull.z_index = 5
	parent.add_child.call_deferred(pull)
