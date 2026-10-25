class_name GlueGuyAbility
extends FigureAbility
## The first figure it collides with sticks to it. The two then move as one heavier body until
## the end of the combat, or until an explosion hits either of them.

var _used := false


func on_hit(figure: Figure, other: Figure) -> void:
	if _used or figure.knocked_off or other.knocked_off:
		return
	_used = true
	figure.glue_to(other)
