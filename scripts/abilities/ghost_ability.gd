class_name GhostAbility
extends FigureAbility
## During its OWN side's turn, whenever it leaves the table it wraps to the opposite edge (Pac-Man style)
## and keeps its velocity: no limit, and no condition on what it touched. During the opponent's turn,
## leaving the table knocks it off as usual. (Damping always slows it, so a wrapping Ghost still comes to
## rest and the turn still ends; `max_settle_time` is the safety net.)

## Upgrade switch (Full Haunt): it can also wrap during the opponent's turn, but only `opponent_wraps_per_turn`
## times per turn; after that it falls off the table normally (so it can still be killed).
@export var wraps_on_opponent_turn := false
@export var opponent_wraps_per_turn := 1
## Haunt path: +x knockback dealt and +x flick power for the combat for every wrap so far.
@export var wrap_knockback := 0.0
@export var wrap_power := 0.0
## Phase path: it passes through allies (Ghost Walk), can teleport to another spot once per turn (Teleport; it can
## still flick), and allies it passes through can wrap around the table once (Wrap Gift).
@export var phase_allies := false
@export var teleport := false
@export var gift_wraps := false

var _wraps := 0
var _teleported := false
var _phased: Array[Figure] = []

var _opponent_wraps_used := 0


## True while Ghost's side is the one taking its turn.
func _own_turn(figure: Figure) -> bool:
	var combat = RunManager.combat  # the Main node (untyped: Main is not a named class)
	return combat != null and combat.turret_side == figure.team


## Can it wrap right now? Always on its own turn; on the opponent's turn only with the upgrade and wraps left.
func _wraps_now(figure: Figure) -> bool:
	if _own_turn(figure):
		return true
	return wraps_on_opponent_turn and _opponent_wraps_used < opponent_wraps_per_turn


func on_turn_ended(_figure: Figure) -> void:
	_opponent_wraps_used = 0
	_teleported = false


func get_dealt_knockback_bonus(_figure: Figure, _other: Figure) -> float:
	return wrap_knockback * _wraps


func get_flick_power_multiplier(_figure: Figure) -> float:
	return 1.0 + wrap_power * _wraps


func on_flicked(figure: Figure, _impulse: Vector2) -> void:
	if not phase_allies:
		return
	for node in figure.get_tree().get_nodes_in_group("figures"):
		var other := node as Figure
		if other != null and other != figure and other.team == figure.team and not other.knocked_off:
			figure.add_collision_exception_with(other)
			_phased.append(other)


func on_stopped(figure: Figure) -> void:
	for other in _phased:
		if is_instance_valid(other):
			figure.remove_collision_exception_with(other)
	_phased.clear()


func on_physics_process(figure: Figure, _delta: float) -> void:
	if not gift_wraps or _phased.is_empty():
		return
	for other in _phased:  # an ally the Ghost is passing through gets one wrap
		if is_instance_valid(other) and figure.global_position.distance_to(other.global_position) < figure.radius + other.radius:
			other.set_meta("ghost_wrap", true)


## Phase path (Teleport): tap an empty spot to move there, once per turn; the Ghost can still flick.
func get_tap_ability(figure: Figure) -> Dictionary:
	if not teleport or figure.knocked_off:
		return {}
	return {"kind": "point", "ready": not _teleported and figure.can_act_now(), "uses_action": false, "hint": "Teleported. Drag anywhere to flick"}


func use_tap_ability(figure: Figure, point: Vector2) -> bool:
	var combat = RunManager.combat
	if combat == null or _teleported:
		return false
	if not combat.arena.is_spot_free(figure.get_world_2d().direct_space_state, combat.board.board_rect, point, figure.radius):
		return false
	_teleported = true
	figure.global_position = point
	figure.on_deck = false
	figure._update_collision()
	figure.show_popup("Boo!", Color(0.85, 0.9, 1.0))
	return true


func on_left_table(figure: Figure, table: Rect2) -> bool:
	if not _wraps_now(figure):
		return false
	if not _own_turn(figure):
		_opponent_wraps_used += 1
	_wraps += 1
	var position := figure.global_position
	# Re-enter from the far side, keeping the same distance past the edge.
	position.x = table.position.x + fposmod(position.x - table.position.x, table.size.x)
	position.y = table.position.y + fposmod(position.y - table.position.y, table.size.y)
	figure.global_position = position
	figure.show_popup("Boo!", Color(0.85, 0.9, 1.0))
	return true


## For the enemy AI: effectively unlimited on its own turn, otherwise the opponent-turn wraps it has left.
func get_wrap_count(figure: Figure) -> int:
	if _own_turn(figure):
		return 99
	return maxi(opponent_wraps_per_turn - _opponent_wraps_used, 0) if wraps_on_opponent_turn else 0


## Enemy AI: teleport next to the nearest player figure (about 340 px away) when it is far from all of them.
func ai_tap_point(figure: Figure, opponents: Array) -> Vector2:
	var nearest: Figure = null
	var best := INF
	for other in opponents:
		if is_instance_valid(other) and not other.knocked_off and not other.on_deck:
			var d: float = other.global_position.distance_to(figure.global_position)
			if d < best:
				best = d
				nearest = other
	if nearest == null or best < 520.0:
		return Vector2.INF
	return nearest.global_position + (figure.global_position - nearest.global_position).normalized() * 340.0
