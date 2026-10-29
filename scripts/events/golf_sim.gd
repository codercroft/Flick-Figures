class_name GolfSim
extends RefCounted
## A small stand-alone simulation of one golf ball, used by the Mini-Golf opponent to try shots. It
## follows the same rules as the real physics closely enough to plan bank shots: speed falls with
## damping, the ball bounces off the course walls (rotated rectangles) and pins (which kick it), floor
## patches slow, boost or turn it (the Arena's own `predict_floor_velocity`), and the hole captures it
## when it is over it slowly enough. All positions are world space.

var walls: Array[Dictionary] = []  # {center, half, rotation}
var pins: Array[Dictionary] = []  # {center, radius}
var arena: Arena
var hole := Vector2.ZERO
var hole_radius := 36.0
var capture_speed := 450.0
var ball_radius := 24.0
var damping := 1.5
var stop_speed := 15.0
## Bounce off walls and pins (1 = no energy lost; the real walls lose almost none).
var restitution := 0.95
var pin_kick := 1.3
var step := 1.0 / 90.0
var max_steps := 900
## Other balls, treated as fixed round obstacles: {center, radius}.
var obstacles: Array[Dictionary] = []


func setup(data: ArenaData, origin: Vector2, arena_node: Arena) -> void:
	arena = arena_node
	walls.clear()
	pins.clear()
	for wall in data.walls:
		walls.append({"center": origin + wall.position, "half": wall.size / 2.0, "rotation": deg_to_rad(wall.rotation_degrees)})
	for pin in data.pins:
		pins.append({"center": origin + pin.position, "radius": pin.radius})


## Rolls a ball from `from` with `velocity`. Returns {end, sunk, steps}.
func roll(from: Vector2, velocity: Vector2) -> Dictionary:
	var pos := from
	var vel := velocity
	for i in max_steps:
		vel = arena.predict_floor_velocity(pos, vel, step) if arena != null else vel
		vel *= maxf(1.0 - damping * step, 0.0)
		pos += vel * step
		for wall in walls:
			_bounce_wall(wall, pos, vel)
			pos = _p
			vel = _v
		for pin in pins:
			_bounce_circle(pin.center, float(pin.radius) + ball_radius, pos, vel, pin_kick)
			pos = _p
			vel = _v
		for other in obstacles:
			_bounce_circle(other.center, float(other.radius) + ball_radius, pos, vel, 1.0)
			pos = _p
			vel = _v
		var speed := vel.length()
		if pos.distance_to(hole) < hole_radius and speed < capture_speed:
			return {"end": hole, "sunk": true, "steps": i}
		if speed < stop_speed:
			return {"end": pos, "sunk": false, "steps": i}
	return {"end": pos, "sunk": false, "steps": max_steps}


# Results of the bounce helpers (GDScript has no multiple return values without allocating).
var _p := Vector2.ZERO
var _v := Vector2.ZERO


func _bounce_wall(wall: Dictionary, pos: Vector2, vel: Vector2) -> void:
	_p = pos
	_v = vel
	var center: Vector2 = wall.center
	var half: Vector2 = wall.half
	var rotation: float = wall.rotation
	var local := (pos - center).rotated(-rotation)
	var closest := local.clamp(-half, half)
	var offset := local - closest
	var distance := offset.length()
	if distance >= ball_radius:
		return
	var normal_local: Vector2
	var push: float
	if distance > 0.001:
		normal_local = offset / distance
		push = ball_radius - distance
	else:
		# The center is inside the wall: leave through the nearest face.
		var gap := half - local.abs()
		if gap.x < gap.y:
			normal_local = Vector2(signf(local.x), 0.0)
			push = gap.x + ball_radius
		else:
			normal_local = Vector2(0.0, signf(local.y))
			push = gap.y + ball_radius
	var normal := normal_local.rotated(rotation)
	_p = pos + normal * push
	var into := vel.dot(normal)
	if into < 0.0:
		_v = vel - (1.0 + restitution) * into * normal


func _bounce_circle(center: Vector2, reach: float, pos: Vector2, vel: Vector2, kick: float) -> void:
	_p = pos
	_v = vel
	var offset := pos - center
	var distance := offset.length()
	if distance >= reach or distance < 0.001:
		return
	var normal := offset / distance
	_p = center + normal * reach
	var into := vel.dot(normal)
	if into < 0.0:
		_v = (vel - (1.0 + restitution) * into * normal) * kick
