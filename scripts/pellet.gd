class_name Pellet
extends Area2D
## A small shot from a turret. It flies straight, nudges the first opposing figure it touches (a small
## knockback) and vanishes there, or on a wall or pin, or after `range_left` px. It passes through its own
## side's figures and through turrets.

var team := Figure.Team.PLAYER
var direction := Vector2.UP
var speed := 900.0
var range_left := 520.0
var impulse := 260.0
var radius := 9.0
var owner_figure: Figure  # the Engineer (credited as the source of the knockback)


func _ready() -> void:
	collision_layer = 0
	collision_mask = Figure.LAYER_ARENA | (Figure.LAYER_ENEMY if team == Figure.Team.PLAYER \
			else Figure.LAYER_ON_DECK | Figure.LAYER_FLICKED)
	var circle := CircleShape2D.new()
	circle.radius = radius
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	z_index = 5


func _physics_process(delta: float) -> void:
	var step := speed * delta
	position += direction * step
	range_left -= step
	if range_left <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body is Turret:
		return
	if body is Figure:
		var figure := body as Figure
		if figure.team == team or figure.knocked_off:
			return
		figure.take_knockback.call_deferred(direction * impulse, owner_figure if is_instance_valid(owner_figure) else null)
	queue_free()  # a figure, a wall or a pin


func _draw() -> void:
	var color := Color(1.0, 0.55, 0.45) if team == Figure.Team.ENEMY else Color(0.6, 0.85, 1.0)
	draw_circle(Vector2.ZERO, radius + 3.0, Color(0, 0, 0, 0.45))
	draw_circle(Vector2.ZERO, radius, color)
