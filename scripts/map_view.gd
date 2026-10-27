class_name MapView
extends Control
## Draws the act map (nodes, paths, icons) and reports taps on the stops you can go to. It sits inside
## a ScrollContainer: it is as tall as the map needs (comfortable spacing between the rows), so on a
## small screen the map scrolls, and on a tall phone it simply fills the screen.

signal node_tapped(id: int)

const NODE_RADIUS := 38.0
const BOSS_RADIUS := 56.0
## Extra px around a node that still counts as tapping it.
const TAP_PADDING := 26.0
## Fewest px between two rows of nodes before the map starts to scroll.
const MIN_ROW_SPACING := 150.0
const EDGE_PADDING := 100.0
## A press that moves further than this (px) is a scroll, not a tap.
const TAP_SLOP := 24.0

@export var done_color := Color(0.3, 0.5, 0.36)
@export var reachable_ring := Color(1.0, 0.85, 0.3)
@export var line_color := Color(0.33, 0.36, 0.45)
@export var text_color := Color(0.9, 0.92, 0.97)
@export var dim_text_color := Color(0.6, 0.63, 0.72)

var _time := 0.0
var _press_position := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS  # let the ScrollContainer see drags


## The height the map wants, given the height of the area it lives in.
func required_height(available: float) -> float:
	var rows := RunManager.map.columns + 1
	return maxf(available, MIN_ROW_SPACING * rows + EDGE_PADDING * 2.0)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()  # the reachable nodes pulse


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_position = event.position
		elif event.position.distance_to(_press_position) < TAP_SLOP:
			for id in RunManager.reachable_nodes():
				var node := RunManager.map.nodes[id]
				if event.position.distance_to(node_center(node)) <= _node_radius(node) + TAP_PADDING:
					node_tapped.emit(id)
					return


func _node_radius(node: MapNode) -> float:
	return BOSS_RADIUS if node.type == MapNode.Type.BOSS else NODE_RADIUS


## Where a node is drawn: the first column near the bottom, the boss at the top, lanes across.
func node_center(node: MapNode) -> Vector2:
	var map := RunManager.map
	var y := lerpf(size.y - EDGE_PADDING, EDGE_PADDING, float(node.column) / map.columns)
	var x := size.x * 0.5
	if node.type != MapNode.Type.BOSS:
		x = lerpf(170.0, size.x - 170.0, float(node.lane) / maxf(map.lanes - 1, 1))
	return Vector2(x, y)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var map := RunManager.map
	var reachable := RunManager.reachable_nodes()
	# Paths first, so the nodes sit on top of them.
	for node in map.nodes:
		for id in node.next:
			var target := map.nodes[id]
			var open := reachable.has(id) and node.id == RunManager.current_node
			var color := reachable_ring.darkened(0.2) if open else (done_color if node.visited and target.visited else line_color)
			draw_line(node_center(node), node_center(target), color, 7.0 if open else 4.0, true)
	if RunManager.current_node == -1:
		for id in reachable:
			var start := node_center(map.nodes[id])
			draw_line(start + Vector2(0.0, 80.0), start, reachable_ring.darkened(0.2), 6.0, true)
	for node in map.nodes:
		_draw_node(font, node, reachable.has(node.id))
	var boss_node := map.boss()
	draw_string(font, node_center(boss_node) + Vector2(BOSS_RADIUS + 18.0, 14.0), "Boss: %s" % RunManager.boss.display_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 34, dim_text_color)


func _draw_node(font: Font, node: MapNode, is_reachable: bool) -> void:
	var center := node_center(node)
	var radius := _node_radius(node)
	var base := MapIcons.color_for(node.type, RunManager.boss.map_color)
	var fill := base.darkened(0.6)
	if node.visited:
		fill = done_color
	elif is_reachable:
		fill = base
	draw_circle(center, radius, fill)
	if is_reachable:
		var pulse := 6.0 + 4.0 * sin(_time * 4.0 + node.id)
		draw_arc(center, radius + pulse, 0.0, TAU, 40, reachable_ring, 6.0, true)
	if node.id == RunManager.current_node:
		draw_arc(center, radius + 6.0, 0.0, TAU, 40, Color.WHITE, 5.0, true)
	var ink := text_color if (is_reachable or node.visited) else dim_text_color
	MapIcons.draw(self, font, node.type, center, radius, ink, RunManager.boss.map_label, RunManager.boss.map_icon)
	if node.visited:
		draw_polyline(PackedVector2Array([center + Vector2(-12, 26), center + Vector2(-3, 36), center + Vector2(16, 14)]), Color.WHITE, 6.0, true)
