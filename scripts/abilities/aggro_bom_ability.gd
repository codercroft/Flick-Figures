class_name AggroBomAbility
extends FigureAbility
## Counts its collisions: at `collisions_needed` it immediately unleashes a powerful explosion (bigger than
## Bombo's) and survives it. The count carries over between turns and only goes back to 0 after it explodes (and
## at the start of each combat). Every hit counts, even on the same figure, but a pair of figures cannot count
## again within `pair_cooldown` seconds (a single grinding contact is one hit). Small pips show the count.

## How many collisions it needs (the upgrade lowers this to 3).
@export var collisions_needed := 4
## The same pair of figures can only count again after this long (seconds).
@export var pair_cooldown := 0.2
## The explosion (a Bombo's is 224 / 900).
@export var explosion_radius := 320.0
@export var explosion_force := 1500.0
@export var pip_color := Color(1.0, 0.85, 0.3)
## Rage path: extra knockback dealt, and extra mass and flick power, for each hit counted so far.
@export var rage_knockback_per_hit := 0.0
@export var rage_power_per_hit := 0.0

var _count := 0
var _base_mass := 0.0
var _last_hit_ms := {}  # other figure's instance id -> when it last counted


func setup_body(figure: Figure) -> void:
	_base_mass = figure.mass


func get_dealt_knockback_bonus(_figure: Figure, _other: Figure) -> float:
	return rage_knockback_per_hit * _count


func get_flick_power_multiplier(_figure: Figure) -> float:
	return 1.0 + rage_power_per_hit * _count


func _apply_rage(figure: Figure) -> void:
	if rage_power_per_hit > 0.0 and _base_mass > 0.0:
		figure.set_size(figure.radius, _base_mass * (1.0 + rage_power_per_hit * _count))
	figure.queue_redraw()


func on_hit(figure: Figure, other: Figure) -> void:
	if figure.knocked_off:
		return
	var id := other.get_instance_id()
	var now := Time.get_ticks_msec()
	if now - int(_last_hit_ms.get(id, -100000)) < int(pair_cooldown * 1000.0):
		return  # the same contact still grinding
	_last_hit_ms[id] = now
	_count += 1
	_apply_rage(figure)
	if _count >= collisions_needed:
		_count = 0
		_apply_rage(figure)
		figure.show_popup("Aggro!", Color(1.0, 0.5, 0.2))
		figure.explode(explosion_radius, explosion_force)


## Enemy AI: how close it is, and what the explosion would be.
func get_ai_aggro(_figure: Figure) -> Dictionary:
	return {"needed": collisions_needed, "met": _count, "radius": explosion_radius, "force": explosion_force}


func get_ai_blast(_figure: Figure) -> Dictionary:
	return {"radius": explosion_radius, "force": explosion_force, "when": "detonate"}


## Set off by a teammate (the explosive tag): the big blast right now.
func detonate(figure: Figure) -> void:
	figure.explode(explosion_radius, explosion_force)


## The pips above the figure: one per collision needed, filled for each collision counted so far.
func draw_overlay(figure: Figure) -> void:
	var spacing := 22.0
	var start_x := -spacing * (collisions_needed - 1) / 2.0
	var y := -figure.radius - 18.0
	for i in collisions_needed:
		var center := Vector2(start_x + spacing * i, y)
		if i < _count:
			figure.draw_circle(center, 8.0, pip_color)
		else:
			figure.draw_arc(center, 7.0, 0.0, TAU, 16, pip_color, 3.0, true)
