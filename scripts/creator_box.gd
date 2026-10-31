class_name CreatorBox
extends Node2D
## The Mad Creator's box at the top of the table: four BreakableWalls around a floor with four colored spaces
## (one per summonable figure). It builds itself, puts the Creator inside, and answers the questions main.gd asks:
## is the Creator still inside, which space is it on, where can a summoned figure appear in front of the box.

## The box's outer size, the wall thickness and its distance from the top of the board (px).
@export var box_size := 480.0
@export var wall_thickness := 30.0
@export var top_margin := 30.0
## Gap between the floor spaces (px).
@export var tile_gap := 20.0
## How far the Creator's summon flick takes it (px, random in this range).
@export var min_travel := 150.0
@export var max_travel := 520.0

var creator: Figure
var summons: Array[FigureData] = []
var walls: Array[BreakableWall] = []
var _outer := Rect2()
var _inner := Rect2()
var _tile_size := 0.0


## Builds the walls and the floor and puts `creator_figure` in the middle. `boss` supplies the summons, the wall health
## and the summon cap.
func build(board_rect: Rect2, boss: BossData, creator_figure: Figure) -> void:
	creator = creator_figure
	summons = boss.summons
	var origin := Vector2(board_rect.position.x + (board_rect.size.x - box_size) / 2.0, board_rect.position.y + top_margin)
	_outer = Rect2(origin, Vector2(box_size, box_size))
	_inner = _outer.grow(-wall_thickness)
	_tile_size = (_inner.size.x - tile_gap) / 2.0 - 10.0
	var inner_height := box_size - wall_thickness * 2.0
	for spec in [
		[Vector2(box_size / 2.0, wall_thickness / 2.0), Vector2(box_size, wall_thickness)],  # top
		[Vector2(box_size / 2.0, box_size - wall_thickness / 2.0), Vector2(box_size, wall_thickness)],  # bottom
		[Vector2(wall_thickness / 2.0, box_size / 2.0), Vector2(wall_thickness, inner_height)],  # left
		[Vector2(box_size - wall_thickness / 2.0, box_size / 2.0), Vector2(wall_thickness, inner_height)],  # right
	]:
		var wall := BreakableWall.new()
		wall.setup(spec[1], boss.box_wall_health)
		wall.position = origin + spec[0]
		add_child(wall)
		walls.append(wall)
	if is_instance_valid(creator):
		creator.global_position = _inner.get_center()
		creator.linear_velocity = Vector2.ZERO
	queue_redraw()


## True while the Creator's center is inside the box (it can only leave through a broken wall).
func creator_inside() -> bool:
	return is_instance_valid(creator) and not creator.knocked_off and _outer.has_point(creator.global_position)


func intact_wall_count() -> int:
	var count := 0
	for wall in walls:
		if is_instance_valid(wall) and not wall.is_broken:
			count += 1
	return count


## Index (0-3) of the floor space under `point`; between spaces, the nearest one.
func tile_index_at(point: Vector2) -> int:
	var best := 0
	var best_distance := INF
	for i in 4:
		var distance := _tile_center(i).distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = i
	return best


## What the space under the Creator summons (null if the box has no such space).
func summon_for(point: Vector2) -> FigureData:
	var index := tile_index_at(point)
	return summons[index] if index < summons.size() else null


## A free spot in front of the box (below it) for a summoned figure, or Vector2.INF if there is no room.
## `others` are the figures already on the table.
func free_spot_in_front(board_rect: Rect2, new_radius: float, others: Array) -> Vector2:
	var spots: Array[Vector2] = []
	for row in 2:
		var y := _outer.end.y + 110.0 + 130.0 * row
		var x := board_rect.position.x + 110.0
		while x <= board_rect.end.x - 110.0:
			spots.append(Vector2(x, y))
			x += 140.0
	spots.shuffle()
	for spot in spots:
		var free := true
		for other in others:
			if is_instance_valid(other) and not other.knocked_off \
					and other.global_position.distance_to(spot) < other.radius + new_radius + 20.0:
				free = false
				break
		if free:
			return spot
	return Vector2.INF


func _tile_center(index: int) -> Vector2:
	var column := index % 2
	var row := index / 2
	var step := _tile_size + tile_gap
	var first := _inner.get_center() - Vector2(step, step) / 2.0
	return first + Vector2(column, row) * step


func _draw() -> void:
	draw_rect(_inner, Color(0.12, 0.1, 0.16))
	var font := ThemeDB.fallback_font
	for i in 4:
		if i >= summons.size():
			continue
		var center := _tile_center(i)
		var rect := Rect2(center - Vector2(_tile_size, _tile_size) / 2.0, Vector2(_tile_size, _tile_size))
		draw_rect(rect, Color(summons[i].color, 0.55))
		draw_rect(rect, summons[i].color.lightened(0.3), false, 4.0)
		draw_string(font, center + Vector2(-_tile_size / 2.0, 12.0), summons[i].display_name,
				HORIZONTAL_ALIGNMENT_CENTER, _tile_size, 30, Color(1, 1, 1, 0.9))
