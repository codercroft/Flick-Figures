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
## Brood path: minis are this much bigger and heavier (x), and a mini splits once more (into 2 smaller ones).
@export var piece_size := 1.0
@export var minis_split_again := false
## Shrapnel path: minis hit with full knockback; the split makes a small explosion (force 0 = none).
@export var minis_full_knockback := false
@export var split_explosion_force := 0.0
@export var split_explosion_radius := 150.0

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
	var mini_data := piece
	if not is_equal_approx(piece_size, 1.0):
		mini_data = piece.duplicate() as FigureData
		mini_data.radius *= piece_size
		mini_data.mass *= piece_size
	var parent := self
	var on_spawn := func(spawned: Figure) -> void:
		if minis_full_knockback and "knockback_dealt" in spawned.ability:
			spawned.ability.knockback_dealt = 1.0
		if minis_split_again:  # this mini can split once more, into 2 smaller ones
			var again := parent.duplicate() as SplitterAbility
			again.piece = mini_data
			again.piece_count = 2
			again.piece_size = 0.8
			again.minis_split_again = false
			spawned._core_ability = again
			spawned._rebuild_ability()
	var pieces: Array[Dictionary] = []
	for i in piece_count:
		var side := -1.0 + 2.0 * i / maxi(piece_count - 1, 1)  # -1 ... 1
		pieces.append({
			"data": mini_data,
			"position": figure.global_position + away.orthogonal() * (i - (piece_count - 1) / 2.0) * mini_data.radius * 2.2,
			"velocity": away.rotated(deg_to_rad(burst_spread_degrees) * side) * burst_speed + figure.linear_velocity * inherit_velocity,
			"on_spawn": on_spawn,
		})
	if split_explosion_force > 0.0:
		figure.explode(split_explosion_radius, split_explosion_force)
	figure.split_into(pieces)
