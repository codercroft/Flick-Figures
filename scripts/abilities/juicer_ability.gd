class_name JuicerAbility
extends FigureAbility
## While it moves, Juicer leaves a trail of sticky floor material. Each piece pushes any OPPOSING
## figure that rolls over it (moving ones only) the way Juicer was MOVING when it laid the piece, and lightly Douses any that touch it. Its own team is not
## affected. Pieces fade after a few rounds. The push is much weaker than an arena boost patch (470).

## Rounds a trail piece lasts (a round = until the player's next turn).
@export var trail_rounds := 3
## Push of a piece in px/s per second (arena boost patches use 470).
@export var boost_acceleration := 150.0
## A piece adds no more speed once a figure goes this fast.
@export var boost_max_speed := 1800.0
## Size of a piece and the distance between pieces (px).
@export var segment_radius := 55.0
@export var segment_spacing := 80.0
## Juicer only leaves a trail while faster than this (px/s).
@export var min_trail_speed := 150.0
## Oldest pieces vanish early beyond this many per Juicer, so the board does not fill up.
@export var max_segments := 30
## Splash: when Juicer hits an opposing figure (faster than `splash_min_speed`), this many boost pieces
## appear in a ring `splash_distance` px around the impact point, each pushing opposing figures outward from it. They
## fade like the trail (`trail_rounds`).
@export var splash_count := 6
@export var splash_distance := 75.0
@export var splash_min_speed := 150.0

## Juice Douses: an opposing figure touching a trail piece or splash piece takes +20% knockback for 2 rounds (refreshed on
## contact, not stacking; an Alchemist's stronger Douse wins if a figure has both).
@export var douse_rounds := 2
@export var douse_knockback := 1.2
## Slick path (Edge Steering): trail pieces push toward the nearest table edge instead of along Juicer's travel.
@export var steer_to_edge := false

var _last_drop := Vector2.INF


func on_flicked(figure: Figure, _impulse: Vector2) -> void:
	_last_drop = figure.global_position


func on_physics_process(figure: Figure, _delta: float) -> void:
	var combat := RunManager.combat
	if combat == null or figure.on_deck or figure.linear_velocity.length() < min_trail_speed:
		return
	if _last_drop == Vector2.INF:
		_last_drop = figure.global_position
	if figure.global_position.distance_to(_last_drop) < segment_spacing:
		return
	_last_drop = figure.global_position
	var push := figure.linear_velocity.normalized()  # the way Juicer was moving when it laid this piece
	if steer_to_edge:
		push = _toward_nearest_edge(figure.global_position, combat.board.get_table_rect())
	combat.arena.add_trail_segment(figure, figure.global_position, push, self)


func on_impact(figure: Figure, other: Figure, speed: float, point: Vector2) -> void:
	var combat := RunManager.combat
	if combat == null or other == null or other.team == figure.team or speed < splash_min_speed or figure.knocked_off:
		return
	for i in splash_count:
		var outward := Vector2.from_angle(TAU * i / splash_count)
		combat.arena.add_trail_segment(figure, point + outward * splash_distance, outward, self)


func _toward_nearest_edge(point: Vector2, table: Rect2) -> Vector2:
	var options := {
		Vector2.LEFT: point.x - table.position.x, Vector2.RIGHT: table.end.x - point.x,
		Vector2.UP: point.y - table.position.y, Vector2.DOWN: table.end.y - point.y}
	var best := Vector2.UP
	var best_distance := INF
	for direction in options:
		if options[direction] < best_distance:
			best_distance = options[direction]
			best = direction
	return best
