class_name BlastoidAbility
extends FigureAbility
## Flicking Blastoid does not move it: it fires a small projectile in the aimed direction instead. The pull
## strength sets the projectile's speed and range. The projectile makes a minor explosion on contact or at its
## max range (through the shared Figure.blast, so Firecracker, Duwall's shell and other explosion effects react).
## Blastoid carries the registry's "explosive" tag: a Firecracker's hit sets it off (a minor blast on the spot).

@export var speed_min := 700.0
@export var speed_max := 1500.0
@export var range_min := 250.0
@export var range_max := 900.0
@export var projectile_radius := 14.0
## The minor explosion (a Bombo's is 320 / 900).
@export var blast_radius := 170.0
@export var blast_force := 800.0


## 0 to 1: how hard the flick was pulled.
func _power(figure: Figure, impulse: Vector2) -> float:
	var combat = RunManager.combat
	var max_force: float = combat.max_flick_force if combat != null else 2400.0
	return clampf(impulse.length() / maxf(max_force * figure.data.flick_power_multiplier, 1.0), 0.0, 1.0)


func replaces_flick(_figure: Figure) -> bool:
	return true


func fire_instead_of_flick(figure: Figure, impulse: Vector2) -> void:
	if impulse.is_zero_approx() or figure.get_parent() == null:
		return
	var power := _power(figure, impulse)
	var projectile := Projectile.new()
	projectile.owner_figure = figure
	projectile.direction = impulse.normalized()
	projectile.speed = lerpf(speed_min, speed_max, power)
	projectile.range_left = lerpf(range_min, range_max, power)
	projectile.radius = projectile_radius
	projectile.blast_radius = blast_radius
	projectile.blast_force = blast_force
	projectile.position = figure.position + projectile.direction * (figure.radius + projectile_radius + 4.0)
	figure.get_parent().add_child(projectile)


func get_aim_range(figure: Figure, impulse: Vector2) -> float:
	return lerpf(range_min, range_max, _power(figure, impulse))


func get_ai_projectile(_figure: Figure) -> Dictionary:
	return {"speed_min": speed_min, "speed_max": speed_max, "range_min": range_min, "range_max": range_max,
			"radius": projectile_radius, "blast_radius": blast_radius, "blast_force": blast_force}


func get_ai_blast(_figure: Figure) -> Dictionary:
	return {"radius": blast_radius, "force": blast_force, "when": "detonate"}


## Set off by a teammate Firecracker: a minor blast right here.
func detonate(figure: Figure) -> void:
	figure.explode(blast_radius, blast_force)
