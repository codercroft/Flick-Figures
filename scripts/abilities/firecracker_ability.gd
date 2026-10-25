class_name FirecrackerAbility
extends FigureAbility
## Explodes when hit by an explosion, which can set off other firecrackers (chain reactions).

@export var explosion_radius := 260.0
@export var explosion_force := 1500.0
## After exploding it ignores explosions for this long (ms), so a chain can't loop forever.
@export var rearm_ms := 1500

var _last_exploded_ms := -100000


func on_exploded(figure: Figure, _source: Figure) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_exploded_ms < rearm_ms:
		return
	_last_exploded_ms = now
	figure.explode(explosion_radius, explosion_force)
