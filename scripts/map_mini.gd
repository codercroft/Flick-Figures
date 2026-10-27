class_name MapMini
extends Control
## A small copy of the current act's map for the run info overlay: your position, what you have done
## and what you can reach next. Tap a stop to read what it is.

signal node_picked(node: MapNode)

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _center(node: MapNode) -> Vector2:
	var map := RunManager.map
	var radius := _radius(node)
	var y := lerpf(size.y - radius - 14.0, radius + 14.0, float(node.column) / map.columns)
	var x := size.x * 0.5
	if node.type != MapNode.Type.BOSS:
		x = lerpf(size.x * 0.14, size.x * 0.86, float(node.lane) / maxf(map.lanes - 1, 1))
	return Vector2(x, y)


func _radius(node: MapNode) -> float:
	return minf(size.x, size.y) * (0.06 if node.type == MapNode.Type.BOSS else 0.042)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var best: MapNode = null
		var best_distance := INF
		for node in RunManager.map.nodes:
			var distance: float = event.position.distance_to(_center(node))
			if distance <= _radius(node) + 22.0 and distance < best_distance:
				best = node
				best_distance = distance
		if best != null:
			node_picked.emit(best)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var map := RunManager.map
	var reachable := RunManager.reachable_nodes()
	for node in map.nodes:
		for id in node.next:
			var open := reachable.has(id) and node.id == RunManager.current_node
			var color := Color(1.0, 0.85, 0.3, 0.8) if open else (Color(0.3, 0.5, 0.36) if node.visited and map.nodes[id].visited else Color(0.33, 0.36, 0.45))
			draw_line(_center(node), _center(map.nodes[id]), color, 3.0, true)
	for node in map.nodes:
		var c := _center(node)
		var r := _radius(node)
		var base := MapIcons.color_for(node.type, RunManager.boss.map_color)
		var is_reachable := reachable.has(node.id)
		draw_circle(c, r, Color(0.3, 0.5, 0.36) if node.visited else (base if is_reachable else base.darkened(0.55)))
		if is_reachable:
			draw_arc(c, r + 3.0 + 2.0 * sin(_time * 4.0 + node.id), 0.0, TAU, 28, Color(1.0, 0.85, 0.3), 3.0, true)
		if node.id == RunManager.current_node:
			draw_arc(c, r + 4.0, 0.0, TAU, 28, Color.WHITE, 3.0, true)
		MapIcons.draw(self, font, node.type, c, r, Color(0.92, 0.94, 1.0), RunManager.boss.map_label, RunManager.boss.map_icon)
	# "You are here": a marker at the start of the act, or the ringed node.
	if RunManager.current_node == -1:
		draw_string(font, Vector2(8.0, size.y - 6.0), "Start of the act", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.7, 0.75, 0.85))
