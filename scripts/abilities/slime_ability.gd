class_name SlimeAbility
extends FigureAbility
## Splits into smaller slimes when hit hard. Each piece is its own enemy with its own turn.

## Impact speed (px/s) needed to split it.
@export var split_speed := 700.0
## What it splits into. Leave empty for a slime that never splits.
@export var piece: FigureData
@export var piece_count := 2
## How fast (px/s) the pieces burst away from the impact point.
@export var burst_speed := 230.0
## How far apart (degrees) the pieces' paths fan out around the straight-away direction.
@export var burst_spread_degrees := 55.0
## How much of the momentum of the hit the pieces keep (0 = none, 1 = all): a share of the slime's own speed
## right after the hit. Low, so a fresh split is not thrown straight off the table.
@export var inherit_velocity := 0.35
## A freshly split piece takes only this fraction of the usual knockback (1 = normal) until the next round
## starts (the rest of that turn, including the enemy's reply).
@export var fresh_knockback_multiplier := 0.5
## A newborn slime ignores hits for this long (ms), so pieces can't split each other at once.
@export var grace_ms := 500

var _created_ms := 0
var _split := false
var _fresh := true  # newborn: takes reduced knockback until the next round


func _init() -> void:
	_created_ms = Time.get_ticks_msec()


func get_knockback_multiplier(_figure: Figure, _source: Figure) -> float:
	return fresh_knockback_multiplier if _fresh else 1.0


func on_round_ticked(_figure: Figure) -> void:
	_fresh = false


func on_impact(figure: Figure, _other: Figure, speed: float, point: Vector2) -> void:
	if _split or piece == null or speed < split_speed:
		return
	if Time.get_ticks_msec() - _created_ms < grace_ms:
		return
	_split = true
	# Pieces burst away from the impact point, fanned out to either side.
	var away := (figure.global_position - point).normalized()
	if away.is_zero_approx():
		away = Vector2.UP
	var pieces: Array[Dictionary] = []
	for i in piece_count:
		var side := -1.0 + 2.0 * i / maxi(piece_count - 1, 1)  # -1 ... 1
		pieces.append({
			"data": piece,
			"position": figure.global_position + away.orthogonal() * side * piece.radius * 1.05,
			"velocity": away.rotated(deg_to_rad(burst_spread_degrees) * side) * burst_speed + figure.linear_velocity * inherit_velocity,
		})
	figure.split_into(pieces, true)
