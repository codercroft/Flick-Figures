class_name UltimateShieldonAbility
extends FigureAbility
## Ultimate Shieldon: at the end of each of its side's turns (once everything settles) it raises a curved shield
## covering `arc_degrees` of its body (240 = two thirds), centered toward the nearest opposing figure; the back third stays
## open. The shield is part of its collision (extra collision polygon): hits that come from the shield side bounce off hard and
## move the Shieldon only a little (`shield_knockback_multiplier`); hits on the open side land normally. It is
## unbreakable and drops when the Ultimate Shieldon is flicked.

@export var arc_degrees := 240.0
## Shield thickness and the gap between the body's edge and the shield (px).
@export var shield_thickness := 26.0
@export var shield_gap := 12.0
## Share of knockback the Shieldon takes from hits that come from the shield side.
@export var shield_knockback_multiplier := 0.1
@export var arc_steps := 20
## Knockback taken from hits on the OPEN side (or while no shield is up). The shield side keeps its tiny multiplier above.
@export var open_knockback_multiplier := 2.0

var _shield: CollisionPolygon2D
var _angle := 0.0  # world direction (radians) the shield is centered on


func on_flicked(figure: Figure, _impulse: Vector2) -> void:
	_drop(figure)


func on_turn_ended(figure: Figure) -> void:
	var combat := RunManager.combat
	if combat != null and combat.turret_side == figure.team and not figure.knocked_off and figure.is_inside_tree():
		raise_shield(figure)


func raise_shield(figure: Figure) -> void:
	_drop(figure)
	var toward := _toward_nearest_opponent(figure)
	_angle = toward.angle() if toward != Vector2.ZERO else (Vector2.DOWN if figure.team == Figure.Team.ENEMY else Vector2.UP).angle()
	var inner := figure.radius + shield_gap
	var outer := inner + shield_thickness
	var half := deg_to_rad(arc_degrees) / 2.0
	var points := PackedVector2Array()
	for i in arc_steps + 1:
		points.append(Vector2.from_angle(_angle - half + 2.0 * half * i / arc_steps) * outer)
	for i in range(arc_steps, -1, -1):
		points.append(Vector2.from_angle(_angle - half + 2.0 * half * i / arc_steps) * inner)
	_shield = CollisionPolygon2D.new()
	_shield.polygon = points
	figure.add_child(_shield)
	figure.queue_redraw()


func _drop(figure: Figure) -> void:
	if _shield != null:
		if is_instance_valid(_shield):
			figure.remove_child(_shield)  # out of the physics body right away
			_shield.queue_free()
		_shield = null
	figure.queue_redraw()


func has_shield() -> bool:
	return _shield != null


func shield_angle() -> float:
	return _angle


## True if `point` lies on the shielded side (within half the arc of the shield's center direction).
func covers(figure: Figure, point: Vector2) -> bool:
	if _shield == null:
		return false
	var bearing := (point - figure.global_position).angle()
	return absf(angle_difference(bearing, _angle)) <= deg_to_rad(arc_degrees) / 2.0


func get_knockback_multiplier(figure: Figure, source: Figure) -> float:
	if _shield != null and source != null and covers(figure, source.global_position):
		return shield_knockback_multiplier
	return open_knockback_multiplier


func _toward_nearest_opponent(figure: Figure) -> Vector2:
	var best := Vector2.ZERO
	var best_distance := INF
	for node in figure.get_tree().get_nodes_in_group("figures"):
		var other := node as Figure
		if other == null or other.knocked_off or other.team == figure.team:
			continue
		var distance := other.global_position.distance_to(figure.global_position)
		if distance < best_distance:
			best_distance = distance
			best = (other.global_position - figure.global_position).normalized()
	return best


## Enemy AI: the shield's arc (degrees) while it can be raised, else {}.
func get_ai_shield(_figure: Figure) -> Dictionary:
	return {"arc": arc_degrees}


## The shield is drawn as a thick steel-blue arc with bright edges; the OPEN side shows a faint dashed orange ring.
func draw_overlay(figure: Figure) -> void:
	if _shield == null:
		return
	var inner := figure.radius + shield_gap
	var mid := inner + shield_thickness / 2.0
	var half := deg_to_rad(arc_degrees) / 2.0
	figure.draw_arc(Vector2.ZERO, mid, _angle - half, _angle + half, 48, Color(0.45, 0.78, 0.95), shield_thickness, true)
	figure.draw_arc(Vector2.ZERO, inner + shield_thickness, _angle - half, _angle + half, 48, Color(0.9, 0.97, 1.0), 4.0, true)
	figure.draw_arc(Vector2.ZERO, inner, _angle - half, _angle + half, 48, Color(0.15, 0.3, 0.5), 4.0, true)
	for edge in [-half, half]:
		figure.draw_circle(Vector2.from_angle(_angle + edge) * mid, shield_thickness * 0.65, Color(0.9, 0.97, 1.0))
	var open_start := _angle + half
	var open_end := _angle + TAU - half
	var steps := 9
	for i in steps:
		if i % 2 == 0:
			var a0 := open_start + (open_end - open_start) * i / steps
			var a1 := open_start + (open_end - open_start) * (i + 1) / steps
			figure.draw_arc(Vector2.ZERO, inner + shield_thickness / 2.0, a0, a1, 6, Color(1.0, 0.6, 0.2, 0.75), 6.0, true)
