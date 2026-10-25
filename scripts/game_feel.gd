extends Node2D
## "Juice": squash/stretch, impact particles, screen shake, knock-off pop and haptics.
## Figures emit signals and main.gd connects them to the on_* functions below.
## Every effect has its own on/off switch in the Inspector.

@export_group("Squash & stretch")
@export var squash_stretch_enabled := true
## How far a figure stretches along its flick on release (0.35 = 35% longer).
@export var flick_stretch := 0.35
## How far figures squash when they bump into each other.
@export var hit_squash := 0.25
## How long the wobble back to normal takes (seconds).
@export var squash_time := 0.4

@export_group("Impact particles and shake")
@export var impact_particles_enabled := true
@export var screen_shake_enabled := true
## Bumps slower than this (px/s) get no effects.
@export var min_impact_speed := 150.0
## Bumps at this speed (px/s) or faster get the full effect.
@export var max_impact_speed := 2000.0
@export var max_impact_particles := 24
@export var impact_particle_color := Color(1.0, 0.95, 0.7)
## Strongest screen shake (px).
@export var max_shake := 18.0
@export var shake_duration := 0.25

@export_group("Knock-off pop")
@export var knock_off_pop_enabled := true
## How much bigger (0.5 = 50%) a figure swells as it pops.
@export var pop_swell := 0.5
@export var pop_time := 0.35
@export var pop_particles := 20

@export_group("Haptics (phones only)")
@export var haptics_enabled := true
@export var flick_haptic_ms := 30
@export var hit_haptic_ms := 50
## Only hits at least this fast (px/s) buzz the phone.
@export var hit_haptic_min_speed := 700.0
## Skip buzzes that come sooner than this after the last one (ms).
@export var min_haptic_gap_ms := 60

var _shake := 0.0
var _last_vibrate_ms := 0
var _fade := Gradient.new()  # particle color over life: opaque to transparent

@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	_fade.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	_fade.offsets = PackedFloat32Array([0.0, 1.0])


func _process(delta: float) -> void:
	_shake = maxf(_shake - max_shake / shake_duration * delta, 0.0)
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake


## A figure was just flicked (player or enemy).
func on_flicked(figure: Figure, impulse: Vector2) -> void:
	var speed := impulse.length() / figure.mass
	var strength := clampf(speed / max_impact_speed, 0.2, 1.0)
	if squash_stretch_enabled:
		figure.play_squash(impulse.normalized(), flick_stretch * strength, squash_time)
	if figure.team == Figure.Team.PLAYER:
		_vibrate(flick_haptic_ms, lerpf(0.3, 1.0, strength))


## Two figures collided. `speed` is their relative speed; `point` is where they touched.
func on_impact(figure: Figure, other: Figure, speed: float, point: Vector2) -> void:
	if not is_instance_valid(figure) or not is_instance_valid(other) or speed < min_impact_speed:
		return
	var strength := clampf(speed / max_impact_speed, 0.1, 1.0)
	if impact_particles_enabled:
		_burst(point, impact_particle_color, int(ceil(max_impact_particles * strength)), 200.0 + 500.0 * strength)
	if screen_shake_enabled:
		_shake = maxf(_shake, max_shake * strength)
	if squash_stretch_enabled:
		var toward_other := (other.global_position - figure.global_position).normalized()
		figure.play_squash(toward_other, -hit_squash * strength, squash_time)
		other.play_squash(toward_other, -hit_squash * strength, squash_time)
	if speed >= hit_haptic_min_speed:
		_vibrate(hit_haptic_ms, lerpf(0.4, 1.0, strength))


## A figure left the table (it is already fading out).
func on_fell_off(figure: Figure) -> void:
	if knock_off_pop_enabled:
		figure.play_pop(pop_swell, pop_time)
		_burst(figure.global_position, figure.data.color, pop_particles, 450.0)


func _burst(pos: Vector2, color: Color, count: int, speed: float) -> void:
	var particles := CPUParticles2D.new()
	particles.position = pos
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = count
	particles.lifetime = 0.45
	particles.direction = Vector2.UP
	particles.spread = 180.0  # all directions
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.damping_min = speed
	particles.damping_max = speed * 1.5
	particles.scale_amount_min = 5.0
	particles.scale_amount_max = 11.0
	particles.color = color
	particles.color_ramp = _fade
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.2).timeout.connect(particles.queue_free)


func _vibrate(duration_ms: int, amplitude: float) -> void:
	if not haptics_enabled or not OS.has_feature("mobile"):
		return
	var now := Time.get_ticks_msec()
	if now - _last_vibrate_ms < min_haptic_gap_ms:
		return
	_last_vibrate_ms = now
	Input.vibrate_handheld(duration_ms, amplitude)
