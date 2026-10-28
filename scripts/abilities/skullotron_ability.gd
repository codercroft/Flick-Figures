class_name SkullotronAbility
extends FigureAbility
## Skull-o-tron: ONE physics body with a core and `arm_count` short arms, each ending in a ball (extra
## collision shapes on the same body). It spins while it moves, so the arms sweep around and hit
## things. An arm hit hard enough (`break_speed`) breaks off and its ball becomes a separate enemy
## (`ball`), which adds a flick to the enemy side's turns. With every arm gone the core is lighter.

@export var arm_count := 3
## From the core's edge to the ball's center (px).
@export var arm_length := 75.0
@export var arm_thickness := 30.0
@export var ball_radius := 38.0
## Relative speed (px/s) of a hit on an arm or ball that breaks the arm off.
@export var break_speed := 650.0
## The enemy a broken-off ball becomes.
@export var ball: FigureData
## How fast (px/s) a freed ball flies outward.
@export var burst_speed := 320.0
## While moving it spins at this many rad/s per px/s of speed, up to `max_spin`. The angle turned in a move is
## spin_per_speed x the distance travelled (speed integrates to distance), so 0.017 turns about 180 degrees
## per 180px move (the AI's typical shot).
@export var spin_per_speed := 0.017
@export var max_spin := 9.0
## With every arm gone, the core's mass is multiplied by this (lighter = easier to knock off).
@export var armless_mass_multiplier := 0.3
## At most one arm breaks per this many ms (a single smash can't strip all three).
@export var break_cooldown_ms := 350

var _arms: Array[Dictionary] = []  # {angle, arm_shape, ball_shape, attached}
var _base_mass := 0.0
var _last_break_ms := -100000


func setup_body(figure: Figure) -> void:
	figure.lock_rotation = false
	figure.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	figure.angular_damp = 4.0
	_base_mass = figure.mass
	_arms.clear()
	for i in arm_count:
		var angle := -PI / 2.0 + TAU * i / arm_count
		var direction := Vector2.from_angle(angle)
		var arm_node := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(arm_length, arm_thickness)
		arm_node.shape = rect
		arm_node.position = direction * (figure.radius + arm_length / 2.0 - 4.0)
		arm_node.rotation = angle
		figure.add_child(arm_node)
		var ball_node := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = ball_radius
		ball_node.shape = circle
		ball_node.position = direction * (figure.radius + arm_length)
		figure.add_child(ball_node)
		_arms.append({"angle": angle, "arm": arm_node, "ball": ball_node, "attached": true})


func on_physics_process(figure: Figure, _delta: float) -> void:
	var speed := figure.linear_velocity.length()
	if speed > figure.stop_speed:
		figure.angular_velocity = minf(speed * spin_per_speed, max_spin)  # it spins while it moves
	else:
		figure.angular_velocity = 0.0


func on_shape_hit(figure: Figure, _other: Figure, shape_node: Node, speed: float) -> void:
	if speed < break_speed or figure.knocked_off:
		return
	if Time.get_ticks_msec() - _last_break_ms < break_cooldown_ms:
		return
	for arm in _arms:
		if arm.attached and (arm.arm == shape_node or arm.ball == shape_node):
			_break_arm(figure, arm)
			return


func _break_arm(figure: Figure, arm: Dictionary) -> void:
	_last_break_ms = Time.get_ticks_msec()
	arm.attached = false
	var ball_position: Vector2 = figure.to_global(arm.ball.position)
	var outward := Vector2.from_angle(arm.angle + figure.rotation)
	for node in [arm.arm, arm.ball]:
		figure.remove_child(node)  # out of the physics body right away
		node.queue_free()
	if ball != null:
		figure.shed([{
			"data": ball,
			"position": ball_position + outward * 6.0,
			"velocity": outward * burst_speed + figure.linear_velocity * 0.5,
		}], true)
	if arms_left() == 0:
		figure.mass = _base_mass * armless_mass_multiplier
	figure.queue_redraw()


func arms_left() -> int:
	var left := 0
	for arm in _arms:
		if arm.attached:
			left += 1
	return left


func draw_body(figure: Figure) -> void:
	var color := figure.data.color
	for arm in _arms:
		if not arm.attached:
			continue
		var direction := Vector2.from_angle(arm.angle)
		var start := direction * figure.radius * 0.6
		var end := direction * (figure.radius + arm_length)
		figure.draw_line(start, end, color.darkened(0.4), arm_thickness)
		figure.draw_circle(end, ball_radius, color.darkened(0.2))
		figure.draw_arc(end, ball_radius - 3.0, 0.0, TAU, 24, Color(1, 1, 1, 0.8), 5.0, true)
		figure.draw_circle(end + Vector2(-ball_radius, -ball_radius) * 0.3, ball_radius * 0.2, color.lightened(0.5))
