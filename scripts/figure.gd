class_name Figure
extends RigidBody2D
## One toy figure (player or enemy): a physics circle on a frictionless tabletop.

enum Team { PLAYER, ENEMY }

# Collision layers (named in Project Settings > Layer Names > 2D Physics).
const LAYER_ON_DECK := 1 << 0  # layer 1: player figures waiting on deck
const LAYER_FLICKED := 1 << 1  # layer 2: player figures out on the board
const LAYER_ENEMY := 1 << 2  # layer 3: enemy figures
const GREYED_OUT := Color(0.5, 0.5, 0.5)

# Set by main.gd before the figure is added to the scene.
var team := Team.PLAYER
var radius := 60.0
var color := Color.WHITE
var bounciness := 0.7
var stop_speed := 15.0  # below this speed (px/s) the figure snaps to a stop
var deck_position := Vector2.ZERO  # where a player figure goes when reloaded

# Player figures: true while waiting on deck (can be flicked), false once flicked (greyed out).
var on_deck := false:
	set(value):
		on_deck = value
		if is_node_ready():
			_update_collision()
			queue_redraw()
var knocked_off := false


func _ready() -> void:
	# A tabletop: no gravity, no spinning, slowing down only through linear_damp.
	gravity_scale = 0.0
	lock_rotation = true
	can_sleep = false
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY

	var material := PhysicsMaterial.new()
	material.bounce = bounciness
	material.friction = 0.0
	physics_material_override = material

	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	collision.shape = circle
	add_child(collision)

	_update_collision()


## Who collides with whom:
## - Player flicks ignore the player's on-deck figures but hit each other and enemies.
## - Enemies hit everything, including on-deck figures.
## - On-deck figures never collide with each other.
func _update_collision() -> void:
	if team == Team.ENEMY:
		collision_layer = LAYER_ENEMY
		collision_mask = LAYER_ENEMY | LAYER_FLICKED | LAYER_ON_DECK
	elif on_deck:
		collision_layer = LAYER_ON_DECK
		collision_mask = LAYER_ENEMY
	else:
		collision_layer = LAYER_FLICKED
		collision_mask = LAYER_FLICKED | LAYER_ENEMY


func _draw() -> void:
	var greyed := team == Team.PLAYER and not on_deck
	var fill := color.lerp(GREYED_OUT, 0.85) if greyed else color
	draw_circle(Vector2.ZERO, radius, fill)
	draw_arc(Vector2.ZERO, radius - 3.0, 0.0, TAU, 48, fill.darkened(0.4), 6.0, true)
	draw_circle(Vector2(-radius, -radius) * 0.3, radius * 0.22, fill.lightened(0.4))


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Damping alone never quite reaches zero, so stop crawling figures.
	if state.linear_velocity.length() < stop_speed:
		state.linear_velocity = Vector2.ZERO


func is_resting() -> bool:
	return linear_velocity.length() < stop_speed


func launch(impulse: Vector2) -> void:
	on_deck = false
	apply_central_impulse(impulse)


func return_to_deck() -> void:
	linear_velocity = Vector2.ZERO
	global_position = deck_position
	on_deck = true


func knock_off(fade_time: float) -> void:
	knocked_off = true
	collision_layer = 0
	collision_mask = 0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	tween.tween_callback(queue_free)
