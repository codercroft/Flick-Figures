class_name EarthquakeEffect
extends PowerEffect
## Every figure on the table gets a small random shove.

## Each figure gets a shove between these speeds (px/s), in a random direction.
@export var min_shove_speed := 90.0
@export var max_shove_speed := 280.0


func _init() -> void:
	settle_after = true


func apply(main, _targets: Array) -> bool:
	for figure in main.get_all_figures():
		figure.nudge(Vector2.from_angle(randf() * TAU) * randf_range(min_shove_speed, max_shove_speed))
	return true
