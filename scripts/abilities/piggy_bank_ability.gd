class_name PiggyBankAbility
extends FigureAbility
## Gets heavier, bigger and harder-hitting the more money the player holds. At $0 it is a normal figure;
## around $20 it has about 2x its mass and deals about 2x the knockback; at $50 about 3.5x of both. Past
## `soft_cap_start` the growth eases off toward `max_scale`, so it can never break the physics.

## Growth per $ held (0.05 = +5% of its base mass per $): $20 -> 2x, $50 -> 3.5x.
@export var scale_per_dollar := 0.05
## From this many $ on, the growth levels off (a soft cap) toward `max_scale`.
@export var soft_cap_start := 50.0
## The most it can ever scale (mass and knockback dealt).
@export var max_scale := 4.0
## How much its radius grows per +1.0 of scale (0.12: 1.3x as wide at 3.5x).
@export var size_per_scale := 0.12

var _base_mass := 0.0
var _base_radius := 0.0
var _applied := -1.0


## The scale (1 = a normal figure) for a given amount of money.
func scale_for(money: float) -> float:
	var linear := 1.0 + scale_per_dollar * money
	if money <= soft_cap_start:
		return linear
	var at_start := 1.0 + scale_per_dollar * soft_cap_start
	return at_start + (maxf(max_scale, at_start) - at_start) * (1.0 - exp(-(money - soft_cap_start) / maxf(soft_cap_start, 1.0)))


func on_physics_process(figure: Figure, _delta: float) -> void:
	if _base_mass == 0.0:
		_base_mass = figure.mass
		_base_radius = figure.radius
	var scale := scale_for(RunManager.money)
	if absf(scale - _applied) < 0.01:
		return
	_applied = scale
	figure.set_size(_base_radius * (1.0 + size_per_scale * (scale - 1.0)), _base_mass * scale)


func on_impact(figure: Figure, other: Figure, speed: float, _point: Vector2) -> void:
	var direction := (other.global_position - figure.global_position).normalized()
	# Only when the Piggy Bank is the one doing the hitting.
	if figure._prev_velocity.dot(direction) + other._prev_velocity.dot(direction) <= 0.0:
		return
	var scale := scale_for(RunManager.money)
	if scale <= 1.01 or _base_mass == 0.0:
		return
	# The extra mass already gives a bigger push; add just enough on top so the knockback dealt is about
	# `scale` times what its base mass would have dealt.
	var share_now := figure.mass / (figure.mass + other.mass)
	var share_base := _base_mass / (_base_mass + other.mass)
	var extra := scale * share_base / share_now - 1.0
	if extra <= 0.0:
		return
	other.take_knockback(direction * speed * share_now * extra * other.mass, figure)
