class_name Droplet
extends Area2D
## One drop of Spitter's spray. It flies straight, gives the first opposing figure it touches a light push and
## vanishes there, on a wall or pin, or after `range_left` px. It passes through its own side's figures.

var team := Figure.Team.PLAYER
var direction := Vector2.UP
var speed := 800.0
var range_left := 450.0
var impulse := 35.0
var radius := 8.0
var owner_figure: Figure


func _ready() -> void:
	add_to_group("projectiles")  # the board is not "settled" while drops fly
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
		if figure.is_slow():
			figure.last_pellet_ms = Time.get_ticks_msec()
		figure.take_knockback.call_deferred(direction * impulse, owner_figure if is_instance_valid(owner_figure) else null)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.45, 0.75, 1.0, 0.85))
