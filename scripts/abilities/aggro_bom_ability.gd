class_name AggroBomAbility
extends FigureAbility
## Counts how many DIFFERENT figures it collides with during one turn (either side's turn: the count resets
## when a turn ends). At `collisions_needed` it immediately unleashes a powerful explosion (bigger than
## Bombo's) and survives it, and the count starts again. Small pips on the figure show the count.

## How many different figures it must bump in one turn (the upgrade lowers this to 2).
@export var collisions_needed := 3
## The explosion (a Bombo's is 224 / 900).
@export var explosion_radius := 320.0
@export var explosion_force := 1500.0
@export var pip_color := Color(1.0, 0.85, 0.3)

var _met: Array[int] = []  # instance ids of the figures bumped this turn


func on_hit(figure: Figure, other: Figure) -> void:
	if figure.knocked_off:
		return
	var id := other.get_instance_id()
	if _met.has(id):
		return
	_met.append(id)
	figure.queue_redraw()
	if _met.size() >= collisions_needed:
		_met.clear()
		figure.show_popup("Aggro!", Color(1.0, 0.5, 0.2))
		figure.explode(explosion_radius, explosion_force)


func on_turn_ended(figure: Figure) -> void:
	if not _met.is_empty():
		_met.clear()
		figure.queue_redraw()


## Enemy AI: how close it is, and what the explosion would be.
func get_ai_aggro(_figure: Figure) -> Dictionary:
	return {"needed": collisions_needed, "met": _met.size(), "radius": explosion_radius, "force": explosion_force}


func get_ai_blast(_figure: Figure) -> Dictionary:
	return {"radius": explosion_radius, "force": explosion_force, "when": "detonate"}


## Set off by a teammate Firecracker: the big blast right now.
func detonate(figure: Figure) -> void:
	figure.explode(explosion_radius, explosion_force)


## The pips above the figure: one per collision needed, filled for each different figure bumped so far.
func draw_overlay(figure: Figure) -> void:
	var spacing := 22.0
	var start_x := -spacing * (collisions_needed - 1) / 2.0
	var y := -figure.radius - 18.0
	for i in collisions_needed:
		var center := Vector2(start_x + spacing * i, y)
		if i < _met.size():
			figure.draw_circle(center, 8.0, pip_color)
		else:
			figure.draw_arc(center, 7.0, 0.0, TAU, 16, pip_color, 3.0, true)
