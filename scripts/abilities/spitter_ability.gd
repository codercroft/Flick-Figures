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

var water := 0.0
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
