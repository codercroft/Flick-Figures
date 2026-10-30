class_name Projectile
extends Area2D
## Blastoid's shot: flies straight, and explodes (a minor blast through Figure.blast, so Firecracker, Duwall's shell,
## Blast Cap and the other explosion effects all react) when it touches a figure, wall or pin, or at its max range.
## The firing Blastoid is never pushed by it.

var owner_figure: Figure
var direction := Vector2.UP
var speed := 1000.0
var range_left := 600.0
var radius := 14.0
var blast_radius := 170.0
var blast_force := 800.0
var _done := false


func _ready() -> void:
	add_to_group("projectiles")  # (main.gd waits for them before ending a turn)
	collision_layer = 0
	collision_mask = Figure.LAYER_ON_DECK | Figure.LAYER_FLICKED | Figure.LAYER_ENEMY | Figure.LAYER_ARENA
	var circle := CircleShape2D.new()
	circle.radius = radius
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	z_index = 5


func _physics_process(delta: float) -> void:
	if _done:
		return
	var step := speed * delta
	position += direction * step
	range_left -= step
	if range_left <= 0.0:
		_explode()


func _on_body_entered(body: Node) -> void:
	if body == owner_figure:
		return
	_explode()


func _explode() -> void:
	if _done:
		return
	_done = true
	var reach := blast_radius * RunManager.relic_explosion_multiplier()  # Blast Cap
	Figure.blast(get_tree(), global_position, reach, blast_force, owner_figure)
	var effect := BlastEffect.new()
	effect.position = position
	effect.z_index = 6
	get_parent().add_child(effect)
	effect.start(reach)
	remove_from_group("projectiles")
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 4.0, Color(1.0, 0.5, 0.1, 0.4))
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.8, 0.3))
	draw_circle(Vector2(-3, -3), radius * 0.35, Color(1, 1, 0.9))
	draw_line(Vector2.ZERO, -direction * radius * 2.6, Color(1.0, 0.6, 0.2, 0.6), 7.0)
