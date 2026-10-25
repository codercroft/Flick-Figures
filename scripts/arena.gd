class_name Arena
extends Node2D
## Builds and runs the current arena layout: solid walls and pins, and floor patches that slow,
## boost or turn figures that are moving across them.

@export_group("Walls and pins")
@export var wall_bounce := 0.8
@export var wall_color := Color(0.33, 0.25, 0.18)
@export var pin_bounce := 1.0
## Figures that touch a pin leave this much faster (on top of the bounce).
@export var pin_kick := 1.3
@export var pin_max_speed := 3000.0
@export var pin_color := Color(0.85, 0.75, 0.3)

@export_group("Floor patches")
## Slow patch: extra damping per second while on it (the normal damping is the Main node's figure_damping).
@export var slow_damping := 3.0
## Boost patch: push in px/s per second. It adds no more speed once a figure goes this fast.
@export var boost_acceleration := 470.0
@export var boost_max_speed := 2400.0
## Turn patch: how fast a moving figure's direction curves, in degrees per second.
@export var turn_rate_degrees := 110.0

var _data: ArenaData
var _origin := Vector2.ZERO
# Things placed by powers: bricks (temporary walls) and zones (magnet fields, glue puddles).
var _bricks: Array[Dictionary] = []  # {body, rounds}
var _zones: Array[Dictionary] = []  # {kind, center, radius, inner, pull, rounds, node, inside}


## Builds the layout. `board_rect` is the board in world space; layout positions are relative to it.
func build(data: ArenaData, board_rect: Rect2) -> void:
	_data = data
	_origin = board_rect.position
	for child in get_children():
		child.queue_free()
	if data != null:
		for warning in data.get_warnings(board_rect.size):
			push_warning("[arena %s] %s" % [data.display_name, warning])
		for wall in data.walls:
			_add_wall(wall)
		for pin in data.pins:
			_add_pin(pin)
	queue_redraw()


func _add_wall(wall: ArenaWall) -> void:
	var body := _make_static_body(wall_bounce)
	body.position = _origin + wall.position
	body.rotation_degrees = wall.rotation_degrees
	var rect := RectangleShape2D.new()
	rect.size = wall.size
	var shape := CollisionShape2D.new()
	shape.shape = rect
	body.add_child(shape)
	add_child(body)


func _add_pin(pin: ArenaPin) -> void:
	var body := _make_static_body(pin_bounce)
	body.position = _origin + pin.position
	var circle := CircleShape2D.new()
	circle.radius = pin.radius
	var shape := CollisionShape2D.new()
	shape.shape = circle
	body.add_child(shape)
	# A slightly bigger sensor ring so the pin can kick figures as they bounce off.
	var sensor := Area2D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = Figure.LAYER_ON_DECK | Figure.LAYER_FLICKED | Figure.LAYER_ENEMY
	var ring := CircleShape2D.new()
	ring.radius = pin.radius + 8.0
	var ring_shape := CollisionShape2D.new()
	ring_shape.shape = ring
	sensor.add_child(ring_shape)
	sensor.body_entered.connect(_on_pin_touched)
	body.add_child(sensor)
	add_child(body)


func _make_static_body(bounce: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = Figure.LAYER_ARENA
	body.collision_mask = 0
	var material := PhysicsMaterial.new()
	material.bounce = bounce
	material.friction = 0.0
	body.physics_material_override = material
	return body


func _on_pin_touched(body: Node) -> void:
	if body is Figure:
		_kick.call_deferred(body)  # deferred: don't change bodies inside a physics callback


func _kick(figure: Figure) -> void:
	if is_instance_valid(figure) and not figure.is_slow():
		figure.linear_velocity = (figure.linear_velocity * pin_kick).limit_length(pin_max_speed)


# --- Floor patches -----------------------------------------------------------

func _physics_process(delta: float) -> void:
	var figures := get_tree().get_nodes_in_group("figures")
	if _data != null and not _data.patches.is_empty():
		for node in figures:
			var figure := node as Figure
			# Resting figures are never touched, so patches can't keep anything moving forever.
			if figure.on_deck or figure.knocked_off or figure.is_slow():
				continue
			for patch in _data.patches:
				if _patch_rect(patch).has_point(figure.global_position):
					_apply_patch(patch, figure, delta)
	for zone in _zones:
		_apply_zone(zone, figures)


# --- Power-placed things -----------------------------------------------------

## A short temporary wall (Brick power). Returns false if a figure is in the way.
func add_brick(center: Vector2, size: Vector2, rounds: int) -> bool:
	var rect := Rect2(center - size / 2.0, size)
	for node in get_tree().get_nodes_in_group("figures"):
		var figure := node as Figure
		if not figure.knocked_off and rect.grow(figure.radius + 4.0).has_point(figure.global_position):
			return false
	var body := _make_static_body(wall_bounce)
	body.position = center
	var shape_rect := RectangleShape2D.new()
	shape_rect.size = size
	var shape := CollisionShape2D.new()
	shape.shape = shape_rect
	body.add_child(shape)
	var corners := PackedVector2Array([-size / 2.0, Vector2(size.x, -size.y) / 2.0, size / 2.0, Vector2(-size.x, size.y) / 2.0])
	var fill := Polygon2D.new()
	fill.polygon = corners
	fill.color = Color(0.7, 0.32, 0.22)
	body.add_child(fill)
	var outline := Line2D.new()
	outline.points = corners
	outline.closed = true
	outline.width = 5.0
	outline.default_color = Color(0.95, 0.6, 0.45)
	body.add_child(outline)
	add_child(body)
	_bricks.append({"body": body, "rounds": rounds})
	return true


## A magnet field that bends the path of moving figures (Magnet Throw power).
func add_magnet_zone(center: Vector2, radius: float, inner: float, pull: float, rounds: int) -> void:
	_add_zone(ZoneVisual.Kind.MAGNET, center, radius, rounds, {"inner": inner, "pull": pull})


## A puddle that stops any figure sliding into it (Glue Puddle power). rounds 0 = the whole combat.
func add_glue_puddle(center: Vector2, radius: float, rounds: int) -> void:
	_add_zone(ZoneVisual.Kind.PUDDLE, center, radius, rounds, {})


func _add_zone(kind: int, center: Vector2, radius: float, rounds: int, extra: Dictionary) -> void:
	var node := ZoneVisual.new()
	node.kind = kind
	node.radius = radius
	node.position = center
	node.z_index = -1
	add_child(node)
	var zone := {"kind": kind, "center": center, "radius": radius, "rounds": rounds, "node": node, "inside": {}}
	zone.merge(extra)
	_zones.append(zone)


## One round has passed: bricks and zones with a limited life count down and vanish.
func tick_round() -> void:
	for i in range(_bricks.size() - 1, -1, -1):
		_bricks[i].rounds -= 1
		if _bricks[i].rounds <= 0:
			_bricks[i].body.queue_free()
			_bricks.remove_at(i)
	for i in range(_zones.size() - 1, -1, -1):
		if _zones[i].rounds <= 0:
			continue  # lasts the whole combat
		_zones[i].rounds -= 1
		if _zones[i].rounds <= 0:
			_zones[i].node.queue_free()
			_zones.remove_at(i)


func _apply_zone(zone: Dictionary, figures: Array) -> void:
	for node in figures:
		var figure := node as Figure
		if figure.knocked_off:
			continue
		var offset: Vector2 = zone.center - figure.global_position
		var distance := offset.length()
		if zone.kind == ZoneVisual.Kind.MAGNET:
			if figure.is_slow() or distance < zone.inner or distance > zone.radius:
				continue
			var strength: float = (distance - zone.inner) / (zone.radius - zone.inner)
			figure.apply_central_force(offset.normalized() * zone.pull * strength * figure.mass)
		else:
			# Only stops figures as they ENTER, so a figure flicked from inside can still leave.
			var id := figure.get_instance_id()
			var inside: bool = distance <= zone.radius
			if inside and not zone.inside.get(id, false) and not figure.is_frozen():
				figure.linear_velocity = Vector2.ZERO
			zone.inside[id] = inside


func _patch_rect(patch: ArenaPatch) -> Rect2:
	return Rect2(_origin + patch.position - patch.size / 2.0, patch.size)


func _apply_patch(patch: ArenaPatch, figure: Figure, delta: float) -> void:
	match patch.kind:
		ArenaPatch.Kind.SLOW:
			figure.apply_central_force(-figure.linear_velocity * slow_damping * patch.strength * figure.mass)
		ArenaPatch.Kind.BOOST:
			var direction := Vector2.from_angle(deg_to_rad(patch.direction_degrees))
			if figure.linear_velocity.dot(direction) < boost_max_speed:
				figure.apply_central_force(direction * boost_acceleration * patch.strength * figure.mass)
		ArenaPatch.Kind.TURN:
			# On screen (y down) a positive angle turns clockwise = right.
			var sign := 1.0 if patch.turn == ArenaPatch.Turn.RIGHT else -1.0
			var angle := sign * deg_to_rad(turn_rate_degrees * patch.strength) * delta
			figure.linear_velocity = figure.linear_velocity.rotated(angle)


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	if _data == null:
		return
	for patch in _data.patches:
		_draw_patch(patch)
	for wall in _data.walls:
		draw_set_transform(_origin + wall.position, deg_to_rad(wall.rotation_degrees))
		draw_rect(Rect2(-wall.size / 2.0, wall.size), wall_color)
		draw_rect(Rect2(-wall.size / 2.0, wall.size), wall_color.lightened(0.35), false, 4.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for pin in _data.pins:
		var center := _origin + pin.position
		draw_circle(center, pin.radius, pin_color.darkened(0.35))
		draw_circle(center, pin.radius - 5.0, pin_color)
		draw_circle(center + Vector2(-0.3, -0.3) * pin.radius, pin.radius * 0.25, pin_color.lightened(0.5))


func _draw_patch(patch: ArenaPatch) -> void:
	var rect := _patch_rect(patch)
	match patch.kind:
		ArenaPatch.Kind.SLOW:
			draw_rect(rect, Color(0.3, 0.2, 0.1, 0.45))
			# Wavy mud lines.
			var line_color := Color(0.2, 0.12, 0.05, 0.7)
			var y := rect.position.y + 30.0
			while y < rect.end.y - 10.0:
				var points := PackedVector2Array()
				var x := rect.position.x + 12.0
				while x < rect.end.x - 12.0:
					points.append(Vector2(x, y + sin(x * 0.06) * 7.0))
					x += 10.0
				draw_polyline(points, line_color, 4.0, true)
				y += 44.0
		ArenaPatch.Kind.BOOST:
			draw_rect(rect, Color(0.2, 0.75, 0.35, 0.28))
			var direction := Vector2.from_angle(deg_to_rad(patch.direction_degrees))
			var side := direction.orthogonal()
			var arrow_color := Color(0.75, 1.0, 0.7, 0.9)
			var inner := rect.grow(-34.0)
			var cy := inner.position.y
			while cy <= inner.end.y:
				var cx := inner.position.x
				while cx <= inner.end.x:
					var c := Vector2(cx, cy)
					draw_polyline(PackedVector2Array([c - direction * 20.0 + side * 18.0, c + direction * 12.0, c - direction * 20.0 - side * 18.0]), arrow_color, 6.0, true)
					cx += 80.0
				cy += 80.0
		ArenaPatch.Kind.TURN:
			draw_rect(rect, Color(0.6, 0.3, 0.8, 0.26))
			var center := rect.get_center()
			var max_radius := minf(rect.size.x, rect.size.y) / 2.0 - 14.0
			var sign := 1.0 if patch.turn == ArenaPatch.Turn.RIGHT else -1.0
			var points := PackedVector2Array()
			for i in 41:
				var t := i / 40.0
				points.append(center + Vector2.from_angle(sign * t * TAU * 1.6) * (10.0 + t * (max_radius - 10.0)))
			var swirl_color := Color(0.9, 0.75, 1.0, 0.9)
			draw_polyline(points, swirl_color, 6.0, true)
			var tip: Vector2 = points[points.size() - 1]
			var heading := (tip - points[points.size() - 3]).normalized()
			draw_polyline(PackedVector2Array([tip - heading * 22.0 + heading.orthogonal() * 16.0, tip, tip - heading * 22.0 - heading.orthogonal() * 16.0]), swirl_color, 6.0, true)
