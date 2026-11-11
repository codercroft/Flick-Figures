class_name LandMinerAbility
extends FigureAbility
## Land Miner: while it moves from its OWN flick it drops a landmine every `mine_spacing` px of distance traveled (the
## first one after that many px, not at the start). A full-power flick travels about 1600 px, so 700 drops about 2.
## Mines are small markers that block nothing and stay for the rest of the combat (at most `max_mines` per Land
## Miner, the oldest goes first). An OPPOSING figure coming within a mine's trigger radius sets it off (see LandMine).

## Distance (px) traveled between mines.
@export var mine_spacing := 700.0
## Live mines per Land Miner; the oldest is removed when a new one would exceed it.
@export var max_mines := 8
## How close (center to center, px) an opposing figure must come to set a mine off.
@export var trigger_radius := 70.0
## The blast of one mine (a Bombo's is 200 / 900). Glow-in-the-dark scales the radius.
@export var explosion_radius := 140.0
@export var explosion_force := 600.0
## Smart Bombs tier 3: mines drift toward MOVING opposing figures within this range (0 = they stay put), at up to
## `homing_speed` px/s.
@export var homing_range := 0.0
@export var homing_speed := 220.0

var _flicking := false
var _since_drop := 0.0
var _last_position := Vector2.INF
var _mines: Array = []  # (untyped: a mine that went off is freed, and a freed object can't pass through a typed filter)


func on_flicked(figure: Figure, _impulse: Vector2) -> void:
	_flicking = true
	_since_drop = 0.0
	_last_position = figure.global_position


func on_stopped(_figure: Figure) -> void:
	_flicking = false


func on_physics_process(figure: Figure, _delta: float) -> void:
	if not _flicking or figure.knocked_off or not figure.is_inside_tree() or figure.on_deck:
		return
	var position := figure.global_position
	if _last_position == Vector2.INF:
		_last_position = position
	_since_drop += position.distance_to(_last_position)
	_last_position = position
	while _since_drop >= mine_spacing:
		_since_drop -= mine_spacing
		_drop(figure, position)


func _drop(figure: Figure, at: Vector2) -> void:
	var combat := RunManager.combat
	var parent: Node = combat.arena if combat != null else figure.get_parent()
	if parent == null:
		return
	_mines = _mines.filter(func(m) -> bool: return is_instance_valid(m))
	while _mines.size() >= maxi(max_mines, 1):
		_mines.pop_front().queue_free()  # the oldest goes first
	var mine := LandMine.new()
	mine.team = figure.team
	mine.owner_figure = figure
	mine.trigger_radius = trigger_radius
	mine.explosion_radius = explosion_radius
	mine.explosion_force = explosion_force
	mine.homing_range = homing_range
	mine.homing_speed = homing_speed
	parent.add_child(mine)
	mine.global_position = at
	_mines.append(mine)


## Enemy AI: the numbers it plans mine laying with.
func get_mine_stats(_figure: Figure) -> Dictionary:
	return {"spacing": mine_spacing, "trigger_radius": trigger_radius, "radius": explosion_radius, "force": explosion_force}
