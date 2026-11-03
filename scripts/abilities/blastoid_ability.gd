class_name BlastoidAbility
extends FigureAbility
## Blastoid has two actions and each turn it takes ONE of them: flick it (drag, it moves like an average figure
## and does not fire) or TAP a spot on the board (a quick tap with no drag): it stays where it is and fires a
## small projectile at that spot. The projectile makes a minor explosion on contact with a figure, wall or pin,
## or when it reaches the tapped spot (through the shared Figure.blast, so Firecracker, Duwall's shell and other
## explosion effects react). There is no range limit: tap anywhere on the board. Blastoid carries the registry's "explosive" tag: a Firecracker's hit sets it off.

## How fast the projectile flies (px/s).
@export var projectile_speed := 1200.0
@export var projectile_radius := 14.0
## The minor explosion (a Bombo's is 224 / 900).
@export var blast_radius := 170.0
@export var blast_force := 800.0


## Tap-to-fire stats ({} = none); the enemy AI reads the same dictionary.
func get_shot_stats(_figure: Figure) -> Dictionary:
	return {"speed": projectile_speed, "radius": projectile_radius,
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
	projectile.range_left = maxf(offset.length() - start_gap, 0.0)
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
