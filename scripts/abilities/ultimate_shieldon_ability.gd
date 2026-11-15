class_name UltimateShieldonAbility
extends FigureAbility
## Ultimate Shieldon: at the end of each of its side's turns (once everything settles) it raises a curved shield made of
## `segment_count` (3) segments that together cover `arc_degrees` (240, so about 80 degrees each), centered toward the
## nearest opposing figure; the rest stays open. Each segment is its own collision shape with its own health, like
## Duwall's shell: hits and explosions from its side damage it, cracks show, and when it breaks it is gone for the rest
## of the combat. Hits from the shield side bounce off hard and move the Shieldon only a little
## (`shield_knockback_multiplier`); hits on the open side, or on a broken segment, land with `open_knockback_multiplier`.
## The shield drops when the Ultimate Shieldon is flicked and goes up again (intact segments only) after its next turn.

@export var arc_degrees := 240.0
## How many segments the arc is split into (each covers arc_degrees / segment_count).
@export var segment_count := 3
## Shell damage one segment takes before it breaks: about 2 full-power Grunt hits (measured ~3100 each).
@export var segment_health := 6000.0
## Explosion pushes (impulse) count as segment damage times this.
@export var explosion_damage_scale := 1.0
## Cracks appear at these fractions of a segment's health (light, then heavy).
@export var light_crack_at := 1.0 / 3.0
@export var heavy_crack_at := 2.0 / 3.0
## Shield thickness and the gap between the body's edge and the shield (px).
@export var shield_thickness := 26.0
@export var shield_gap := 12.0
## Share of knockback the Shieldon takes from hits that come from an intact shield segment.
@export var shield_knockback_multiplier := 0.1
## Collision polygon steps for the WHOLE arc (split between the segments).
@export var arc_steps := 24
## Knockback taken from hits on the OPEN side, on a broken segment, or while no shield is up.
@export var open_knockback_multiplier := 2.0

var _angle := 0.0  # world direction (radians) the arc is centered on
var _up := false
var _health: Array[float] = []  # damage taken per segment
var _broken: Array[bool] = []
var _shapes: Array[CollisionPolygon2D] = []  # one per segment (null once broken)


func _ensure_state() -> void:
	while _health.size() < segment_count:
		_health.append(0.0)
		_broken.append(false)
		_shapes.append(null)


func segment_arc() -> float:
	return deg_to_rad(arc_degrees) / maxf(float(segment_count), 1.0)


## The world angle (radians) of the CENTER of segment `index` when the arc is centered on `arc_angle`.
func segment_center(index: int, arc_angle: float) -> float:
	return arc_angle + (index - (segment_count - 1) / 2.0) * segment_arc()


func intact_count() -> int:
	_ensure_state()
	var count := 0
	for i in segment_count:
		if not _broken[i]:
			count += 1
	return count


func is_segment_broken(index: int) -> bool:
	_ensure_state()
	return _broken[index]


## 0 (fresh) to 1 (about to break).
func segment_fraction(index: int) -> float:
	_ensure_state()
	return clampf(_health[index] / segment_health, 0.0, 1.0)


func on_flicked(figure: Figure, _impulse: Vector2) -> void:
	_drop(figure)


func on_turn_ended(figure: Figure) -> void:
	var combat := RunManager.combat
	if combat != null and combat.turret_side == figure.team and not figure.knocked_off and figure.is_inside_tree():
		raise_shield(figure)


## Puts the shield up (intact segments only) turned so that they face the opposing figures (see `plan_angle`).
func raise_shield(figure: Figure) -> void:
	_ensure_state()
	_drop(figure)
	if intact_count() == 0:
		figure.queue_redraw()
		return
	var targets: Array[Vector2] = []
	for node in figure.get_tree().get_nodes_in_group("figures"):
		var other := node as Figure
		if other != null and not other.knocked_off and other.team != figure.team:
			targets.append(other.global_position)
	_angle = plan_angle(figure.global_position, figure.team, targets)
	_up = true
	var inner := figure.radius + shield_gap
	var outer := inner + shield_thickness
	var steps := maxi(int(ceil(float(arc_steps) / segment_count)), 4)
	for i in segment_count:
		if _broken[i]:
			continue
		var from := segment_center(i, _angle) - segment_arc() / 2.0
		var to := from + segment_arc()
		var points := PackedVector2Array()
		for s in steps + 1:
			points.append(Vector2.from_angle(lerpf(from, to, float(s) / steps)) * outer)
		for s in range(steps, -1, -1):
			points.append(Vector2.from_angle(lerpf(from, to, float(s) / steps)) * inner)
		var shape := CollisionPolygon2D.new()
		shape.polygon = points
		figure.add_child(shape)
		_shapes[i] = shape
	figure.queue_redraw()


## Which way the arc should face when the Shieldon stands at `point`: centered on the nearest opponent while every segment
## is intact; with broken segments it is turned so an INTACT segment faces the nearest opponent (then as many of the others
## as possible), changing as little as it can from the centered position.
func plan_angle(point: Vector2, team: int, targets: Array[Vector2]) -> float:
	_ensure_state()
	var nearest := Vector2.ZERO
	var best_distance := INF
	for target in targets:
		var d := target.distance_to(point)
		if d < best_distance:
			best_distance = d
			nearest = target
	var base := (nearest - point).angle() if best_distance < INF else (Vector2.DOWN if team == Figure.Team.ENEMY else Vector2.UP).angle()
	if intact_count() == segment_count or intact_count() == 0 or best_distance == INF:
		return base
	var best_angle := base
	var best_score := -INF
	for k in 72:
		var candidate := base + deg_to_rad(5.0) * ((k + 1) / 2) * (1 if k % 2 == 0 else -1)
		var score := 0.0
		if bearing_covered(candidate, (nearest - point).angle()):
			score += 100.0
		for target in targets:
			if target != nearest and bearing_covered(candidate, (target - point).angle()):
				score += 10.0 / (1.0 + target.distance_to(point) / 400.0)
		score -= absf(angle_difference(candidate, base))
		if score > best_score:
			best_score = score
			best_angle = candidate
	return best_angle


## True if an INTACT segment of an arc centered on `arc_angle` covers the world direction `bearing`.
func bearing_covered(arc_angle: float, bearing: float) -> bool:
	_ensure_state()
	for i in segment_count:
		if not _broken[i] and absf(angle_difference(bearing, segment_center(i, arc_angle))) <= segment_arc() / 2.0:
			return true
	return false


## The segment index whose range contains `bearing` (world angle) for the current arc, or -1 if it is in the open part.
func segment_at(bearing: float) -> int:
	for i in segment_count:
		if absf(angle_difference(bearing, segment_center(i, _angle))) <= segment_arc() / 2.0:
			return i
	return -1


func _drop(figure: Figure) -> void:
	_ensure_state()
	for i in _shapes.size():
		var shape := _shapes[i]
		if shape != null and is_instance_valid(shape):
			figure.remove_child(shape)  # out of the physics body right away
			shape.queue_free()
		_shapes[i] = null
	_up = false
	figure.queue_redraw()


func has_shield() -> bool:
	return _up


func shield_angle() -> float:
	return _angle


## True if `point` is on a side an intact, raised segment protects.
func covers(figure: Figure, point: Vector2) -> bool:
	if not _up:
		return false
	var segment := segment_at((point - figure.global_position).angle())
	return segment >= 0 and not _broken[segment]


func get_knockback_multiplier(figure: Figure, source: Figure) -> float:
	if source != null and covers(figure, source.global_position):
		return shield_knockback_multiplier
	return open_knockback_multiplier


## Impacts on a raised segment damage it like Duwall's shell (momentum the OTHER figure brings in).
func on_impact(figure: Figure, other: Figure, _speed: float, _point: Vector2) -> void:
	if not _up or figure.knocked_off or other.team == figure.team:
		return
	var bearing := (other.global_position - figure.global_position).angle()
	var segment := segment_at(bearing)
	if segment < 0 or _broken[segment]:
		return
	var inward := (figure.global_position - other.global_position).normalized()
	var other_closing := maxf(other._prev_velocity.dot(inward), 0.0)
	var my_closing := maxf(-figure._prev_velocity.dot(inward), 0.0)
	var closing := other_closing + my_closing
	if closing <= 0.0:
		return
	var reduced_mass := figure.mass * other.mass / (figure.mass + other.mass)
	var restitution := clampf(figure.data.bounce + other.data.bounce, 0.0, 1.0)
	_damage_segment(figure, segment, (1.0 + restitution) * reduced_mass * closing * (other_closing / closing))


## Explosion pushes hit the segment that faces the blast (the push points away from it).
func on_took_explosion(figure: Figure, impulse: Vector2) -> void:
	if not _up or impulse == Vector2.ZERO:
		return
	var segment := segment_at((-impulse).angle())
	if segment >= 0 and not _broken[segment]:
		_damage_segment(figure, segment, impulse.length() * explosion_damage_scale)


func _damage_segment(figure: Figure, segment: int, amount: float) -> void:
	_health[segment] += amount
	figure.queue_redraw()
	if _health[segment] >= segment_health:
		_break_segment(figure, segment)


func _break_segment(figure: Figure, segment: int) -> void:
	_broken[segment] = true
	var shape := _shapes[segment]
	if shape != null and is_instance_valid(shape):
		figure.remove_child(shape)
		shape.queue_free()
	_shapes[segment] = null
	ShellBurst.spawn(figure, figure.data.color)
	figure.show_popup("Shield broken!", Color(0.7, 0.9, 1.0))
	figure.queue_redraw()


## Enemy AI: the shield's shape (arc, intact segments) and a way to ask where it would face from a given spot.
func get_ai_shield(_figure: Figure) -> Dictionary:
	_ensure_state()
	return {"arc": arc_degrees, "intact": intact_count(), "segments": segment_count, "ability": self}


## Each intact segment is a steel-blue arc with bright edges that darkens and cracks as it takes damage; everything that is
## not covered by an intact segment (the open back and any broken segment) shows a dashed orange ring.
func draw_overlay(figure: Figure) -> void:
	if not _up:
		return
	var inner := figure.radius + shield_gap
	var mid := inner + shield_thickness / 2.0
	for i in segment_count:
		if _broken[i]:
			continue
		var from := segment_center(i, _angle) - segment_arc() / 2.0
		var to := from + segment_arc()
		var damage := segment_fraction(i)
		var color := Color(0.45, 0.78, 0.95).lerp(Color(0.5, 0.45, 0.5), damage * 0.7)
		figure.draw_arc(Vector2.ZERO, mid, from, to, 24, color, shield_thickness, true)
		figure.draw_arc(Vector2.ZERO, inner + shield_thickness, from, to, 24, Color(0.9, 0.97, 1.0), 4.0, true)
		figure.draw_arc(Vector2.ZERO, inner, from, to, 24, Color(0.15, 0.3, 0.5), 4.0, true)
		figure.draw_circle(Vector2.from_angle(from) * mid, shield_thickness * 0.5, Color(0.9, 0.97, 1.0))
		figure.draw_circle(Vector2.from_angle(to) * mid, shield_thickness * 0.5, Color(0.9, 0.97, 1.0))
		if damage >= light_crack_at:
			var heavy := damage >= heavy_crack_at
			var count := 4 if heavy else 2
			var rng := RandomNumberGenerator.new()
			rng.seed = figure.get_instance_id() + i * 13
			for c in count:
				var angle := lerpf(from, to, (c + 0.5) / count) + rng.randf_range(-0.04, 0.04)
				var points := PackedVector2Array()
				for step in 5:
					var radius := inner + shield_thickness * step / 4.0
					points.append(Vector2.from_angle(angle + rng.randf_range(-0.03, 0.03)) * radius)
				figure.draw_polyline(points, Color(0.08, 0.1, 0.18, 0.9), 5.0 if heavy else 3.0, true)
	var steps := 60
	for s in steps:
		if s % 2 == 0:
			var a0 := TAU * s / steps
			var a1 := TAU * (s + 1) / steps
			if not bearing_covered(_angle, (a0 + a1) / 2.0):
				figure.draw_arc(Vector2.ZERO, mid, a0, a1, 3, Color(1.0, 0.6, 0.2, 0.75), 6.0, true)
