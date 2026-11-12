class_name SpitterAbility
extends FigureAbility
## With Spitter selected, PRESS AND HOLD (about a quarter second without much movement; dragging is a normal
## flick) to spray a stream of water toward your finger. It follows the finger while held; releasing stops it.
## Spraying is Spitter's action for the turn (spray OR flick). The drops give figures they hit a light, steady
## push: enough to nudge or redirect, not to knock a resting figure off from the middle. It holds a limited
## amount of water per combat and shrinks (and gets lighter) as it empties, down to `min_size` of its size.

## Seconds of spray in a full tank.
@export var max_water := 4.0
## Size and mass at an empty tank, as a share of full.
@export var min_size := 0.5
## Drops per second while spraying, their speed (px/s), range (px) and push (impulse each).
@export var drops_per_second := 20.0
@export var drop_speed := 800.0
@export var drop_range := 450.0
@export var drop_impulse := 20.0
## Random spread of the stream (degrees either side).
@export var spread_degrees := 5.0
## Sprinkler path: the spray Douses what it hits (1.0 = no Douse; 1.2 lightly, 1.5 heavily) and water refills this much
## (seconds) every round.
@export var spray_douse := 1.0
@export var water_per_round := 0.0

var water := 0.0
var _flicked_this_turn := false
var _post_offered := false  # the after-flick spray offer was made this turn
var spraying := false
var _point := Vector2.ZERO
var _full_radius := 0.0
var _full_mass := 0.0
var _emit_timer := 0.0


func setup_body(figure: Figure) -> void:
	water = max_water
	_full_radius = figure.radius
	_full_mass = figure.mass


func get_spray_stats(_figure: Figure) -> Dictionary:
	return {"range": drop_range, "speed": drop_speed, "drops_per_second": drops_per_second,
			"impulse": drop_impulse, "water": water, "max_water": max_water}


func set_spray(figure: Figure, active: bool, point := Vector2.ZERO) -> void:
	if active and water <= 0.0:
		active = false
	spraying = active
	_point = point
	if active:
		_emit_timer = 0.0


func on_physics_process(figure: Figure, delta: float) -> void:
	if not spraying or figure.knocked_off:
		return
	water = maxf(water - delta, 0.0)
	_resize(figure)
	_emit_timer -= delta
	var interval := 1.0 / drops_per_second
	while _emit_timer <= 0.0:
		_emit_timer += interval
		_emit(figure)
	if water <= 0.0:
		spraying = false  # (the player's release still ends the action)


func _emit(figure: Figure) -> void:
	if figure.get_parent() == null:
		return
	var aim := _point - figure.global_position
	var direction := aim.normalized() if aim.length() > 5.0 else Vector2.UP
	direction = direction.rotated(deg_to_rad(randf_range(-spread_degrees, spread_degrees)))
	var drop := Droplet.new()
	drop.team = figure.team
	drop.owner_figure = figure
	drop.direction = direction
	drop.speed = drop_speed
	drop.range_left = drop_range
	drop.impulse = drop_impulse
	drop.douse = spray_douse
	drop.position = figure.position + direction * (figure.radius + 6.0)
	figure.get_parent().add_child(drop)


func _resize(figure: Figure) -> void:
	var share := lerpf(min_size, 1.0, water / maxf(max_water, 0.01))
	figure.set_size(_full_radius * share, _full_mass * share)


## The water level: a blue arc around the body.
func draw_overlay(figure: Figure) -> void:
	var fraction := water / maxf(max_water, 0.01)
	figure.draw_arc(Vector2.ZERO, figure.radius + 7.0, -PI / 2.0, -PI / 2.0 + TAU * fraction, 32,
			Color(0.4, 0.75, 1.0, 0.9), 6.0, true)


func on_round_ticked(figure: Figure) -> void:
	if water_per_round > 0.0 and not spraying:
		water = minf(water + water_per_round, max_water)
		_resize(figure)
		figure.queue_redraw()


func on_flicked(_figure: Figure, _impulse: Vector2) -> void:
	_flicked_this_turn = true


func on_turn_ended(_figure: Figure) -> void:
	_flicked_this_turn = false
	_post_offered = false


## Once its flick has settled it may still spray that turn (the same water, so the total stays limited).
func wants_post_action(figure: Figure) -> String:
	if _flicked_this_turn and not _post_offered and water > 0.05 and not figure.knocked_off:
		_post_offered = true
		return "spray"
	return ""
