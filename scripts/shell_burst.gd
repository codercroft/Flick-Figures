class_name ShellBurst
extends Node2D
## The "shell bursts open" effect: a handful of green shell chips fly outward and fade.

var _chips: Array[Dictionary] = []
var _age := 0.0
const LIFETIME := 0.7


static func spawn(figure: Figure, _grunt_color: Color) -> void:
	var parent := figure.get_parent()
	if parent == null:
		return
	var burst := ShellBurst.new()
	burst.position = figure.position
	burst.z_index = 6
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 10:
		var angle := rng.randf() * TAU
		burst._chips.append({"direction": Vector2.from_angle(angle), "speed": rng.randf_range(180.0, 420.0),
				"size": rng.randf_range(9.0, 20.0), "spin": rng.randf_range(-8.0, 8.0), "angle": angle,
				"start": figure.radius * 0.5})
	parent.add_child(burst)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var fade := 1.0 - _age / LIFETIME
	for chip in _chips:
		var center: Vector2 = chip.direction * (chip.start + chip.speed * _age)
		var angle: float = chip.angle + chip.spin * _age
		var size: float = chip.size
		var a := center + Vector2.from_angle(angle) * size
		var b := center + Vector2.from_angle(angle + 2.1) * size * 0.8
		var c := center + Vector2.from_angle(angle + 4.2) * size * 0.8
		draw_colored_polygon(PackedVector2Array([a, b, c]), Color(0.3, 0.6, 0.4, fade))
		draw_polyline(PackedVector2Array([a, b, c, a]), Color(0.1, 0.25, 0.15, fade), 2.0)
