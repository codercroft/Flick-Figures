class_name LandMinerAbility
extends FigureAbility
## Land Miner: whenever it MOVES (faster than `min_mine_speed`: its own flick, a hit, a push, Rally's nudge, an explosion,
## on either side's turn) it adds the distance it travels to a counter and drops a landmine every `mine_spacing` px of total
## travel (the first after that many px, not at the start; the counter keeps running between movements). A full-power flick
## travels about 1590 px, so 400 drops about 4. Mines are small markers that block nothing and stay for the rest of the combat
## (at most `max_mines` per Land Miner, the oldest goes first). No mine drops outside the table or within `min_mine_gap` px of
## another mine. An OPPOSING figure coming within a mine's trigger radius sets it off (see LandMine).

## Distance (px) traveled between mines.
@export var mine_spacing := 400.0
## Only movement faster than this (px/s) counts toward the next mine.
@export var min_mine_speed := 60.0
## No mine is dropped within this many px of an existing mine.
@export var min_mine_gap := 40.0
## Live mines per Land Miner; the oldest is removed when a new one would exceed it.
@export var max_mines := 12
## How close (center to center, px) an opposing figure must come to set a mine off.
@export var trigger_radius := 70.0
## The blast of one mine (a Bombo's is 200 / 900, a Sneaky Bomber's 270 / ?). Glow-in-the-dark scales the radius.
@export var explosion_radius := 180.0
@export var explosion_force := 1800.0
## Smart Bombs tier 3: mines drift toward MOVING opposing figures within this range (0 = they stay put), at up to
## `homing_speed` px/s.
@export var homing_range := 0.0
@export var homing_speed := 220.0

var _since_drop := 0.0
var _last_position := Vector2.INF
var _mines: Array = []  # (untyped: a mine that went off is freed, and a freed object can't pass through a typed filter)


func on_physics_process(figure: Figure, _delta: float) -> void:
	if figure.knocked_off or not figure.is_inside_tree():
		_last_position = Vector2.INF
		return
	var position := figure.global_position
	if _last_position == Vector2.INF:
		_last_position = position
	if figure.linear_velocity.length() >= min_mine_speed:
		_since_drop += position.distance_to(_last_position)  # (the counter keeps running between movements)
	_last_position = position
	while _since_drop >= mine_spacing:
		_since_drop -= mine_spacing
		maybe_drop(figure, position)


## Drops a mine at `at` unless it is outside the table or within `min_mine_gap` of another mine. Returns whether it did.
func maybe_drop(figure: Figure, at: Vector2) -> bool:
	var combat := RunManager.combat
	if combat != null and not combat.board.get_table_rect().has_point(at):
		return false
	for node in figure.get_tree().get_nodes_in_group("mines"):
		if node is LandMine and not node.is_queued_for_deletion() and node.global_position.distance_to(at) < min_mine_gap:
			return false
	_drop(figure, at)
	return true


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
