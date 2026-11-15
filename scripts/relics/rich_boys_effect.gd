class_name RichBoysEffect
extends RelicEffect
## After a won combat every figure that still pays income pays this much more ($1 + $1 = $2 by default).

@export var extra_per_figure := 1


func get_income_per_figure_bonus() -> int:
	return extra_per_figure
