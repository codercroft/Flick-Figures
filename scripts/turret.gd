class_name Turret
extends RigidBody2D
## An Engineer's turret: a weak, light, pin-like body that figures can knock around and off the table.
## During the OPPOSING side's turn it fires a Pellet at the nearest opposing figure every `interval`
## seconds (counted only while it may fire; the first shot comes `interval` after the turn starts).
## It is not a Figure, so it never counts for winning or losing. It goes when its Engineer does.

var owner_figure: Figure
var team := Figure.Team.PLAYER
var stats := {}
var radius := 30.0

var _cooldown := 0.0
var _aim := Vector2.UP
var _flash := 0.0


func setup(engineer: Figure, turret_stats: Dictionary) -> void:
	owner_figure = engineer
	team = engineer.team
	stats = turret_stats
	radius = turret_stats.radius
	mass = turret_stats.mass
	linear_damp = turret_stats.damping
	_cooldown = turret_stats.interval
	_aim = Vector2.UP if team == Figure.Team.PLAYER else Vector2.DOWN


func _ready() -> void:
	gravity_scale = 0.0
	lock_rotation = true
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	# Like an enemy figure for collisions (everyone's flicks and shoves move it); never a Figure.
	collision_layer = Figure.LAYER_ENEMY
	collision_mask = Figure.LAYER_ON_DECK | Figure.LAYER_FLICKED | Figure.LAYER_ENEMY | Figure.LAYER_ARENA
	var material := PhysicsMaterial.new()
	material.bounce = 0.7
	material.friction = 0.0
	physics_material_override = material
	var circle := CircleShape2D.new()
	circle.radius = radius
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(owner_figure) or owner_figure.knocked_off:
		_remove()
		return
	var combat = RunManager.combat  # the Main node (untyped: Main is not a named class)
	if combat == null:
		return
	if not combat.board.get_table_rect().has_point(global_position):
		_remove()  # knocked off the table
		return
	_flash = maxf(_flash - delta * 4.0, 0.0)
	queue_redraw()
	# Only the opposing side's turn counts: otherwise it waits with a full cooldown.
	if combat.turret_side < 0 or combat.turret_side == team:
		_cooldown = stats.interval
		return
	var target := _nearest_target()
	if target == null:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var aim_point := _aim_point(target)
	if global_position.distance_to(aim_point) > stats.range:
		return
	_cooldown = stats.interval
	_fire((aim_point - global_position).normalized())


func _nearest_target() -> Figure:
	var best: Figure = null
	var best_distance: float = stats.range
	for node in get_tree().get_nodes_in_group("figures"):
		var figure := node as Figure
		if figure.knocked_off or figure.team == team or figure.on_deck:
			continue  # (figures waiting on the deck are not targets)
		var distance := global_position.distance_to(figure.global_position)
		if distance <= best_distance:
			best = figure
			best_distance = distance
	return best


## Where to shoot: ahead of a moving target so the pellet meets it.
func _aim_point(target: Figure) -> Vector2:
	var point := target.global_position
	if stats.lead and not target.is_slow():
		point += target.linear_velocity * (global_position.distance_to(point) / stats.speed)
	return point


func _fire(direction: Vector2) -> void:
	_aim = direction
	_flash = 1.0
	var pellet := Pellet.new()
	pellet.team = team
	pellet.owner_figure = owner_figure
	pellet.direction = direction
	pellet.speed = stats.speed
	pellet.range_left = stats.range
	pellet.impulse = stats.impulse
	pellet.radius = stats.pellet_radius
	pellet.position = position + direction * (radius + stats.pellet_radius + 2.0)
	get_parent().add_child(pellet)


func _remove() -> void:
	var parent := get_parent()
	if parent != null:
		parent.remove_child(self)  # out of the physics space right away
	queue_free()


func _draw() -> void:
	var team_color := Figure.ENEMY_RING if team == Figure.Team.ENEMY else Figure.PLAYER_RING
	if is_instance_valid(owner_figure) and not owner_figure.knocked_off:
		draw_dashed_line(Vector2.ZERO, to_local(owner_figure.global_position), Color(team_color, 0.3), 3.0, 14.0)
	var body := Color(0.45, 0.55, 0.6)
	draw_circle(Vector2.ZERO, radius, body.darkened(0.4))
	draw_circle(Vector2.ZERO, radius - 5.0, body)
	# The barrel points where it last aimed, and glows when it fires.
	draw_line(Vector2.ZERO, _aim * (radius + 12.0), body.darkened(0.55), 12.0)
	draw_line(Vector2.ZERO, _aim * (radius + 12.0), Color(1.0, 0.85, 0.3).lerp(body, 1.0 - _flash), 6.0)
	draw_circle(Vector2.ZERO, radius * 0.4, body.lightened(0.3))
	draw_arc(Vector2.ZERO, radius + 7.0, 0.0, TAU, 32, team_color, 5.0, true)
