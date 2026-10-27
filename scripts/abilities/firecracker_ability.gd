class_name FirecrackerAbility
extends FigureAbility
## Explodes when a figure on its own team hits it. The blast pushes away everything nearby except
## the friend that hit it. It also explodes when caught in another explosion (chain reactions).

@export var explosion_radius := 260.0
@export var explosion_force := 1500.0
## After exploding it ignores new triggers for this long (ms), so a chain can't loop forever.
@export var rearm_ms := 1500

var _last_exploded_ms := -100000


func on_hit(figure: Figure, other: Figure) -> void:
	if other.team == figure.team:
		_explode(figure, other)


func on_exploded(figure: Figure, _source: Figure) -> void:
	_explode(figure, null)


func _explode(figure: Figure, spared: Figure) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_exploded_ms < rearm_ms:
		return
	_last_exploded_ms = now
	figure.explode(explosion_radius, explosion_force, spared)


func get_ai_blast(_figure: Figure) -> Dictionary:
	return {"radius": explosion_radius, "force": explosion_force, "when": "ally_hit"}
