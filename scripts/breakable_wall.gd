class_name BreakableWall
extends StaticBody2D
## One wall of the Mad Creator's box. It has health (about two full-power Grunt hits: one deals ~4200) and the same kind of damage
## as Duwall's shell: a hit adds (1 + restitution) x the hitter's mass x its closing speed, an explosion adds its
## push (scaled). Only the PLAYER's figures damage it by hitting (the Creator's own movement and its summons never
## do; Figure._on_body_entered checks that), explosions damage it whoever caused them. Cracks show the damage:
## light at 1/3, heavy at 2/3; at full damage it breaks and is gone.

signal broken(wall: BreakableWall)

## A wall's bounciness (figures bounce off it like off an arena wall).
@export var bounce := 0.8
## Explosion pushes count as damage times this.
@export var explosion_damage_scale := 3.0
@export var color := Color(0.5, 0.42, 0.6)
@export var light_crack_at := 1.0 / 3.0
@export var heavy_crack_at := 2.0 / 3.0

var health := 8000.0
var damage := 0.0
var size := Vector2(100.0, 30.0)
var is_broken := false


func setup(wall_size: Vector2, wall_health: float) -> void:
	size = wall_size
	health = wall_health
	collision_layer = Figure.LAYER_ARENA
	collision_mask = 0
	var material := PhysicsMaterial.new()
	material.bounce = bounce
	material.friction = 0.0
	physics_material_override = material
	var rect := RectangleShape2D.new()
	rect.size = size
	var shape := CollisionShape2D.new()
	shape.shape = rect
	add_child(shape)
	add_to_group("breakable_walls")


## A player figure hit the wall with `velocity` (just before the impact).
func hit_by(figure: Figure, velocity: Vector2) -> void:
	var normal := Vector2.DOWN if size.x >= size.y else Vector2.RIGHT  # the wall's face (walls are axis-aligned)
	var closing := absf(velocity.dot(normal))
	var restitution := clampf(figure.data.bounce + bounce, 0.0, 1.0)
	add_damage((1.0 + restitution) * figure.mass * closing)


## An explosion at `center` pushes with `force` at its middle, fading to 0 at `radius`.
func take_explosion(center: Vector2, radius: float, force: float) -> void:
	var half := size / 2.0
	var local := global_position - center
	var gap := Vector2(maxf(absf(local.x) - half.x, 0.0), maxf(absf(local.y) - half.y, 0.0)).length()
	if gap >= radius:
		return
	add_damage(force * (1.0 - gap / radius) * explosion_damage_scale)


func add_damage(amount: float) -> void:
	if is_broken:
		return
	damage += amount
	queue_redraw()
	if damage >= health:
		is_broken = true
		set_deferred("collision_layer", 0)  # (physics callbacks can't change physics state directly)
		remove_from_group("breakable_walls")
		broken.emit(self)
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.35)
		tween.tween_callback(queue_free)


func damage_fraction() -> float:
	return clampf(damage / health, 0.0, 1.0)


func _draw() -> void:
	var rect := Rect2(-size / 2.0, size)
	draw_rect(rect, color)
	draw_rect(rect, color.lightened(0.35), false, 4.0)
	var fraction := damage_fraction()
	if fraction < light_crack_at:
		return
	var heavy := fraction >= heavy_crack_at
	var rng := RandomNumberGenerator.new()
	rng.seed = get_instance_id()  # the same cracks every frame
	var long_side := maxf(size.x, size.y)
	var horizontal := size.x >= size.y
	var count := 7 if heavy else 3
	for i in count:
		var along := -long_side / 2.0 + long_side * (i + rng.randf()) / count
		var start := Vector2(along, -size.y / 2.0) if horizontal else Vector2(-size.x / 2.0, along)
		var points := PackedVector2Array([start])
		for step in 3:
			var wobble := rng.randf_range(-9.0, 9.0)
			var depth := minf(size.x, size.y) * (step + 1) / 3.0
			points.append(start + (Vector2(wobble, depth) if horizontal else Vector2(depth, wobble)))
		draw_polyline(points, Color(0.1, 0.08, 0.12, 0.9), 5.0 if heavy else 3.0, true)
