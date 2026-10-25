class_name Figure
extends RigidBody2D
## One toy figure (player or enemy): a physics circle on a frictionless tabletop.
## What makes it special comes from its FigureData (stats) and ability (events).

signal flicked(figure: Figure, impulse: Vector2)
## Two figures collided. Only one of the two figures emits this per collision.
signal impacted(figure: Figure, other: Figure, speed: float, point: Vector2)
signal fell_off(figure: Figure)
## A figure wants to be replaced by new figures (Slime splitting). `pieces` is an array of
## {data, position, velocity} dictionaries; main.gd spawns them and removes `parent`.
signal split_requested(parent: Figure, pieces: Array, grants_flicks: bool)

enum Team { PLAYER, ENEMY }

# Collision layers (named in Project Settings > Layer Names > 2D Physics).
const LAYER_ON_DECK := 1 << 0  # layer 1: player figures waiting on deck
const LAYER_FLICKED := 1 << 1  # layer 2: player figures out on the board
const LAYER_ENEMY := 1 << 2  # layer 3: enemy figures
const LAYER_ARENA := 1 << 3  # layer 4: arena walls and pins
const GREYED_OUT := Color(0.5, 0.5, 0.5)
const PLAYER_RING := Color(1.0, 1.0, 1.0, 0.9)
const ENEMY_RING := Color(0.95, 0.15, 0.15)
## Velocity changes smaller than this (px/s) are just damping, not a hit.
const KNOCKBACK_MIN_CHANGE := 60.0
const BLAST_RING_TIME := 0.35
## Ability numbers that the Glow-in-the-dark finish makes stronger (radius, pull, bounce).
const STRENGTH_PROPERTIES := ["explosion_radius", "pull_radius", "pull_acceleration", "bounce_boost", "bump_ratio", "nudge_speed"]

var team := Team.PLAYER
var data: FigureData  # may be a modified copy of base_data (upgrades and finishes change stats)
var base_data: FigureData  # the original, untouched figure data (what to respawn from)
var ability: FigureAbility
## The toy finish (one general upgrade) and the figure-specific upgrade on this figure, or null.
var finish: FinishData
var upgrade: UpgradeData
var _fx_time := 0.0
## The equipment item attached to this figure (player figures only), or null.
var equipment: EquipmentData
var radius := 60.0
var stop_speed := 15.0  # below this speed (px/s) the figure counts as slow
var settle_frames := 5  # ...and after this many slow frames in a row it stops dead
var deck_position := Vector2.ZERO  # where a player figure goes when reloaded

# Player figures: true while waiting on deck (can be flicked), false once flicked (greyed out).
var on_deck := false:
	set(value):
		on_deck = value
		if is_node_ready():
			_update_collision()
			queue_redraw()
# Player figures: true while this figure may be flicked this round; false once it has been
# flicked (greyed out) until the whole squad has gone. Separate from on_deck, which is about
# WHERE the figure is (and so who it collides with).
var flickable := true:
	set(value):
		flickable = value
		queue_redraw()
var knocked_off := false
## Flicks this figure has taken this turn (main.gd resets it each turn; Speedo can take 2).
var turn_flicks := 0
## True once this figure has touched anything (a figure or a wall) since it was last flicked.
var touched_since_flick := false
## Glue Guy: the joints holding this figure to others (stale ones may linger; check validity).
var glue_joints: Array[PinJoint2D] = []
## Powers: rounds left of Freeze Ray / Bubble Shield (0 = not active), and Shrink Ray.
var frozen_rounds := 0
var bubble_rounds := 0
var shrunk := false

# Player figures: highlighted ring while chosen for aiming.
var selected := false:
	set(value):
		selected = value
		queue_redraw()

var _circle: CircleShape2D

var _last_velocity := Vector2.ZERO
var _prev_velocity := Vector2.ZERO  # the step before _last_velocity (to see speed before an impact)
var _skip_knockback_frames := 0  # ignore our own flicks/blasts when measuring hits
var _was_moving := false
var _slow_frames := 0  # consecutive physics frames spent below stop_speed
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
func setup(figure_data: FigureData, figure_team: Team, base_damping: float, speed_to_stop: float,
		frames_to_settle := 5, item: EquipmentData = null, toy_finish: FinishData = null,
		figure_upgrade: UpgradeData = null) -> void:
	base_data = figure_data
	data = figure_data
	team = figure_team
	equipment = item
	finish = toy_finish
	upgrade = figure_upgrade
	# Stat changes go on a private copy so the shared FigureData resource is never touched.
	if upgrade != null and not upgrade.data_overrides.is_empty() \
			or finish != null and finish.knockback_taken_multiplier != 1.0:
		data = figure_data.duplicate() as FigureData
		if upgrade != null:
			for key in upgrade.data_overrides:
				data.set(key, upgrade.data_overrides[key])
		if finish != null:
			data.knockback_taken_multiplier *= finish.knockback_taken_multiplier
	radius = data.radius
	mass = data.mass
	linear_damp = base_damping * data.damping_multiplier
	if equipment != null:
		mass *= equipment.mass_multiplier
		linear_damp *= equipment.damping_multiplier
	if finish != null:
		mass *= finish.mass_multiplier
	stop_speed = speed_to_stop
	settle_frames = frames_to_settle
	# Each figure gets its own copy so abilities can keep per-figure state.
	ability = data.ability.duplicate() as FigureAbility if data.ability else FigureAbility.new()
	if upgrade != null:
		for key in upgrade.ability_overrides:
			if key in ability:
				ability.set(key, upgrade.ability_overrides[key])
	if finish != null and finish.ability_strength != 1.0:
		for key in STRENGTH_PROPERTIES:
			if key in ability:
				ability.set(key, ability.get(key) * finish.ability_strength)
	# Equipment, upgrades and finishes with an effect run next to the figure's own ability.
	for extra in [equipment.effect if equipment != null else null,
			upgrade.extra_effect if upgrade != null else null, finish.effect if finish != null else null]:
		if extra != null:
			ability = CombinedAbility.new(ability, extra.duplicate() as FigureAbility)


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
	if finish != null:
		if finish.look == FinishData.Look.TRANSLUCENT:
			self_modulate.a = 0.55
		set_process(finish.look in [FinishData.Look.SPARKLE, FinishData.Look.SHEEN, FinishData.Look.GLOW])
	else:
		set_process(false)

	var material := PhysicsMaterial.new()
	material.bounce = clampf(data.bounce + (equipment.bounce_bonus if equipment != null else 0.0), 0.0, 1.0)
	material.friction = 0.0
	physics_material_override = material

	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	_circle = circle
	collision.shape = circle
	add_child(collision)

	_update_collision()


## The toy finish drawn on top of the body: sparkle, sheen, glow or rubber (translucent is
## just the figure's alpha).
func _draw_finish() -> void:
	if finish == null:
		return
	match finish.look:
		FinishData.Look.SPARKLE:
			for i in 7:
				var spot := Vector2.from_angle(i * 1.9 + 0.7) * radius * (0.25 + 0.5 * fmod(i * 0.37, 1.0))
				var twinkle := 0.5 + 0.5 * sin(_fx_time * 5.0 + i * 1.7)
				var arm := radius * 0.16 * twinkle
				var color := Color(finish.color, twinkle)
				draw_line(spot + Vector2(-arm, 0.0), spot + Vector2(arm, 0.0), color, 3.0)
				draw_line(spot + Vector2(0.0, -arm), spot + Vector2(0.0, arm), color, 3.0)
				draw_line(spot + Vector2(-arm, -arm) * 0.6, spot + Vector2(arm, arm) * 0.6, color, 2.0)
				draw_line(spot + Vector2(-arm, arm) * 0.6, spot + Vector2(arm, -arm) * 0.6, color, 2.0)
		FinishData.Look.SHEEN:
			draw_circle(Vector2.ZERO, radius - 4.0, Color(0.85, 0.88, 0.95, 0.35))
			var sweep := _fx_time * 1.3
			draw_arc(Vector2.ZERO, radius * 0.7, sweep, sweep + 0.9, 12, Color(1.0, 1.0, 1.0, 0.7), radius * 0.2, true)
			draw_arc(Vector2.ZERO, radius * 0.7, sweep + PI, sweep + PI + 0.5, 8, Color(1.0, 1.0, 1.0, 0.4), radius * 0.12, true)
		FinishData.Look.GLOW:
			var pulse := 0.75 + 0.25 * sin(_fx_time * 3.0)
			for i in 3:
				draw_arc(Vector2.ZERO, radius + 6.0 + i * 9.0, 0.0, TAU, 40, Color(finish.color, (0.55 - 0.15 * i) * pulse), 8.0, true)
		FinishData.Look.RUBBER:
			draw_arc(Vector2.ZERO, radius - 2.0, 0.0, TAU, 40, Color(0.12, 0.12, 0.14, 0.9), 10.0, true)
			for i in 10:
				var direction := Vector2.from_angle(TAU * i / 10.0)
				draw_line(direction * (radius - 12.0), direction * (radius + 1.0), Color(0.3, 0.3, 0.34), 3.0)


## Who collides with whom:
## - Player flicks ignore the player's on-deck figures but hit each other and enemies.
## - Enemies hit everything, including on-deck figures.
## - On-deck figures never collide with each other.
func _update_collision() -> void:
	if team == Team.ENEMY:
		collision_layer = LAYER_ENEMY
		collision_mask = LAYER_ENEMY | LAYER_FLICKED | LAYER_ON_DECK | LAYER_ARENA
	elif on_deck:
		collision_layer = LAYER_ON_DECK
		collision_mask = LAYER_ENEMY | LAYER_ARENA
	else:
		collision_layer = LAYER_FLICKED
		collision_mask = LAYER_FLICKED | LAYER_ENEMY | LAYER_ARENA


func _draw() -> void:
	var greyed := team == Team.PLAYER and not flickable
	var fill := data.color.lerp(GREYED_OUT, 0.85) if greyed else data.color
	# The body squashes/stretches along _squash_angle; the details on top only grow.
	var stretch := maxf(1.0 + _squash_amount, 0.2)
	draw_set_transform(Vector2.ZERO, _squash_angle, Vector2(stretch, 1.0 / stretch) * (1.0 + _pop))
	draw_circle(Vector2.ZERO, radius, fill)
	# The ring shows which side the figure is on (any figure can be on either side).
	draw_arc(Vector2.ZERO, radius - 4.0, 0.0, TAU, 48, ENEMY_RING if team == Team.ENEMY else PLAYER_RING, 8.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * (1.0 + _pop))
	if selected:
		draw_arc(Vector2.ZERO, radius + 10.0, 0.0, TAU, 48, Color(1.0, 0.9, 0.3), 8.0, true)
	draw_circle(Vector2(-radius, -radius) * 0.3, radius * 0.22, fill.lightened(0.4))
	_draw_finish()
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
	if upgrade != null:
		# A little gold pip in the upper right marks a figure-specific upgrade.
		var pip := Vector2(radius, -radius) * 0.66
		draw_circle(pip, radius * 0.17, Color(1.0, 0.85, 0.2))
		draw_arc(pip, radius * 0.17, 0.0, TAU, 14, Color(0.2, 0.15, 0.05), 3.0, true)
	if equipment != null:
		# A small badge in the lower right shows that this figure carries equipment.
		var badge_center := Vector2(radius, radius) * 0.62
		var badge_radius := radius * 0.34
		draw_circle(badge_center, badge_radius, equipment.color)
		draw_arc(badge_center, badge_radius, 0.0, TAU, 20, Color(0.1, 0.1, 0.12), 4.0, true)
		var badge_size := int(badge_radius * (1.05 if equipment.label.length() <= 1 else 0.85))
		draw_string(ThemeDB.fallback_font, badge_center + Vector2(-badge_radius, badge_size * 0.33), equipment.label,
				HORIZONTAL_ALIGNMENT_CENTER, badge_radius * 2.0, badge_size, Color(0.1, 0.1, 0.12))
	if frozen_rounds > 0:
		draw_circle(Vector2.ZERO, radius, Color(0.6, 0.9, 1.0, 0.55))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.85, 1.0, 1.0), 6.0, true)
	if bubble_rounds > 0:
		draw_arc(Vector2.ZERO, radius + 16.0, 0.0, TAU, 48, Color(0.5, 0.85, 1.0, 0.9), 8.0, true)
		draw_arc(Vector2.ZERO, radius + 16.0, 0.0, TAU, 48, Color(0.5, 0.85, 1.0, 0.25), 18.0, true)
	if _blast_progress < 1.0:
		var ring_radius := lerpf(radius, _blast_radius, _blast_progress)
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64, Color(1, 0.8, 0.3, 1.0 - _blast_progress), 10.0, true)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var velocity := state.linear_velocity

	# Knockback multiplier: scale how much a collision changed our velocity.
	if _skip_knockback_frames > 0:
		_skip_knockback_frames -= 1
	elif state.get_contact_count() > 0:
		var hitter := _hardest_hitter(state)
		var multiplier := data.knockback_taken_multiplier * ability.get_knockback_multiplier(self, hitter)
		if hitter != null:
			var impact := maxf((_last_velocity - hitter._last_velocity).length(),
					(_prev_velocity - hitter._prev_velocity).length())
			multiplier *= ability.get_hit_multiplier(self, hitter, impact)
		var change := velocity - _last_velocity
		if not is_equal_approx(multiplier, 1.0) and change.length() > KNOCKBACK_MIN_CHANGE:
			velocity = _last_velocity + change * multiplier

	# Damping alone never quite reaches zero. Once a figure has stayed below stop_speed for
	# settle_frames frames in a row, it stops dead.
	if velocity.length() < stop_speed:
		_slow_frames = mini(_slow_frames + 1, settle_frames)
		if _slow_frames >= settle_frames:
			velocity = Vector2.ZERO
			if _was_moving:
				_was_moving = false
				ability.on_stopped.call_deferred(self)
	else:
		_slow_frames = 0
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


func _process(delta: float) -> void:
	_fx_time += delta  # animates sparkle, sheen and glow
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not knocked_off:
		ability.on_physics_process(self, delta)


func _on_body_entered(body: Node) -> void:
	touched_since_flick = true
	if body is Figure:
		# Deferred: physics callbacks can't change physics state directly.
		ability.on_hit.call_deferred(self, body)
		var other: Figure = body
		# Velocities change in the same step as the collision, so look at the step before too.
		var speed := maxf((_last_velocity - other._last_velocity).length(),
				(_prev_velocity - other._prev_velocity).length())
		var point := global_position + (other.global_position - global_position).normalized() * radius
		ability.on_impact.call_deferred(self, other, speed, point)
		# Both figures get this signal; only the one with the lower id reports the impact.
		if get_instance_id() < other.get_instance_id():
			emit_signal.call_deferred(&"impacted", self, other, speed, point)
	else:
		ability.on_hit_wall.call_deferred(self, body)


## Below the settle speed right now (not necessarily stopped for good yet).
func is_slow() -> bool:
	return linear_velocity.length() < stop_speed


## Settled: has been slow for several frames in a row (and is still slow).
func is_resting() -> bool:
	return _slow_frames >= settle_frames and is_slow()


## Safety net: stop right now.
func force_settle() -> void:
	linear_velocity = Vector2.ZERO
	_slow_frames = settle_frames
	_was_moving = false


## For the "still moving" debug readout.
func describe_motion() -> String:
	return "%s %.0fpx/s" % [data.display_name, linear_velocity.length()]


func launch(impulse: Vector2) -> void:
	on_deck = false
	flickable = false
	turn_flicks += 1
	touched_since_flick = false
	_skip_knockback_frames = 2
	_slow_frames = 0
	apply_central_impulse(impulse)
	ability.on_flicked(self, impulse)
	flicked.emit(self, impulse)


## Pushed by a hit-like effect (an explosion or bump). `source` is the figure that caused it.
## Respects knockback_taken_multiplier and the ability's get_knockback_multiplier.
func take_knockback(impulse: Vector2, source: Figure = null) -> void:
	if is_frozen():
		return
	_skip_knockback_frames = 2
	apply_central_impulse(impulse * data.knockback_taken_multiplier * ability.get_knockback_multiplier(self, source))


## Pushed by an explosion: breaks any glue, then the push is scaled by the ability's
## get_explosion_multiplier (0 = immune).
func take_explosion(impulse: Vector2, source: Figure) -> void:
	unglue()
	var multiplier := ability.get_explosion_multiplier(self, source)
	if multiplier > 0.0:
		take_knockback(impulse * multiplier, source)


## Changes velocity by `velocity_change` px/s directly (ignores knockback multipliers).
func nudge(velocity_change: Vector2) -> void:
	if is_frozen():
		return
	_skip_knockback_frames = 2
	_slow_frames = 0
	apply_central_impulse(velocity_change * mass)


## Glues this figure to `other`: they move as one heavier body until an explosion hits either.
func glue_to(other: Figure) -> void:
	if knocked_off or other.knocked_off or get_parent() == null:
		return
	var joint := PinJoint2D.new()
	get_parent().add_child(joint)
	joint.global_position = (global_position + other.global_position) / 2.0
	joint.node_a = joint.get_path_to(self)
	joint.node_b = joint.get_path_to(other)
	joint.softness = 0.0
	glue_joints.append(joint)
	other.glue_joints.append(joint)


func is_glued() -> bool:
	for joint in glue_joints:
		if is_instance_valid(joint) and not joint.is_queued_for_deletion():
			return true
	return false


## Breaks every glue joint on this figure.
func unglue() -> void:
	for joint in glue_joints:
		if is_instance_valid(joint):
			joint.queue_free()
	glue_joints.clear()


## A short floating text above the figure (e.g. "+$2").
func show_popup(text: String, color := Color(1.0, 0.85, 0.2)) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(-80.0, -radius - 70.0)
	label.size = Vector2(160.0, 50.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	label.z_index = 10
	add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 90.0, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tween.chain().tween_callback(label.queue_free)


## Pushes every other figure within blast_radius away (except `spared`, if given). The push is
## `force` at the center and fades to zero at the edge.
func explode(blast_radius: float, force: float, spared: Figure = null) -> void:
	_blast_radius = blast_radius
	create_tween().tween_property(self, "_blast_progress", 1.0, BLAST_RING_TIME).from(0.0)
	Figure.blast(get_tree(), global_position, blast_radius, force, self, spared)


## An explosion at `center` (set off by `source`, which may be null for a power) that pushes every
## figure within blast_radius away, except `source` and `spared`.
static func blast(tree: SceneTree, center: Vector2, blast_radius: float, force: float,
		source: Figure = null, spared: Figure = null) -> void:
	for node in tree.get_nodes_in_group("figures"):
		var other := node as Figure
		if other == source or other == spared or other.knocked_off:
			continue
		var offset := other.global_position - center
		var distance := offset.length()
		if distance >= blast_radius:
			continue
		var direction := offset.normalized() if distance > 0.01 else Vector2.UP
		other.take_explosion(direction * force * (1.0 - distance / blast_radius), source)
		other.ability.on_exploded.call_deferred(other, source)


## Asks main.gd to replace this figure with `pieces` ({data, position, velocity} dictionaries).
## `grants_flicks` = the enemy side gets an extra flick per turn for it (Slime does, Splitter doesn't).
func split_into(pieces: Array, grants_flicks := false) -> void:
	split_requested.emit(self, pieces, grants_flicks)


## Power: can't flick and can't be moved (a static body) for `rounds` rounds.
func freeze_for(rounds: int) -> void:
	frozen_rounds = rounds
	linear_velocity = Vector2.ZERO
	force_settle()
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	freeze = true
	queue_redraw()


func thaw() -> void:
	frozen_rounds = 0
	freeze = false
	queue_redraw()


func is_frozen() -> bool:
	return frozen_rounds > 0


## Power: for `rounds` rounds it stops at the table edge instead of falling off.
func set_bubble(rounds: int) -> void:
	bubble_rounds = rounds
	queue_redraw()


## Power: smaller and lighter for the rest of the combat.
func shrink(size_factor: float, mass_factor: float) -> void:
	shrunk = true
	set_size(radius * size_factor, mass * mass_factor)


## Changes the figure's radius and mass (the collision shape and the picture follow).
func set_size(new_radius: float, new_mass: float) -> void:
	radius = new_radius
	mass = new_mass
	if _circle != null:
		_circle.radius = new_radius
	queue_redraw()


## Called by main.gd at the start of each round: powers that last "a round" count down here.
func tick_round() -> void:
	if frozen_rounds > 0:
		frozen_rounds -= 1
		if frozen_rounds == 0:
			thaw()
	if bubble_rounds > 0:
		bubble_rounds -= 1
		queue_redraw()


func return_to_deck() -> void:
	linear_velocity = Vector2.ZERO
	global_position = deck_position
	on_deck = true
	flickable = true


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


## `retired` = removed for another reason than falling off (a Splitter splitting): no on_knocked_off.
func knock_off(fade_time: float, retired := false) -> void:
	unglue()
	knocked_off = true
	fell_off.emit(self)
	collision_layer = 0
	collision_mask = 0
	if not retired:
		ability.on_knocked_off(self)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	tween.tween_callback(queue_free)
