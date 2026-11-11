class_name BlastoidAbility
extends FigureAbility
## Blastoid has two actions and each turn it takes ONE of them: flick it (drag, it moves like an average figure
## and does not fire) or TAP a spot on the board (a quick tap with no drag): it stays where it is and fires a
## small projectile at that spot. The projectile makes a minor explosion on contact with a figure, wall or pin,
## or when it reaches the tapped spot (through the shared Figure.blast, so Duwall's shell, Blast Cap and other
## explosion effects react). There is no range limit: tap anywhere on the board. Blastoid carries the registry's "explosive" tag: when a teammate's hit (Bombo's Shrapnel upgrade,
## or anything else that "sets off" explosives) detonates it, it fires a rocket at the nearest opposing figure on the
## table and stays put. Upgrade Twin Rockets: every shot fires 2 rockets.

## How fast the projectile flies (px/s).
@export var projectile_speed := 1200.0
@export var projectile_radius := 14.0
## The minor explosion (a Bombo's is 224 / 900).
@export var blast_radius := 170.0
@export var blast_force := 1200.0
## Rockets per shot (the Twin Rockets upgrade sets 2).
@export var rockets_per_shot := 1
## On a tap with 2+ rockets they fan out by this many degrees either side of the tapped point.
@export var spread_degrees := 6.0
## Rocket Ring: firing also sends this many rockets out all around Blastoid (0 = none).
@export var ring_rockets := 0
@export var ring_distance := 420.0
## Quake Warheads (Nuke path): a rocket that hits an opponent first slams THAT opponent along the rocket's direction with
## `direct_hit_multiplier` x the rocket's normal knockback (0 = off; the normal, reduced-radius blast still goes off), then every OTHER
## opposing figure gets the Earthquake shove (`earthquake_speed`).
@export var earthquake_on_hit := false
@export var earthquake_speed := 380.0
@export var direct_hit_multiplier := 0.0
## The share of a rocket's force a figure touching it normally feels (the blast falloff at contact).
@export var direct_hit_falloff := 0.55


## Tap-to-fire stats ({} = none); the enemy AI reads the same dictionary.
func get_shot_stats(_figure: Figure) -> Dictionary:
	return {"speed": projectile_speed, "radius": projectile_radius,
			"blast_radius": blast_radius, "blast_force": blast_force, "rockets": rockets_per_shot}


func fire_shot_at(figure: Figure, point: Vector2) -> void:
	if figure.get_parent() == null:
		return
	var offset := point - figure.global_position
	if offset.length() < 1.0:
		return
	var count := maxi(rockets_per_shot, 1)
	for i in count:
		var angle := 0.0
		if count > 1:
			angle = deg_to_rad(lerpf(-spread_degrees, spread_degrees, float(i) / float(count - 1)))
		_fire_rocket(figure, figure.global_position + offset.rotated(angle))
	_fire_ring(figure)


## Rocket Ring: rockets all around.
func _fire_ring(figure: Figure) -> void:
	for i in ring_rockets:
		_fire_rocket(figure, figure.global_position + Vector2.from_angle(TAU * i / ring_rockets) * ring_distance)


## Quake Warheads: the target takes a huge direct shove, every other opponent gets the Earthquake shove.
func on_projectile_hit(figure: Figure, target: Figure, direction := Vector2.ZERO) -> void:
	if target.team == figure.team:
		return
	if direct_hit_multiplier > 0.0 and direction != Vector2.ZERO:
		# `direct_hit_multiplier` x the rocket's normal knockback on a figure it touches (`direct_hit_falloff` of its force; the Nuke
		# path's small blast radius would otherwise leave the target out of its own blast). The blast itself still goes off.
		var push := direction.normalized() * blast_force * RunManager.explosion_force_multiplier() * direct_hit_falloff * direct_hit_multiplier
		target.take_explosion(push, figure)
	if not earthquake_on_hit:
		return
	for node in figure.get_tree().get_nodes_in_group("figures"):
		var other := node as Figure
		if other != null and not other.knocked_off and other.team != figure.team and other != target:
			other.nudge(Vector2.from_angle(randf() * TAU) * earthquake_speed)


## One rocket from `figure` toward `point` (it bursts at the point or on the first thing it meets).
func _fire_rocket(figure: Figure, point: Vector2) -> void:
	var offset := point - figure.global_position
	var start_gap := figure.radius + projectile_radius + 4.0
	var projectile := Projectile.new()
	projectile.owner_figure = figure
	projectile.direction = offset.normalized()
	projectile.speed = projectile_speed
	projectile.range_left = maxf(offset.length() - start_gap, 0.0)
	projectile.radius = projectile_radius
	projectile.blast_radius = blast_radius
	projectile.blast_force = blast_force
	projectile.position = figure.position + projectile.direction * start_gap
	figure.get_parent().add_child(projectile)


func get_ai_blast(_figure: Figure) -> Dictionary:
	return {"radius": blast_radius, "force": blast_force, "when": "detonate"}


## Set off by a teammate (the explosive tag): fires a rocket at the nearest opposing figure on the table (Twin Rockets: one at
## each of the 2 nearest, both at the same one if only one is left). Blastoid stays put and keeps its action.
func detonate(figure: Figure) -> void:
	_fire_ring(figure)
	var targets := nearest_opponents(figure, maxi(rockets_per_shot, 1))
	for i in maxi(rockets_per_shot, 1):
		if targets.is_empty():
			return
		_fire_rocket(figure, targets[mini(i, targets.size() - 1)].global_position)


## The `count` nearest opposing figures on the table, nearest first (shared with the enemy AI).
static func nearest_opponents(figure: Figure, count: int) -> Array[Figure]:
	var found: Array[Figure] = []
	for node in figure.get_tree().get_nodes_in_group("figures"):
		var other := node as Figure
		if other == null or other.knocked_off or other.team == figure.team:
			continue
		found.append(other)
	found.sort_custom(func(a: Figure, b: Figure) -> bool:
		return a.global_position.distance_squared_to(figure.global_position) < b.global_position.distance_squared_to(figure.global_position))
	return found.slice(0, count)
