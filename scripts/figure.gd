class_name Figure
extends RigidBody2D
## One toy figure (player or enemy): a physics circle on a frictionless tabletop.
## What makes it special comes from its FigureData (stats) and ability (events).

signal flicked(figure: Figure, impulse: Vector2)
## Two figures collided. Only one of the two figures emits this per collision.
signal impacted(figure: Figure, other: Figure, speed: float, point: Vector2)
signal fell_off(figure: Figure)

enum Team { PLAYER, ENEMY }

# Collision layers (named in Project Settings > Layer Names > 2D Physics).
const LAYER_ON_DECK := 1 << 0  # layer 1: player figures waiting on deck
const LAYER_FLICKED := 1 << 1  # layer 2: player figures out on the board
const LAYER_ENEMY := 1 << 2  # layer 3: enemy figures
const GREYED_OUT := Color(0.5, 0.5, 0.5)
const PLAYER_RING := Color(1.0, 1.0, 1.0, 0.9)
const ENEMY_RING := Color(0.95, 0.15, 0.15)
## Velocity changes smaller than this (px/s) are just damping, not a hit.
const KNOCKBACK_MIN_CHANGE := 60.0
const BLAST_RING_TIME := 0.35

var team := Team.PLAYER
var data: FigureData
var ability: FigureAbility
var radius := 60.0
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

var _last_velocity := Vector2.ZERO
var _prev_velocity := Vector2.ZERO  # the step before _last_velocity (to see speed before an impact)
var _skip_knockback_frames := 0  # ignore our own flicks/blasts when measuring hits
var _was_moving := false
var _squash_amount := 0.0:  # + stretches along _squash_angle, - squashes
	set(value):
		_squash_amount = value
		queue_redraw()
var _squash_angle := 0.0
var _squash_tween: Tween
var _pop := 0.0:  # extra size while popping off the table
	set(value):
		_pop = value
		queue_redraw()
var _blast_radius := 0.0
var _blast_progress := 1.0:  # 0 = blast just went off, 1 = ring finished
	set(value):
		_blast_progress = value
		queue_redraw()


## Call before adding the figure to the scene.
func setup(figure_data: FigureData, figure_team: Team, base_damping: float, speed_to_stop: float) -> void:
	data = figure_data
	team = figure_team
	radius = data.radius
	mass = data.mass
	linear_damp = base_damping * data.damping_multiplier
	stop_speed = speed_to_stop
	# Each figure gets its own copy so abilities can keep per-figure state.
	ability = data.ability.duplicate() as FigureAbility if data.ability else FigureAbility.new()


func _ready() -> void:
	# A tabletop: no gravity, no spinning, slowing down only through linear_damp.
	gravity_scale = 0.0
	lock_rotation = true
	can_sleep = false
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_body_entered)
	add_to_group("figures")

	var material := PhysicsMaterial.new()
	material.bounce = data.bounce
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
	var fill := data.color.lerp(GREYED_OUT, 0.85) if greyed else data.color
	# The body squashes/stretches along _squash_angle; the details on top only grow.
	var stretch := maxf(1.0 + _squash_amount, 0.2)
	draw_set_transform(Vector2.ZERO, _squash_angle, Vector2(stretch, 1.0 / stretch) * (1.0 + _pop))
	draw_circle(Vector2.ZERO, radius, fill)
	# The ring shows which side the figure is on (any figure can be on either side).
	draw_arc(Vector2.ZERO, radius - 4.0, 0.0, TAU, 48, ENEMY_RING if team == Team.ENEMY else PLAYER_RING, 8.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * (1.0 + _pop))
	draw_circle(Vector2(-radius, -radius) * 0.3, radius * 0.22, fill.lightened(0.4))
	# A short label so you can tell figures apart (the first letter of the name by default).
	var label := data.label if data.label != "" else data.display_name.left(1)
	var font_size := int(radius * (1.0 if label.length() <= 1 else 0.75))
	var ink := fill.darkened(0.5)
	if data.icon == FigureIcons.Icon.NONE:
		draw_string(ThemeDB.fallback_font, Vector2(-radius, font_size * 0.35), label,
				HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, ink)
	else:
		# Label above, little icon below.
		font_size = int(font_size * 0.8)
		draw_string(ThemeDB.fallback_font, Vector2(-radius, -radius * 0.08), label,
				HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, ink)
		FigureIcons.draw(self, data.icon, Vector2(0.0, radius * 0.46), radius * 0.3, ink)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _blast_progress < 1.0:
		var ring_radius := lerpf(radius, _blast_radius, _blast_progress)
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64, Color(1, 0.8, 0.3, 1.0 - _blast_progress), 10.0, true)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var velocity := state.linear_velocity

	# Knockback multiplier: scale how much a collision changed our velocity.
	if _skip_knockback_frames > 0:
		_skip_knockback_frames -= 1
	elif state.get_contact_count() > 0:
		var multiplier := data.knockback_taken_multiplier \
				* ability.get_knockback_multiplier(self, _hardest_hitter(state))
		var change := velocity - _last_velocity
		if not is_equal_approx(multiplier, 1.0) and change.length() > KNOCKBACK_MIN_CHANGE:
			velocity = _last_velocity + change * multiplier

	# Damping alone never quite reaches zero, so stop crawling figures.
	if velocity.length() < stop_speed:
		velocity = Vector2.ZERO
		if _was_moving:
			_was_moving = false
			ability.on_stopped.call_deferred(self)
	else:
		_was_moving = true

	state.linear_velocity = velocity
	_prev_velocity = _last_velocity
	_last_velocity = velocity


## The touching figure we are moving fastest relative to: the one that hit us.
func _hardest_hitter(state: PhysicsDirectBodyState2D) -> Figure:
	var best: Figure = null
	var best_speed := -1.0
	for i in state.get_contact_count():
		var other := state.get_contact_collider_object(i) as Figure
		if other == null:
			continue
		var speed := (other.linear_velocity - state.linear_velocity).length()
		if speed > best_speed:
			best = other
			best_speed = speed
	return best


func _physics_process(delta: float) -> void:
	if not knocked_off:
		ability.on_physics_process(self, delta)


func _on_body_entered(body: Node) -> void:
	if body is Figure:
		# Deferred: physics callbacks can't change physics state directly.
		ability.on_hit.call_deferred(self, body)
		# Both figures get this signal; only the one with the lower id reports the impact.
		var other: Figure = body
		if get_instance_id() < other.get_instance_id():
			# Velocities change in the same step as the collision, so look at the step before too.
			var speed := maxf((_last_velocity - other._last_velocity).length(),
					(_prev_velocity - other._prev_velocity).length())
			var point := global_position + (other.global_position - global_position).normalized() * radius
			emit_signal.call_deferred(&"impacted", self, other, speed, point)


func is_resting() -> bool:
	return linear_velocity.length() < stop_speed


func launch(impulse: Vector2) -> void:
	on_deck = false
	_skip_knockback_frames = 2
	apply_central_impulse(impulse)
	ability.on_flicked(self, impulse)
	flicked.emit(self, impulse)


## Pushed by a hit-like effect (an explosion or bump). `source` is the figure that caused it.
## Respects knockback_taken_multiplier and the ability's get_knockback_multiplier.
func take_knockback(impulse: Vector2, source: Figure = null) -> void:
	_skip_knockback_frames = 2
	apply_central_impulse(impulse * data.knockback_taken_multiplier * ability.get_knockback_multiplier(self, source))


## Pushes every other figure within blast_radius away. The push is `force` at the
## center and fades to zero at the edge.
func explode(blast_radius: float, force: float) -> void:
	_blast_radius = blast_radius
	create_tween().tween_property(self, "_blast_progress", 1.0, BLAST_RING_TIME).from(0.0)
	for node in get_tree().get_nodes_in_group("figures"):
		var other := node as Figure
		if other == self or other.knocked_off:
			continue
		var offset := other.global_position - global_position
		var distance := offset.length()
		if distance >= blast_radius:
			continue
		other.take_knockback(offset.normalized() * force * (1.0 - distance / blast_radius), self)
		other.ability.on_exploded.call_deferred(other, self)


func return_to_deck() -> void:
	linear_velocity = Vector2.ZERO
	global_position = deck_position
	on_deck = true


## Stretches (amount > 0) or squashes (amount < 0) the body along `direction`, then wobbles back.
func play_squash(direction: Vector2, amount: float, duration: float) -> void:
	_squash_angle = direction.angle()
	if _squash_tween:
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_property(self, "_squash_amount", 0.0, duration).from(amount) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Swells the figure by `swell` (0.5 = 50% bigger). Used as it gets knocked off.
func play_pop(swell: float, duration: float) -> void:
	create_tween().tween_property(self, "_pop", swell, duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func knock_off(fade_time: float) -> void:
	knocked_off = true
	fell_off.emit(self)
	collision_layer = 0
	collision_mask = 0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	tween.tween_callback(queue_free)
