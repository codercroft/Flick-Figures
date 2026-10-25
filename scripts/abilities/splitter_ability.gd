class_name SplitterAbility
extends FigureAbility
## On its first hit after being flicked, it breaks into smaller minis that burst apart from the
## impact point. The minis are normal figures on the same team (they count for win/loss).

## What it breaks into.
@export var piece: FigureData
@export var piece_count := 2
## Hits slower than this (px/s) do not split it.
@export var min_hit_speed := 150.0
## How fast (px/s) the minis burst away from the impact point.
@export var burst_speed := 260.0
## How far apart (degrees) the minis' paths fan out.
@export var burst_spread_degrees := 55.0
## How much of its own speed after the hit the minis keep (0 = none, 1 = all).
@export var inherit_velocity := 0.2

var _armed := false


func on_flicked(_figure: Figure, _impulse: Vector2) -> void:
	_armed = true


func on_impact(figure: Figure, _other: Figure, speed: float, point: Vector2) -> void:
	if not _armed or piece == null or speed < min_hit_speed or figure.knocked_off:
		return
	_armed = false
	var away := (figure.global_position - point).normalized()
	if away.is_zero_approx():
		away = Vector2.UP
	var pieces: Array[Dictionary] = []
	for i in piece_count:
		var side := -1.0 + 2.0 * i / maxi(piece_count - 1, 1)  # -1 ... 1
		pieces.append({
			"data": piece,
			"position": figure.global_position + away.orthogonal() * (i - (piece_count - 1) / 2.0) * piece.radius * 2.2,
			"velocity": away.rotated(deg_to_rad(burst_spread_degrees) * side) * burst_speed + figure.linear_velocity * inherit_velocity,
		})
	figure.split_into(pieces)
