class_name Implosion
extends Node2D
## A short pull toward a point (Short Fuse when its figure is knocked off): for `seconds` it pulls every
## figure within `radius` toward `center`, harder the nearer they are (linear falloff). Then it removes itself.

var center := Vector2.ZERO
var radius := 300.0
var strength := 1800.0  # px/s per second at the center
var seconds := 0.4
## Black Hole (Magnet upgrade): it never pulls figures of the source's own team.
var friendly_safe := false
var source: Figure  # never pulls itself (it is already off the table)

var _age := 0.0
var _source_team := -1


func _ready() -> void:
	AudioManager.play_implosion()


func _physics_process(delta: float) -> void:
	_age += delta
	if is_instance_valid(source):
		_source_team = source.team
	var source_team := _source_team
	var protected := Figure.team_has_firecracker(get_tree(), source_team)
	for node in get_tree().get_nodes_in_group("figures"):
		var figure := node as Figure
		if figure == source or figure.knocked_off or figure.is_frozen() or Figure.blast_immune(figure, source_team, protected):
			continue
		if friendly_safe and figure.team == source_team:
			continue
		var offset := center - figure.global_position
		var distance := offset.length()
		if distance > radius or distance < 1.0:
			continue
		# (nudge, not a force: a resting figure's first slow frames would otherwise be zeroed by the settle logic)
		figure.nudge(offset / distance * strength * (1.0 - distance / radius) * delta)
	if _age >= seconds:
		queue_free()


func _draw() -> void:
	# A ring that shrinks toward the point.
	var t := clampf(_age / seconds, 0.0, 1.0)
	draw_arc(Vector2.ZERO, radius * (1.0 - t), 0.0, TAU, 48, Color(0.75, 0.45, 1.0, 0.7 * (1.0 - t)), 6.0, true)


func _process(_delta: float) -> void:
	queue_redraw()
