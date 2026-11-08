class_name PowerhouseAbility
extends FigureAbility
## Hits hard (its flick power is on the FigureData), but takes extra knockback from enemy figures.
## Might path (Heavy First Hit): the first hit of each flick lands as if the figure were `first_hit_mass` x heavier.

@export var enemy_knockback_multiplier := 2.0
@export var first_hit_mass := 1.0

var _heavy := false
var _base_mass := 0.0


func get_knockback_multiplier(figure: Figure, source: Figure) -> float:
	if source != null and source.team != figure.team:
		return enemy_knockback_multiplier
	return 1.0


func on_flicked(figure: Figure, _impulse: Vector2) -> void:
	if first_hit_mass > 1.0 and not _heavy:
		_heavy = true
		_base_mass = figure.mass
		figure.mass = _base_mass * first_hit_mass  # (the flick's speed is already set, so it does not slow down)


func on_hit(figure: Figure, _other: Figure) -> void:
	_restore(figure)


func on_stopped(figure: Figure) -> void:
	_restore(figure)


func _restore(figure: Figure) -> void:
	if _heavy:
		_heavy = false
		figure.mass = _base_mass


func get_hit_mass_multiplier(_figure: Figure) -> float:
	return first_hit_mass if first_hit_mass > 1.0 else 1.0
