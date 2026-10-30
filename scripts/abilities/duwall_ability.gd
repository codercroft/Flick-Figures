class_name DuwallAbility
extends FigureAbility
## Duwall's breakable shell. While the shell is intact Duwall keeps its usual (heavy, tough) stats. Every
## impact it takes adds shell damage in proportion to the impact's strength: the momentum the other body
## gives it (reduced mass x closing speed x (1 + bounce), the part that comes from the OTHER figure moving),
## or the push of an explosion. When the total reaches `shell_strength` the shell bursts and Duwall becomes a
## Grunt for the rest of the combat (it keeps its equipment and finish). The shell is whole again at the
## start of every combat (each combat spawns fresh figures).

## Total shell damage that breaks the shell: about 3 full-power Grunt hits. Measured headless: a full-power Grunt
## flick (impulse 2400) into a resting Duwall deals ~3100 from 250 px away and ~2700 from 450 px away (the speed
## at contact falls with distance), so 3 hits = about 8000.
@export var shell_strength := 8000.0
## What it becomes when the shell breaks.
@export var broken_form: FigureData
## Explosion pushes (impulse) count as shell damage times this.
@export var explosion_damage_scale := 1.0
## Cracks appear at these fractions of the shell strength (light, then heavy).
@export var light_crack_at := 1.0 / 3.0
@export var heavy_crack_at := 2.0 / 3.0

var damage := 0.0
var broken := false


func on_impact(figure: Figure, other: Figure, _speed: float, _point: Vector2) -> void:
	if broken or figure.knocked_off:
		return
	var inward := (figure.global_position - other.global_position).normalized()
	# Pre-collision velocities: how fast the other one came at us, and how fast we went at it.
	var other_closing := maxf(other._prev_velocity.dot(inward), 0.0)
	var my_closing := maxf(-figure._prev_velocity.dot(inward), 0.0)
	var closing := other_closing + my_closing
	if closing <= 0.0:
		return
	var reduced_mass := figure.mass * other.mass / (figure.mass + other.mass)
	var restitution := clampf(figure.data.bounce + other.data.bounce, 0.0, 1.0)
	_add_damage(figure, (1.0 + restitution) * reduced_mass * closing * (other_closing / closing))


func on_took_explosion(figure: Figure, impulse: Vector2) -> void:
	if not broken:
		_add_damage(figure, impulse.length() * explosion_damage_scale)


func _add_damage(figure: Figure, amount: float) -> void:
	damage += amount
	figure.queue_redraw()
	if damage >= shell_strength:
		_break(figure)


func _break(figure: Figure) -> void:
	broken = true
	if broken_form != null:
		figure.transform_into(broken_form)
	figure.shell_broken = true
	figure.show_popup("Shell burst!", Color(1.0, 0.85, 0.5))
	ShellBurst.spawn(figure, figure.data.color)
	figure.queue_redraw()


## 0 (new) to 1 (about to burst).
func shell_fraction() -> float:
	return clampf(damage / shell_strength, 0.0, 1.0)


## For the enemy AI: {remaining, max} while the shell is intact, {} otherwise.
func get_shell_state(_figure: Figure) -> Dictionary:
	if broken:
		return {}
	return {"remaining": shell_strength - damage, "max": shell_strength}


## What a hit would add to the shell (the AI uses this to value cracking it).
func predict_shell_damage(figure: Figure, shooter: Figure, closing_speed: float) -> float:
	var reduced_mass := figure.mass * shooter.mass / (figure.mass + shooter.mass)
	var restitution := clampf(figure.data.bounce + shooter.data.bounce, 0.0, 1.0)
	return (1.0 + restitution) * reduced_mass * closing_speed


func draw_overlay(figure: Figure) -> void:
	var fraction := shell_fraction()
	if broken:
		_draw_shell_bits(figure)
		return
	if fraction < light_crack_at:
		return
	var heavy := fraction >= heavy_crack_at
	var rng := RandomNumberGenerator.new()
	rng.seed = figure.get_instance_id()  # the same cracks every frame
	var count := 6 if heavy else 3
	var color := Color(0.1, 0.12, 0.1, 0.85)
	var width := 5.0 if heavy else 3.0
	for i in count:
		var angle := TAU * i / count + rng.randf_range(-0.3, 0.3)
		var points := PackedVector2Array([Vector2.ZERO])
		var length := figure.radius * (0.95 if heavy else 0.7)
		var direction := Vector2.from_angle(angle)
		for step in 4:
			var along := length * (step + 1) / 4.0
			points.append(direction * along + direction.orthogonal() * rng.randf_range(-9.0, 9.0))
		figure.draw_polyline(points, color, width, true)


## Leftover bits of shell on the Grunt: small chips near the rim.
func _draw_shell_bits(figure: Figure) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = figure.get_instance_id() + 7
	for i in 5:
		var angle := rng.randf() * TAU
		var spot := Vector2.from_angle(angle) * figure.radius * rng.randf_range(0.55, 0.92)
		var size := figure.radius * rng.randf_range(0.1, 0.17)
		var shell_color := Color(0.3, 0.6, 0.4)
		figure.draw_colored_polygon(PackedVector2Array([spot + Vector2(-size, size * 0.5), spot + Vector2(0, -size), spot + Vector2(size, size * 0.4)]), shell_color)
