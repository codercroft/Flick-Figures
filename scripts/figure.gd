class_name Figure
extends RigidBody2D
## One toy figure: a physics circle that sits on deck until it is flicked.

# Collision layers (named in Project Settings > Layer Names > 2D Physics).
const LAYER_ON_DECK := 1 << 0  # layer 1
const LAYER_FLICKED := 1 << 1  # layer 2
const GREYED_OUT := Color(0.5, 0.5, 0.5)

# Set by main.gd before the figure is added to the scene.
var radius := 60.0
var color := Color.WHITE
var bounciness := 0.7
var stop_speed := 15.0  # below this speed (px/s) the figure snaps to a stop

var on_deck := true  # still sitting in the deck, never flicked this round
var can_flick := true  # false (greyed out) after being flicked
var entered_board := false  # has been inside the board at least once
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

	# On deck: held in place, and nothing a flick does can touch it.
	freeze = true
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	collision_layer = LAYER_ON_DECK
	collision_mask = 0


func _draw() -> void:
	var fill := color if can_flick else color.lerp(GREYED_OUT, 0.85)
	draw_circle(Vector2.ZERO, radius, fill)
	draw_arc(Vector2.ZERO, radius - 3.0, 0.0, TAU, 48, fill.darkened(0.4), 6.0, true)
	draw_circle(Vector2(-radius, -radius) * 0.3, radius * 0.22, fill.lightened(0.4))


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Damping alone never quite reaches zero, so stop crawling figures.
	if state.linear_velocity.length() < stop_speed:
		state.linear_velocity = Vector2.ZERO


func set_can_flick(value: bool) -> void:
	can_flick = value
	queue_redraw()


func is_resting() -> bool:
	return linear_velocity.length() < stop_speed


func launch(impulse: Vector2) -> void:
	on_deck = false
	set_can_flick(false)
	# Flicked figures collide with other flicked figures, and ignore the deck.
	collision_layer = LAYER_FLICKED
	collision_mask = LAYER_FLICKED
	freeze = false
	apply_central_impulse(impulse)


func knock_off(fade_time: float) -> void:
	knocked_off = true
	collision_layer = 0
	collision_mask = 0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	tween.tween_callback(queue_free)
