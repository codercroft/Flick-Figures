extends Control
## The act map, shown between stops: a Slay-the-Spire style branching map. You start at the bottom,
## pick one of the glowing next stops (2-3 choices per step), and every path ends at the boss on top.
## Node types: combat, elite (tougher, optional), shop, treasure. Placeholder icons. Everything is in
## the bottom half of the screen.

const COMBAT_SCENE := "res://scenes/main.tscn"
const SHOP_SCENE := "res://scenes/shop.tscn"
const REWARD_SCENE := "res://scenes/reward.tscn"
const EQUIP_SCENE := "res://scenes/equip.tscn"
const UPGRADE_SCENE := "res://scenes/upgrade.tscn"
const NODE_RADIUS := 30.0
const BOSS_RADIUS := 46.0
## Extra px around a node that still counts as tapping it.
const TAP_PADDING := 24.0

@export var done_color := Color(0.3, 0.5, 0.36)
@export var future_color := Color(0.22, 0.24, 0.3)
@export var reachable_ring := Color(1.0, 0.85, 0.3)
@export var line_color := Color(0.33, 0.36, 0.45)
@export var text_color := Color(0.9, 0.92, 0.97)
@export var dim_text_color := Color(0.6, 0.63, 0.72)
@export var money_color := Color(1.0, 0.82, 0.25)
@export var combat_color := Color(0.75, 0.3, 0.3)
@export var elite_color := Color(0.9, 0.45, 0.1)
@export var shop_color := Color(0.85, 0.7, 0.15)
@export var treasure_color := Color(0.6, 0.4, 0.2)

var _time := 0.0


func _ready() -> void:
	# The relic icons sit in a row at the top of the map (the bottom half of the screen).
	var relics := RelicBar.new()
	relics.anchor_right = 1.0
	relics.anchor_top = 0.5
	relics.anchor_bottom = 0.5
	relics.offset_left = 24.0
	relics.offset_right = -24.0
	relics.offset_top = 8.0
	relics.offset_bottom = 64.0
	relics.name = "RelicBar"
	add_child(relics)
	# Buttons for the equip and upgrade screens, along the bottom.
	var held := RunManager.equipment_inventory.size()
	var equipment := _bottom_button("Equipment (%d)" % held, false, EQUIP_SCENE)
	if held > 0:
		equipment.add_theme_color_override("font_color", money_color)
	if RunManager.config.show_upgrade_screen:
		_bottom_button("Upgrades", true, UPGRADE_SCENE)


func _bottom_button(text: String, on_left: bool, scene: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 34)
	button.anchor_left = 0.0 if on_left else 1.0
	button.anchor_right = 0.0 if on_left else 1.0
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = 24.0 if on_left else -324.0
	button.offset_right = 324.0 if on_left else -24.0
	button.offset_top = -190.0
	button.offset_bottom = -110.0
	button.pressed.connect(func(): get_tree().change_scene_to_file(scene))
	add_child(button)
	return button


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()  # the reachable nodes pulse


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for id in RunManager.reachable_nodes():
			var node := RunManager.map.nodes[id]
			if event.position.distance_to(_node_center(node)) <= _node_radius(node) + TAP_PADDING:
				_go_to(id)
				return


func _go_to(id: int) -> void:
	if not RunManager.enter_node(id):
		return
	match RunManager.node.type:
		MapNode.Type.SHOP:
			get_tree().change_scene_to_file(SHOP_SCENE)
		MapNode.Type.TREASURE:
			get_tree().change_scene_to_file(REWARD_SCENE)
		_:
			get_tree().change_scene_to_file(COMBAT_SCENE)


func _node_radius(node: MapNode) -> float:
	return BOSS_RADIUS if node.type == MapNode.Type.BOSS else NODE_RADIUS


## The map fills the bottom half: the first column near the bottom, the boss at the top.
func _node_center(node: MapNode) -> Vector2:
	var map := RunManager.map
	var top := size.y * 0.5 + 175.0
	var bottom := size.y - 230.0
	var y := lerpf(bottom, top, float(node.column) / map.columns)
	var x := size.x * 0.5
	if node.type != MapNode.Type.BOSS:
		x = lerpf(150.0, size.x - 150.0, float(node.lane) / maxf(map.lanes - 1, 1))
	return Vector2(x, y)


func _type_color(node_type: MapNode.Type) -> Color:
	match node_type:
		MapNode.Type.ELITE:
			return elite_color
		MapNode.Type.SHOP:
			return shop_color
		MapNode.Type.TREASURE:
			return treasure_color
		MapNode.Type.BOSS:
			return RunManager.boss.map_color
	return combat_color


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var map := RunManager.map
	draw_string(font, Vector2(0.0, size.y * 0.5 + 100.0), "Act %d of %d" % [RunManager.act + 1, RunManager.config.acts],
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 44, dim_text_color)
	draw_string(font, Vector2(0.0, size.y * 0.5 + 100.0), "$%d" % RunManager.money, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 40.0, 52, money_color)
	var reachable := RunManager.reachable_nodes()
	# Paths first, so the nodes sit on top of them.
	for node in map.nodes:
		for id in node.next:
			var target := map.nodes[id]
			var open := reachable.has(id) and node.id == RunManager.current_node
			var color := reachable_ring.darkened(0.2) if open else (done_color if node.visited and target.visited else line_color)
			draw_line(_node_center(node), _node_center(target), color, 6.0 if open else 4.0, true)
	if RunManager.current_node == -1:
		for id in reachable:
			var start := _node_center(map.nodes[id])
			draw_line(start + Vector2(0.0, 60.0), start, reachable_ring.darkened(0.2), 5.0, true)
	for node in map.nodes:
		_draw_node(font, node, reachable.has(node.id))
	var boss_node := map.boss()
	draw_string(font, _node_center(boss_node) + Vector2(BOSS_RADIUS + 16.0, 14.0), "Boss: %s" % RunManager.boss.display_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 34, dim_text_color)
	draw_string(font, Vector2(0.0, size.y - 40.0), "Choose your next stop", HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, dim_text_color)


func _draw_node(font: Font, node: MapNode, is_reachable: bool) -> void:
	var center := _node_center(node)
	var radius := _node_radius(node)
	var base := _type_color(node.type)
	var fill := future_color
	if node.visited:
		fill = done_color
	elif is_reachable:
		fill = base
	else:
		fill = base.darkened(0.6)
	draw_circle(center, radius, fill)
	if is_reachable:
		var pulse := 5.0 + 3.0 * sin(_time * 4.0 + node.id)
		draw_arc(center, radius + pulse, 0.0, TAU, 40, reachable_ring, 5.0, true)
	if node.id == RunManager.current_node:
		draw_arc(center, radius + 5.0, 0.0, TAU, 40, Color.WHITE, 4.0, true)
	var ink := text_color if (is_reachable or node.visited) else dim_text_color
	_draw_icon(font, node.type, center, radius, ink)
	if node.visited:
		draw_polyline(PackedVector2Array([center + Vector2(-10, 22), center + Vector2(-2, 30), center + Vector2(14, 12)]), Color.WHITE, 5.0, true)


## Placeholder pictures: swords for combat, a star for elite, $ for shop, a chest for treasure.
func _draw_icon(font: Font, node_type: MapNode.Type, c: Vector2, r: float, ink: Color) -> void:
	match node_type:
		MapNode.Type.COMBAT:
			draw_line(c + Vector2(-r, -r) * 0.5, c + Vector2(r, r) * 0.5, ink, 5.0, true)
			draw_line(c + Vector2(r, -r) * 0.5, c + Vector2(-r, r) * 0.5, ink, 5.0, true)
		MapNode.Type.ELITE:
			var points := PackedVector2Array()
			for i in 10:
				var length := r * (0.7 if i % 2 == 0 else 0.32)
				points.append(c + Vector2.from_angle(-PI / 2.0 + TAU * i / 10.0) * length)
			draw_colored_polygon(points, ink)
		MapNode.Type.SHOP:
			draw_string(font, c + Vector2(-r, r * 0.38), "$", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(r * 1.3), ink)
		MapNode.Type.TREASURE:
			draw_rect(Rect2(c + Vector2(-r * 0.55, -r * 0.1), Vector2(r * 1.1, r * 0.65)), ink, false, 4.0)
			draw_arc(c + Vector2(0.0, -r * 0.1), r * 0.55, PI, TAU, 12, ink, 4.0, true)
			draw_circle(c + Vector2(0.0, r * 0.2), 4.0, ink)
		MapNode.Type.BOSS:
			draw_string(font, c + Vector2(-r, r * 0.3), RunManager.boss.map_label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(r * 0.9), ink)
