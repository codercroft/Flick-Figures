class_name BlastoidAbility
extends FigureAbility
## Blastoid has two actions and each turn it takes ONE of them: flick it (drag, it moves like an average figure
## and does not fire) or TAP a spot on the board (a quick tap with no drag): it stays where it is and fires a
## small projectile at that spot. The projectile makes a minor explosion on contact with a figure, wall or pin,
## or when it reaches the tapped spot (through the shared Figure.blast, so Firecracker, Duwall's shell and other
## explosion effects react). Shot range is capped at `max_range`; a faint circle shows it while Blastoid is
## selected. Blastoid carries the registry's "explosive" tag: a Firecracker's hit sets it off.

## How fast the projectile flies (px/s).
@export var projectile_speed := 1200.0
## The furthest it can fly. A tap beyond this still fires, but the shot bursts at this distance.
@export var max_range := 700.0
@export var projectile_radius := 14.0
## The minor explosion (a Bombo's is 224 / 900).
@export var blast_radius := 170.0
@export var blast_force := 800.0


## Tap-to-fire stats ({} = none); the enemy AI reads the same dictionary.
func get_shot_stats(_figure: Figure) -> Dictionary:
	return {"speed": projectile_speed, "range": max_range, "radius": projectile_radius,
			"blast_radius": blast_radius, "blast_force": blast_force}


func fire_shot_at(figure: Figure, point: Vector2) -> void:
	if figure.get_parent() == null:
		return
	var offset := point - figure.global_position
	if offset.length() < 1.0:
		return
	var start_gap := figure.radius + projectile_radius + 4.0
	var projectile := Projectile.new()
	projectile.owner_figure = figure
	projectile.direction = offset.normalized()
	projectile.speed = projectile_speed
	projectile.range_left = maxf(minf(offset.length(), max_range) - start_gap, 0.0)
	projectile.radius = projectile_radius
	projectile.blast_radius = blast_radius
	projectile.blast_force = blast_force
	projectile.position = figure.position + projectile.direction * start_gap
	figure.get_parent().add_child(projectile)


func get_ai_blast(_figure: Figure) -> Dictionary:
	return {"radius": blast_radius, "force": blast_force, "when": "detonate"}


## Set off by a teammate Firecracker: a minor blast right here.
func detonate(figure: Figure) -> void:
	figure.explode(blast_radius, blast_force)


## While selected (and still able to act): a faint circle showing how far a shot can reach.
func draw_overlay(figure: Figure) -> void:
	if not figure.selected or not figure.flickable:
		return
	figure.draw_circle(Vector2.ZERO, max_range, Color(1.0, 0.6, 0.25, 0.05))
	figure.draw_arc(Vector2.ZERO, max_range, 0.0, TAU, 96, Color(1.0, 0.6, 0.25, 0.3), 4.0, true)
