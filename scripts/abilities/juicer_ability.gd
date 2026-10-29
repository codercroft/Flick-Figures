class_name JuicerAbility
extends FigureAbility
## While it moves, Juicer leaves a trail of speed-boosting floor material. Each piece pushes any
## figure that rolls over it (moving ones only) in the direction Juicer was travelling. Pieces fade
## after a few rounds. The boost is much weaker than an arena boost patch (470).

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
## appear in a ring `splash_distance` px around the impact point, each pushing outward from it. They
## fade like the trail (`trail_rounds`).
@export var splash_count := 6
@export var splash_distance := 75.0
@export var splash_min_speed := 150.0

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
	combat.arena.add_trail_segment(figure, figure.global_position, figure.linear_velocity.normalized(), self)


func on_impact(figure: Figure, other: Figure, speed: float, point: Vector2) -> void:
	var combat := RunManager.combat
	if combat == null or other == null or other.team == figure.team or speed < splash_min_speed or figure.knocked_off:
		return
	for i in splash_count:
		var outward := Vector2.from_angle(TAU * i / splash_count)
		combat.arena.add_trail_segment(figure, point + outward * splash_distance, outward, self)
