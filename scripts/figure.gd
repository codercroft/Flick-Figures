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
## A figure sheds pieces but stays itself (Skull-o-tron's arms): main.gd spawns them.
signal shed_requested(parent: Figure, pieces: Array, grants_flicks: bool)

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
const STRENGTH_PROPERTIES := ["explosion_radius", "blast_radius", "pull_radius", "pull_acceleration", "bounce_boost", "bump_ratio", "nudge_speed", "aura_radius"]

var team := Team.PLAYER
var data: FigureData  # may be a modified copy of base_data (upgrades and finishes change stats)
var base_data: FigureData  # the original, untouched figure data (what to respawn from)
var ability: FigureAbility
var blast_shield := false:  # set by main while the team has a Firecracker (draws the faint ring)
	set(value):
		if value != blast_shield:
			blast_shield = value
			queue_redraw()
## The toy finish (one general upgrade) and the figure-specific upgrade on this figure, or null.
var finish: FinishData
var upgrades: Array[UpgradeData] = []  # the tiers this figure owns (RunManager.owned_upgrades), in order
var upgrade_state := Vector2i(-1, 0)  # (path, tier), kept for Rewind
## Enemies: the act's stat multipliers it was built with ({accuracy, power, mass}) and whether it
## is an elite (drawn with a gold ring). Kept so Slime pieces and Rewind can rebuild it.
var scale_factors := {}
var elite := false
var _fx_time := 0.0
## The equipment item attached to this figure (player figures only), or null.
var equipment: EquipmentData
var deck_slot := -1  # the index in RunManager.deck for the player's starting figures (-1 for anything else)
var _core_ability: FigureAbility  # the figure's own ability, without equipment / upgrade / finish effects
var _equipment_effect: FigureAbility
var _upgrade_effects: Array[FigureAbility] = []
var _finish_effect: FigureAbility
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
## Duwall: true once its shell has burst and it has become a Grunt.
var shell_broken := false
## Bloodluster: bonus flicks taken this turn (main.gd resets it with turn_flicks).
var bonus_flicks_used := 0
var _base_damping := 1.5  # the Main node's damping before this figure's own multipliers

# Player figures: highlighted ring while chosen for aiming.
var selected := false:
	set(value):
		selected = value
		queue_redraw()

## Set when a turret's pellet hits this figure while it rests: the nudge alone does not count as "movement in
## progress" (turrets stop firing once only pellet-driven figures are moving).
var last_pellet_ms := -100000
## Pinhead / Alchemist / Engineer: this figure already placed its pin, zone or turret this turn (reset when a turn ends).
var placed_this_turn := false
## Doused by an Alchemist's zone: rounds left, the rounds it started with (for the fade) and the knockback multiplier.
var doused_rounds := 0
var doused_full := 1
var doused_multiplier := 1.0
var placed_count := 0  # placements made this turn (Pinhead and Engineer can place more than one)
var temp_dealt := 0.0  # extra knockback dealt until the end of the next turn (Rally's Hard Hitters)
var temp_taken := 1.0  # knockback taken multiplier until the end of the next turn (Rally's Padded Ranks)
var temp_taken_team := -1  # whose turn start clears the two above (-1 = none)
var charge_power := 1.0  # x flick power on the next flick (Energizer's Overcharge)
var shock_flick := 1.0  # x flick power until this figure's next flick (Energizer's Shock)
var doused_flick := 1.0  # x flick power while Doused by a weakening zone (Alchemist's Weakening Brew)
var stunned_rounds := 0  # can't flick for this many rounds (Energizer's Stun)
var bummed_stats := {}
var bummed_extra := 0  # takeovers left after leaving a Bummer's aura (Gloom tier 3)
var doused_juice := false  # the weaker Juicer version (lighter tint); an Alchemist zone replaces it
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
		figure_upgrades: Array = [], stat_scale := {}, is_elite := false) -> void:
	base_data = figure_data
	data = figure_data
	team = figure_team
	equipment = item
	finish = toy_finish
	upgrades.clear()
	for u in figure_upgrades:
		upgrades.append(u)
	elite = is_elite
	scale_factors = stat_scale
	# Stat changes go on a private copy so the shared FigureData resource is never touched.
	var changes_data := false
	for u in upgrades:
		if not u.data_overrides.is_empty() or not u.data_multipliers.is_empty():
			changes_data = true
	if changes_data or finish != null and finish.knockback_taken_multiplier != 1.0 or not stat_scale.is_empty():
		data = figure_data.duplicate() as FigureData
		for u in upgrades:  # tier 1 first: overrides, then multipliers
			for key in u.data_overrides:
				data.set(key, u.data_overrides[key])
			for key in u.data_multipliers:
				data.set(key, data.get(key) * u.data_multipliers[key])
		if finish != null:
			data.knockback_taken_multiplier *= finish.knockback_taken_multiplier
		# Act difficulty (and elite strength) for enemies: accuracy, flick power and mass.
		if not stat_scale.is_empty():
			data.accuracy = minf(data.accuracy * stat_scale.get("accuracy", 1.0), 1.0)
			data.flick_power_multiplier *= stat_scale.get("power", 1.0)
			data.mass *= stat_scale.get("mass", 1.0)
			data.radius *= stat_scale.get("size", 1.0)
			data.creep_distance *= stat_scale.get("creep", 1.0)  # (Ascension: The Wall creeps faster)
			data.bounce = clampf(data.bounce + stat_scale.get("bounce", 0.0), 0.0, 1.0)
	_base_damping = base_damping
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
	for u in upgrades:
		for key in u.ability_overrides:
			if key in ability:
				ability.set(key, u.ability_overrides[key])
		for key in u.ability_multipliers:
			if key in ability:
				ability.set(key, ability.get(key) * u.ability_multipliers[key])
	for key in stat_scale.get("ability_values", {}):  # exact values from an encounter (Big Brother's double shell)
		if key in ability:
			ability.set(key, stat_scale.ability_values[key])
	var strength: float = (finish.ability_strength if finish != null else 1.0) * stat_scale.get("ability", 1.0)
	if strength != 1.0:
		for key in STRENGTH_PROPERTIES:
			if key in ability:
				ability.set(key, ability.get(key) * strength)
	# Equipment, upgrades and finishes with an effect run next to the figure's own ability.
	_core_ability = ability
	_equipment_effect = _copy_effect(equipment.effect if equipment != null else null)
	_upgrade_effects.clear()
	for u in upgrades:
		if u.extra_effect != null:
			_upgrade_effects.append(_copy_effect(u.extra_effect))
	_finish_effect = _copy_effect(finish.effect if finish != null else null)
	_rebuild_ability()


func _copy_effect(effect: FigureAbility) -> FigureAbility:
	return effect.duplicate() as FigureAbility if effect != null else null


## The figure's own ability plus the equipment / upgrade / finish effects (events go to all of them).
func _rebuild_ability() -> void:
	ability = _core_ability
	var extras: Array = [_equipment_effect]
	extras.append_array(_upgrade_effects)
	extras.append(_finish_effect)
	for extra in extras:
		if extra != null:
			ability = CombinedAbility.new(ability, extra)


## Costume Change relic: swap this figure's equipment during a combat. Stat changes and the effect apply at once;
## the old item's effect is gone (its per-combat state, e.g. a used Parachute, starts fresh with a new copy).
func set_equipment(item: EquipmentData) -> void:
	if equipment != null:
		mass /= equipment.mass_multiplier
		linear_damp /= equipment.damping_multiplier
	equipment = item
	if equipment != null:
		mass *= equipment.mass_multiplier
		linear_damp *= equipment.damping_multiplier
	if physics_material_override != null:
		physics_material_override.bounce = clampf(data.bounce + (equipment.bounce_bonus if equipment != null else 0.0), 0.0, 1.0)
	_equipment_effect = _copy_effect(equipment.effect if equipment != null else null)
	_rebuild_ability()
	queue_redraw()


func _ready() -> void:
	# A tabletop: no gravity, no spinning, slowing down only through linear_damp.
	gravity_scale = 0.0
	lock_rotation = true
	can_sleep = false
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_body_entered)
	body_shape_entered.connect(_on_body_shape_entered)
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
	ability.setup_body(self)


## The Doused status: a purple tint with three drips under the figure, fading as the rounds run out.
func _draw_doused() -> void:
	if doused_rounds <= 0:
		return
	var fade := clampf(float(doused_rounds) / maxf(doused_full, 1), 0.0, 1.0)
	if doused_juice:  # Juicer's juice: a lighter, greener tint
		draw_circle(Vector2.ZERO, radius - 2.0, Color(0.65, 0.95, 0.2, 0.16 * fade))
		draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 48, Color(0.75, 1.0, 0.35, 0.4 * fade), 4.0, true)
		for j in 3:
			var jx := radius * (-0.45 + 0.45 * j)
			draw_circle(Vector2(jx, radius * 0.7 + radius * 0.1 * (j % 2)), radius * 0.08, Color(0.8, 1.0, 0.4, 0.6 * fade))
		return
	draw_circle(Vector2.ZERO, radius - 2.0, Color(0.6, 0.25, 0.85, 0.35 * fade))
	draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 48, Color(0.75, 0.4, 0.95, 0.7 * fade), 5.0, true)
	for i in 3:
		var x := radius * (-0.45 + 0.45 * i)
		var top := Vector2(x, radius * (0.55 + 0.12 * (i % 2)))
		var length := radius * (0.35 + 0.15 * ((i + 1) % 3))
		draw_line(top, top + Vector2(0, length), Color(0.7, 0.35, 0.95, 0.8 * fade), radius * 0.1)
		draw_circle(top + Vector2(0, length + radius * 0.06), radius * 0.1, Color(0.8, 0.5, 1.0, 0.9 * fade))


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
	ability.draw_body(self)
	# A faint circle shows the aura (Crazy Man) around the figure.
	var aura_radius := ability.get_aura_radius(self)
	if aura_radius > 0.0:
		draw_circle(Vector2.ZERO, aura_radius, Color(data.color, 0.08))
		draw_arc(Vector2.ZERO, aura_radius, 0.0, TAU, 72, Color(data.color, 0.3), 4.0, true)
	# A Bummer's aura (faint, in a sour color) around the figure.
	var bummer := ability.get_bummer_stats(self)
	if not bummer.is_empty():
		draw_circle(Vector2.ZERO, bummer.radius, Color(0.55, 0.25, 0.7, 0.09))
		draw_arc(Vector2.ZERO, bummer.radius, 0.0, TAU, 72, Color(0.65, 0.35, 0.8, 0.35), 4.0, true)
	var greyed := team == Team.PLAYER and not flickable
	var fill := data.color.lerp(GREYED_OUT, 0.85) if greyed else data.color
	# The body squashes/stretches along _squash_angle; the details on top only grow.
	var stretch := maxf(1.0 + _squash_amount, 0.2)
	draw_set_transform(Vector2.ZERO, _squash_angle - rotation, Vector2(stretch, 1.0 / stretch) * (1.0 + _pop))
	var own_body := ability.draws_own_body(self)  # (Trangle draws its triangle in draw_body)
	if not own_body:
		draw_circle(Vector2.ZERO, radius, fill)
		# The ring shows which side the figure is on (any figure can be on either side).
		draw_arc(Vector2.ZERO, radius - 4.0, 0.0, TAU, 48, ENEMY_RING if team == Team.ENEMY else PLAYER_RING, 8.0, true)
	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE * (1.0 + _pop))
	if selected:
		draw_arc(Vector2.ZERO, radius + 10.0, 0.0, TAU, 48, Color(1.0, 0.9, 0.3), 8.0, true)
	if not own_body:
		draw_circle(Vector2(-radius, -radius) * 0.3, radius * 0.22, fill.lightened(0.4))
	_draw_finish()
	_draw_doused()
	# A short label so you can tell figures apart (the first letter of the name by default).
	if not ability.draws_own_label(self):
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
	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
	for i in upgrades.size():
		# Little gold pips in the upper right: one per upgrade tier owned.
		var pip := Vector2(radius, -radius) * 0.66 + Vector2(-radius * 0.3 * i, radius * 0.1 * i)
		draw_circle(pip, radius * 0.14, Color(1.0, 0.85, 0.2))
		draw_arc(pip, radius * 0.14, 0.0, TAU, 14, Color(0.2, 0.15, 0.05), 3.0, true)
	if elite:
		draw_arc(Vector2.ZERO, radius + 9.0, 0.0, TAU, 48, Color(1.0, 0.8, 0.2), 7.0, true)
	if equipment != null:
		# A small badge in the lower right shows that this figure carries equipment.
		var badge_center := Vector2(radius, radius) * 0.62
		var badge_radius := radius * 0.34
		draw_circle(badge_center, badge_radius, equipment.color)
		draw_arc(badge_center, badge_radius, 0.0, TAU, 20, Color(0.1, 0.1, 0.12), 4.0, true)
		var badge_size := int(badge_radius * (1.05 if equipment.label.length() <= 1 else 0.85))
		draw_string(ThemeDB.fallback_font, badge_center + Vector2(-badge_radius, badge_size * 0.33), equipment.label,
				HORIZONTAL_ALIGNMENT_CENTER, badge_radius * 2.0, badge_size, Color(0.1, 0.1, 0.12))
	ability.draw_overlay(self)
	if blast_shield:  # a Firecracker on the team protects it from the team's own explosions
		draw_arc(Vector2.ZERO, radius + 7.0, 0.0, TAU, 40, Color(1.0, 0.65, 0.2, 0.45), 3.0, true)
		draw_arc(Vector2.ZERO, radius + 12.0, 0.0, TAU, 40, Color(1.0, 0.65, 0.2, 0.15), 2.0, true)
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
		var multiplier := data.knockback_taken_multiplier * ability.get_knockback_multiplier(self, hitter) \
				* RunManager.relic_knockback_taken(self, hitter) * aura_knockback_multiplier() * zone_knockback_multiplier()
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


## Upgrades and temporary buffs that make this figure's hits push harder.
func _apply_dealt_bonus(other: Figure) -> void:
	if knocked_off or other.knocked_off or other.team == team:
		return
	var bonus := ability.get_dealt_knockback_bonus(self, other) + temp_dealt
	if bonus > 0.0:
		ability.extra_hit_knockback(self, other, bonus)


func _on_body_entered(body: Node) -> void:
	touched_since_flick = true
	if body is Figure:
		# Deferred: physics callbacks can't change physics state directly.
		ability.on_hit.call_deferred(self, body)
		_chain_glue.call_deferred(body)
		var other: Figure = body
		# Velocities change in the same step as the collision, so look at the step before too.
		var speed := maxf((_last_velocity - other._last_velocity).length(),
				(_prev_velocity - other._prev_velocity).length())
		var point := global_position + (other.global_position - global_position).normalized() * radius
		ability.on_impact.call_deferred(self, other, speed, point)
		_apply_dealt_bonus.call_deferred(other)
		if has_meta("spat_explode"):  # a figure an Absorber spat out explodes on its first impact
			var blast: Array = get_meta("spat_explode")
			remove_meta("spat_explode")
			explode.call_deferred(blast[0], blast[1])
		# Both figures get this signal; only the one with the lower id reports the impact.
		if get_instance_id() < other.get_instance_id():
			emit_signal.call_deferred(&"impacted", self, other, speed, point)
			AudioManager.play_clack(speed)
	else:
		ability.on_hit_wall.call_deferred(self, body)
		if body is ShieldWall:
			(body as ShieldWall).on_figure_hit.call_deferred(self)
		AudioManager.play_wall(_last_velocity.length())
		if body is BreakableWall and team == Team.PLAYER:  # the Mad Creator's box: only the player's hits damage it
			body.hit_by(self, _last_velocity if _last_velocity.length() >= _prev_velocity.length() else _prev_velocity)


## Flick power multiplier from teammates' auras (Crazy Man) that this figure stands inside.
func aura_flick_multiplier() -> float:
	var multiplier := 1.0
	if team == Team.ENEMY and RunManager.combat != null and not RunManager.enemy_relics.is_empty():
		multiplier *= RunManager.enemy_relic_power(RunManager.combat, self)  # enemy relics (act 3 elites)
	for source in _aura_sources():
		multiplier *= source.ability.get_aura_flick_multiplier(source)
	multiplier *= charge_power * shock_flick * (doused_flick if doused_rounds > 0 else 1.0)
	multiplier *= enemy_aura_factor().y
	for other in glue_partners():  # glued to an opposing figure: Glue Guy's Tar
		if other.team != team and not other.knocked_off:
			multiplier *= other.ability.get_stuck_enemy_flick_multiplier(other)
	return multiplier


## (knockback taken, flick power) factors from the auras of OPPOSING figures this figure stands in (Crazy Man's
## Frenzy, Bummer's Downer), x each.
func enemy_aura_factor() -> Vector2:
	var factor := Vector2.ONE
	if not is_inside_tree():
		return factor
	for node in get_tree().get_nodes_in_group("figures"):
		var other := node as Figure
		if other == self or other.knocked_off or other.team == team or other.ability == null:
			continue
		var aura := other.ability.get_enemy_aura(other)
		if not aura.is_empty() and other.global_position.distance_to(global_position) <= aura.radius + radius:
			factor *= Vector2(aura.get("knockback", 1.0), aura.get("flick", 1.0))
	return factor


## Knockback-taken multiplier from teammates' auras (below 1 = tougher).
func aura_knockback_multiplier() -> float:
	var multiplier := 1.0
	for source in _aura_sources():
		multiplier *= source.ability.get_aura_knockback_multiplier(source)
	return multiplier


## True if this figure standing at `point` would be inside a teammate's aura (Crazy Man).
func would_be_in_aura(point: Vector2) -> bool:
	if not is_inside_tree():
		return false
	for node in get_tree().get_nodes_in_group("figures"):
		var other := node as Figure
		if other == self or other.knocked_off or other.team != team or other.ability == null:
			continue
		var reach := other.ability.get_aura_radius(other)
		if reach > 0.0 and other.global_position.distance_to(point) <= reach:
			return true
	return false


## The OPPOSING Bummer whose small aura this figure's body touches when standing at `point` ({} if none):
## its stats ({radius}). Such a figure is taken over when its side goes to flick it.
func bummer_effect_at(point: Vector2) -> Dictionary:
	var best := {}
	if not is_inside_tree():
		return best
	for node in get_tree().get_nodes_in_group("figures"):
		var other := node as Figure
		if other == self or other.knocked_off or other.team == team or other.ability == null:
			continue
		var stats := other.ability.get_bummer_stats(other)
		if not stats.is_empty() and other.global_position.distance_to(point) <= stats.radius + radius:
			best = stats
	return best


## The Bummer effect on this figure where it stands now ({} = not in an opposing Bummer's aura).
func bummer_effect() -> Dictionary:
	var effect := bummer_effect_at(global_position)
	if effect.is_empty() and bummed_extra > 0:
		return bummed_stats  # Lingering Gloom: still bummed for one more flick
	return effect


## Alchemist: the knockback multiplier from an enemy debuff zone this figure stands in, or from being Doused by
## one earlier (1 = none). They do not stack: the strongest counts.
func zone_knockback_multiplier() -> float:
	var best := doused_multiplier if doused_rounds > 0 else 1.0
	var combat = RunManager.combat  # the Main node (untyped: Main is not a named class)
	if combat == null or not is_inside_tree():
		return best * temp_taken
	return maxf(best, combat.arena.zone_multiplier_at(global_position, team)) * enemy_aura_factor().x * temp_taken


## Touched an Alchemist's zone: Doused for `rounds` rounds (touching again refreshes it back to the full amount).
func douse(rounds: int, knockback: float, juice := false, flick := 1.0) -> void:
	if doused_rounds > 0 and knockback < doused_multiplier:
		return  # a stronger Douse is active: only the stronger effect applies
	if doused_rounds < rounds or doused_full != rounds or doused_juice != juice:
		queue_redraw()
	doused_rounds = rounds
	doused_full = rounds
	doused_multiplier = knockback
	doused_flick = flick if not juice else 1.0
	doused_juice = juice


func is_doused() -> bool:
	return doused_rounds > 0


## Teammates (not this figure) whose aura reaches this figure.
func _aura_sources() -> Array[Figure]:
	var sources: Array[Figure] = []
	if not is_inside_tree():
		return sources
	for node in get_tree().get_nodes_in_group("figures"):
		var other := node as Figure
		if other == self or other.knocked_off or other.team != team or other.ability == null:
			continue
		var reach := other.ability.get_aura_radius(other)
		if reach > 0.0 and other.global_position.distance_to(global_position) <= reach:
			sources.append(other)
	return sources


## A hit on one of the body's collision shapes: lets the ability react to hits on extra shapes (arms).
func _on_body_shape_entered(_body_rid: RID, body: Node, _body_shape: int, local_shape: int) -> void:
	var other := body as Figure
	if other == null or local_shape == 0:
		return
	var shape_node := shape_owner_get_owner(shape_find_owner(local_shape))
	var speed := maxf((_last_velocity - other._last_velocity).length(),
			(_prev_velocity - other._prev_velocity).length())
	ability.on_shape_hit.call_deferred(self, other, shape_node, speed)


## Below the settle speed right now (not necessarily stopped for good yet).
## A pellet nudged this figure (from rest) a moment ago, so its motion is not a reason for turrets to keep firing.
func is_pellet_driven() -> bool:
	return Time.get_ticks_msec() - last_pellet_ms < 2500


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
	charge_power = 1.0  # (a recharge's bonus and a shock last until this flick)
	shock_flick = 1.0
	_skip_knockback_frames = 2
	_slow_frames = 0
	apply_central_impulse(impulse)
	AudioManager.play_flick(impulse.length() / mass)
	ability.on_flicked(self, impulse)
	flicked.emit(self, impulse)


## Blastoid's other action: fire its projectile at `point` and stay put. Uses up its action like a flick.
func shoot_at(point: Vector2) -> void:
	flickable = false
	turn_flicks += 1
	touched_since_flick = false
	ability.fire_shot_at(self, point)
	AudioManager.play_flick(1000.0)
	ability.on_flicked(self, Vector2.ZERO)


## Pushed by a hit-like effect (an explosion or bump). `source` is the figure that caused it.
## Respects knockback_taken_multiplier and the ability's get_knockback_multiplier.
func take_knockback(impulse: Vector2, source: Figure = null) -> void:
	if is_frozen():
		return
	_skip_knockback_frames = 2
	apply_central_impulse(impulse * data.knockback_taken_multiplier * ability.get_knockback_multiplier(self, source)
			* RunManager.relic_knockback_taken(self, source) * aura_knockback_multiplier() * zone_knockback_multiplier())


## Share of an ENEMY explosion's push this figure ignores because of a teammate Firecracker's Safety Officer cover.
func _explosion_cover(source: Figure) -> float:
	if source == null or source.team == team or not is_inside_tree():
		return 0.0
	var best := 0.0
	for node in get_tree().get_nodes_in_group("figures"):
		var other := node as Figure
		if other.team == team and not other.knocked_off and other.ability != null:
			best = maxf(best, other.ability.get_team_explosion_reduction(other))
	var combat = RunManager.combat
	if combat != null and combat.has_method("lingering_cover_for"):
		best = maxf(best, combat.lingering_cover_for(team))
	return clampf(best, 0.0, 1.0)


## Pushed by an explosion: breaks any glue, then the push is scaled by the ability's
## get_explosion_multiplier (0 = immune).
func take_explosion(impulse: Vector2, source: Figure) -> void:
	unglue()
	impulse *= 1.0 - _explosion_cover(source)
	var multiplier := ability.get_explosion_multiplier(self, source)
	if multiplier > 0.0:
		ability.on_took_explosion(self, impulse * multiplier)  # (Duwall's shell)
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
	var joint := GlueLink.new()
	joint.figure_a = self
	joint.figure_b = other
	joint.z_index = 3
	get_parent().add_child(joint)
	joint.global_position = (global_position + other.global_position) / 2.0
	joint.node_a = joint.get_path_to(self)
	joint.node_b = joint.get_path_to(other)
	joint.softness = 0.0
	_prune_glue()
	other._prune_glue()
	glue_joints.append(joint)
	other.glue_joints.append(joint)


func is_glued() -> bool:
	for joint in glue_joints:
		if is_instance_valid(joint) and not joint.is_queued_for_deletion():
			return true
	return false


## Drops joints that are gone from the list.
func _prune_glue() -> void:
	for i in range(glue_joints.size() - 1, -1, -1):
		if not is_instance_valid(glue_joints[i]) or glue_joints[i].is_queued_for_deletion():
			glue_joints.remove_at(i)


## The figures glued to this one, directly.
func glue_partners() -> Array[Figure]:
	var partners: Array[Figure] = []
	for joint in glue_joints:
		if not is_instance_valid(joint) or joint.is_queued_for_deletion():
			continue
		var link := joint as GlueLink
		if link == null:
			continue
		var partner: Figure = link.figure_b if link.figure_a == self else link.figure_a
		if is_instance_valid(partner) and not partner.knocked_off and not partners.has(partner):
			partners.append(partner)
	return partners


## This figure and everything glued to it, directly or through others (a chain of goo).
func glue_cluster() -> Array[Figure]:
	var cluster: Array[Figure] = [self]
	var i := 0
	while i < cluster.size():
		for partner in cluster[i].glue_partners():
			if not cluster.has(partner):
				cluster.append(partner)
		i += 1
	return cluster


## Glue Guy's upgrade: a figure in a glue cluster with a chain-sticky Glue Guy sticks to whatever it hits,
## as long as the whole chain stays within the cap.
func _chain_glue(other: Figure) -> void:
	if knocked_off or other.knocked_off or not is_glued():
		return
	var cluster := glue_cluster()
	if cluster.has(other):
		return
	var cap := 0
	for member in cluster:
		cap = maxi(cap, member.ability.get_glue_chain_cap(member))
	if cap <= 0:
		return
	var merged := cluster.duplicate()
	for member in other.glue_cluster():
		if not merged.has(member):
			merged.append(member)
	if merged.size() <= cap:
		glue_to(other)
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
	force *= take_detonate_multiplier()
	blast_radius *= RunManager.relic_explosion_multiplier(team)  # Blast Cap
	_blast_radius = blast_radius
	create_tween().tween_property(self, "_blast_progress", 1.0, BLAST_RING_TIME).from(0.0)
	Figure.blast(get_tree(), global_position, blast_radius, force, self, spared)


## Firecracker's Heavy Charges marks the explosives it sets off; their next blast is stronger (used once).
func take_detonate_multiplier() -> float:
	var mult: float = get_meta("detonate_force_mult", 1.0)
	if has_meta("detonate_force_mult"):
		remove_meta("detonate_force_mult")
	return mult


## An explosion at `center` (set off by `source`, which may be null for a power) that pushes every
## figure within blast_radius away, except `source` and `spared`.
static func blast(tree: SceneTree, center: Vector2, blast_radius: float, force: float,
		source: Figure = null, spared: Figure = null, source_team := -1) -> void:
	if source != null:
		source_team = source.team
	var protected := team_has_firecracker(tree, source_team)
	force *= RunManager.explosion_force_multiplier()
	AudioManager.play_boom(blast_radius)
	for wall in tree.get_nodes_in_group("breakable_walls"):
		wall.take_explosion(center, blast_radius, force)
	for node in tree.get_nodes_in_group("figures"):
		var other := node as Figure
		if other == source or other == spared or other.knocked_off:
			continue
		var offset := other.global_position - center
		var distance := offset.length()
		if distance >= blast_radius:
			continue
		var direction := offset.normalized() if distance > 0.01 else Vector2.UP
		if blast_immune(other, source_team, protected):
			other.ability.on_exploded.call_deferred(other, source)  # (it still reacts, e.g. a Firecracker, but is not pushed)
			continue
		other.take_explosion(direction * force * (1.0 - distance / blast_radius), source)
		other.ability.on_exploded.call_deferred(other, source)


## True if any figure of `team` on the table has a Firecracker's explosion immunity.
static func team_has_firecracker(tree: SceneTree, team: int) -> bool:
	if team < 0:
		return false
	for node in tree.get_nodes_in_group("figures"):
		var other := node as Figure
		if other.team == team and not other.knocked_off and other.ability.grants_explosion_immunity(other):
			return true
	return false


## True if an explosion (or implosion) set off by `source_team` does not push `victim`: the player's own blasts never
## push any player figure (the base rule), and an ENEMY Firecracker (`team_protected`) shields the enemy team from its
## own team's blasts. Blasts from the other side always push.
static func blast_immune(victim: Figure, source_team: int, team_protected: bool) -> bool:
	if source_team < 0:
		return false
	if source_team == Team.PLAYER and victim.team == Team.PLAYER:
		return true  # the player's own explosions never push any player figure
	return team_protected and victim.team == source_team


## Asks main.gd to replace this figure with `pieces` ({data, position, velocity} dictionaries).
## `grants_flicks` = the enemy side gets an extra flick per turn for it (Slime does, Splitter doesn't).
func split_into(pieces: Array, grants_flicks := false) -> void:
	split_requested.emit(self, pieces, grants_flicks)


## Sheds `pieces` ({data, position, velocity}) as new figures on this team; this figure stays.
func shed(pieces: Array, grants_flicks := false) -> void:
	shed_requested.emit(self, pieces, grants_flicks)


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


## Duwall's shell burst: this figure becomes `new_data` (a Grunt) for the rest of the combat: its stats and
## look, with the same equipment, finish and difficulty scaling (the upgrade of the old form is dropped).
func transform_into(new_data: FigureData) -> void:
	data = new_data.duplicate() as FigureData
	if finish != null:
		data.knockback_taken_multiplier *= finish.knockback_taken_multiplier
	if not scale_factors.is_empty():
		data.accuracy = minf(data.accuracy * scale_factors.get("accuracy", 1.0), 1.0)
		data.flick_power_multiplier *= scale_factors.get("power", 1.0)
		data.mass *= scale_factors.get("mass", 1.0)
		data.bounce = clampf(data.bounce + scale_factors.get("bounce", 0.0), 0.0, 1.0)
	var new_mass := data.mass
	linear_damp = _base_damping * data.damping_multiplier
	if equipment != null:
		new_mass *= equipment.mass_multiplier
		linear_damp *= equipment.damping_multiplier
	if finish != null:
		new_mass *= finish.mass_multiplier
	set_size(data.radius, new_mass)
	if physics_material_override != null:
		physics_material_override.bounce = clampf(data.bounce + (equipment.bounce_bonus if equipment != null else 0.0), 0.0, 1.0)
	upgrades.clear()
	upgrade_state = Vector2i(-1, 0)
	queue_redraw()


## Changes the figure's radius and mass (the collision shape and the picture follow).
func set_size(new_radius: float, new_mass: float) -> void:
	radius = new_radius
	mass = new_mass
	if _circle != null:
		_circle.radius = new_radius
	queue_redraw()


## Can this figure act in the current flick cycle? (A player figure that has not flicked yet / an enemy that has not
## acted yet.) Used by tap abilities (Magnet's Collapse, Ghost's Teleport, Absorber's Spit).
func can_act_now() -> bool:
	if team == Team.PLAYER:
		return flickable
	var combat = RunManager.combat
	return combat == null or not combat._enemy_cycle.has(get_instance_id())


## A body made of its own collision shapes (Cluster): the usual circle goes, set_size no longer resizes it.
func use_custom_shapes() -> void:
	for child in get_children():
		if child is CollisionShape2D:
			remove_child(child)
			child.queue_free()
	_circle = null


## Called by main.gd at the start of each round: powers that last "a round" count down here.
func tick_round() -> void:
	ability.on_round_ticked(self)
	if stunned_rounds > 0:
		stunned_rounds -= 1
		if stunned_rounds == 0 and team == Team.PLAYER:
			flickable = true
	if doused_rounds > 0:
		doused_rounds -= 1
		queue_redraw()
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
	ability.on_became_flickable(self)


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
		AudioManager.play_fall()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	tween.tween_callback(queue_free)
