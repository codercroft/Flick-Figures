class_name PinataAbility
extends FigureAbility
## Caught in an explosion, it pays the player some money, bursts into small figures that scatter outward
## from the explosion (the Pinata itself is removed), and takes less push from the blast.

## Money paid when it bursts.
@export var payout := 2
## How much of the explosion's push it takes (1 = normal).
@export var explosion_push_scale := 0.4
## What it bursts into, and how many.
@export var piece: FigureData
@export var piece_count := 3
## How fast (px/s) the pieces scatter away from the explosion.
@export var burst_speed := 320.0
## How far apart (degrees) their paths fan out.
@export var burst_spread_degrees := 70.0
## How much of its own speed after the push the pieces keep.
@export var inherit_velocity := 0.3

var _burst := false


func get_explosion_multiplier(_figure: Figure, _source: Figure) -> float:
	return explosion_push_scale


func on_exploded(figure: Figure, source: Figure) -> void:
	if _burst or figure.knocked_off:
		return
	_burst = true
	if figure.team == Figure.Team.PLAYER:
		RunManager.money += payout
		figure.show_popup("+$%d" % payout)
	if piece == null:
		return
	# Scatter outward from the explosion (a power's blast has no source figure: pick a direction).
	var away := Vector2.UP
	if source != null and not source.global_position.is_equal_approx(figure.global_position):
		away = (figure.global_position - source.global_position).normalized()
	var pieces: Array[Dictionary] = []
	for i in piece_count:
		var side := -1.0 + 2.0 * i / maxi(piece_count - 1, 1)  # -1 ... 1
		pieces.append({
			"data": piece,
			"position": figure.global_position + away.orthogonal() * (i - (piece_count - 1) / 2.0) * piece.radius * 2.2,
			"velocity": away.rotated(deg_to_rad(burst_spread_degrees) * side) * burst_speed + figure.linear_velocity * inherit_velocity,
		})
	figure.split_into(pieces)
