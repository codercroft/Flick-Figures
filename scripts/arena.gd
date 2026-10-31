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

@export_group("Temporary pins")
@export var temp_pin_color := Color(0.75, 0.85, 0.95)

var _data: ArenaData
var _origin := Vector2.ZERO
# Things placed by powers: bricks (temporary walls) and zones (magnet fields, glue puddles).
var _bricks: Array[Dictionary] = []  # {body, rounds}
var _zones: Array[Dictionary] = []  # {kind, center, radius, inner, pull, rounds, node, inside}
var _temp_pins: Array[TempPin] = []  # Pinhead's pins
var _shield_walls: Array[ShieldWall] = []  # Shieldon Ooper's walls
var _starter_walls: Array[ShieldWall] = []  # the Starter Walls relic's walls (one enemy turn)
var _alchemy_zones: Array[AlchemyZone] = []  # Alchemist's debuff zones (the power-placed _zones below are different)
var _turrets: Array[Turret] = []  # Engineer's turrets
var _trail: Array[Dictionary] = []  # Juicer's boost pieces: {owner, ability, center, direction, rounds, node}


## Builds the layout. `board_rect` is the board in world space; layout positions are relative to it.
func build(data: ArenaData, board_rect: Rect2, back_wall := false) -> void:
	if back_wall and data != null:
		# A private copy of the layout with one more wall along the whole top edge (BossData.back_wall).
		data = data.duplicate()
		data.walls = data.walls.duplicate()
		var wall := ArenaWall.new()
		wall.position = Vector2(board_rect.size.x / 2.0, 18.0)
		wall.size = Vector2(board_rect.size.x, 36.0)
		data.walls.append(wall)
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
	body.add_to_group("pins")  # (Skull-o-tron's arms break when jammed against a pin)
	body.position = _origin + pin.position
	_add_pin_shapes(body, pin.radius)
	add_child(body)


## The solid circle of a pin plus a slightly bigger sensor ring so the pin can kick figures as they
## bounce off.
func _add_pin_shapes(body: StaticBody2D, radius: float) -> void:
	var circle := CircleShape2D.new()
	circle.radius = radius
	var shape := CollisionShape2D.new()
	shape.shape = circle
	body.add_child(shape)
	var sensor := Area2D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = Figure.LAYER_ON_DECK | Figure.LAYER_FLICKED | Figure.LAYER_ENEMY
	var ring := CircleShape2D.new()
	ring.radius = radius + 8.0
	var ring_shape := CollisionShape2D.new()
	ring_shape.shape = ring
	sensor.add_child(ring_shape)
	sensor.body_entered.connect(_on_pin_touched)
	body.add_child(sensor)


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
	if not _alchemy_zones.is_empty():
		_douse_figures_in_zones(figures)
	for piece in _trail:
		_apply_trail_piece(piece, figures)


# --- Prediction for the enemy AI -----------------------------------------------

## True if anything on the floor changes a moving figure's path (patches, Juicer trail, magnet zones).
func has_floor_effects() -> bool:
	return (_data != null and not _data.patches.is_empty()) or not _trail.is_empty() or _has_magnet_zone()


func _has_magnet_zone() -> bool:
	for zone in _zones:
		if zone.kind == ZoneVisual.Kind.MAGNET:
			return true
	return false


## True if the floor can curve a path (turn patches, magnet zones), so wide-angle shots are worth trying.
func has_bending_floor() -> bool:
	if _has_magnet_zone():
		return true
	if _data != null:
		for patch in _data.patches:
			if patch.kind == ArenaPatch.Kind.TURN:
				return true
	return false


## True if anything on the floor is within `margin` px of the segment a-b (so a figure sliding along it
## could be pushed or bent). Used by the enemy AI to skip the stepped simulation when nothing is near.
func floor_near_segment(a: Vector2, b: Vector2, margin: float) -> bool:
	if _data != null:
		var samples := maxi(int(a.distance_to(b) / 50.0), 1)
		for patch in _data.patches:
			var rect := _patch_rect(patch).grow(margin)
			for i in samples + 1:
				if rect.has_point(a.lerp(b, float(i) / samples)):
					return true
	for piece in _trail:
		var ability: JuicerAbility = piece.ability
		var closest := Geometry2D.get_closest_point_to_segment(piece.center, a, b)
		if closest.distance_to(piece.center) <= ability.segment_radius + margin:
			return true
	for zone in _zones:
		if zone.kind == ZoneVisual.Kind.MAGNET:
			var closest := Geometry2D.get_closest_point_to_segment(zone.center, a, b)
			if closest.distance_to(zone.center) <= zone.radius:
				return true
	return false


## The velocity a MOVING figure at `pos` with `velocity` has `delta` seconds later because of the floor
## (the same maths as the real patches, trail pieces and magnet zones; damping is not included).
func predict_floor_velocity(pos: Vector2, velocity: Vector2, delta: float) -> Vector2:
	if _data != null:
		for patch in _data.patches:
			if not _patch_rect(patch).has_point(pos):
				continue
			match patch.kind:
				ArenaPatch.Kind.SLOW:
					velocity -= velocity * slow_damping * patch.strength * delta
				ArenaPatch.Kind.BOOST:
					var direction := Vector2.from_angle(deg_to_rad(patch.direction_degrees))
					if velocity.dot(direction) < boost_max_speed:
						velocity += direction * boost_acceleration * patch.strength * delta
				ArenaPatch.Kind.TURN:
					var sign := 1.0 if patch.turn == ArenaPatch.Turn.RIGHT else -1.0
					velocity = velocity.rotated(sign * deg_to_rad(turn_rate_degrees * patch.strength) * delta)
	for piece in _trail:
		var ability: JuicerAbility = piece.ability
		if pos.distance_to(piece.center) <= ability.segment_radius and velocity.dot(piece.direction) < ability.boost_max_speed:
			velocity += piece.direction * ability.boost_acceleration * delta
	for zone in _zones:
		if zone.kind != ZoneVisual.Kind.MAGNET:
			continue
		var offset: Vector2 = zone.center - pos
		var distance := offset.length()
		if distance >= zone.inner and distance <= zone.radius:
			var strength: float = (distance - zone.inner) / (zone.radius - zone.inner)
			velocity += offset.normalized() * zone.pull * RunManager.relic_pull_multiplier() * strength * delta
	return velocity


# --- Pinhead's temporary pins ------------------------------------------------------

## True if a pin of `radius` fits at `pos`: inside the board and not touching a figure, wall, pin or brick.
static func is_spot_free(space: PhysicsDirectSpaceState2D, board: Rect2, pos: Vector2, radius: float) -> bool:
	if not board.grow(-radius).has_point(pos):
		return false
	var circle := CircleShape2D.new()
	circle.radius = radius + 6.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, pos)
	query.collision_mask = Figure.LAYER_ON_DECK | Figure.LAYER_FLICKED | Figure.LAYER_ENEMY | Figure.LAYER_ARENA
	return space.intersect_shape(query, 1).is_empty()


## Tap with Pinhead selected: places its pin at `pos` (a second pin of the same Pinhead is moved),
## or takes the pin back if `pos` is on it. Returns "placed", "removed" or "blocked".
func toggle_temp_pin(owner_figure: Figure, pos: Vector2, radius: float, board: Rect2) -> String:
	for pin in _temp_pins:
		if pin.owner_figure == owner_figure and pin.position.distance_to(pos) <= pin.radius + 10.0:
			remove_temp_pins(owner_figure)
			return "removed"
	var old_spot := Vector2.INF
	for pin in _temp_pins:
		if pin.owner_figure == owner_figure:
			old_spot = pin.position
	remove_temp_pins(owner_figure)
	if not place_temp_pin(owner_figure, pos, radius, board):
		if old_spot != Vector2.INF:  # blocked: the old pin stays where it was
			place_temp_pin(owner_figure, old_spot, radius, board)
		return "blocked"
	return "placed"


## Places a temporary pin if the spot is free. Returns whether it was placed.
func place_temp_pin(owner_figure: Figure, pos: Vector2, radius: float, board: Rect2) -> bool:
	remove_temp_pins(owner_figure)  # a new pin replaces the old one
	if not is_spot_free(get_world_2d().direct_space_state, board, pos, radius):
		return false
	var pin := TempPin.new()
	pin.radius = radius
	pin.color = temp_pin_color
	pin.owner_figure = owner_figure
	pin.collision_layer = Figure.LAYER_ARENA
	pin.collision_mask = 0
	var material := PhysicsMaterial.new()
	material.bounce = pin_bounce
	material.friction = 0.0
	pin.physics_material_override = material
	pin.position = pos
	pin.add_to_group("pins")
	_add_pin_shapes(pin, radius)
	add_child(pin)
	_temp_pins.append(pin)
	return true


## Removes the temporary pins of one Pinhead (or all of them if `owner_figure` is null).
func remove_temp_pins(owner_figure: Figure = null) -> void:
	for i in range(_temp_pins.size() - 1, -1, -1):
		var pin := _temp_pins[i]
		if owner_figure == null or pin.owner_figure == owner_figure or not is_instance_valid(pin.owner_figure):
			remove_child(pin)  # out of the physics space right away (queue_free alone waits a frame)
			pin.queue_free()
			_temp_pins.remove_at(i)


## Removes every temporary pin (and Alchemist zone) that belongs to a figure of `team` (that side's flick cycle reset).
func remove_team_pins(team: int) -> void:
	for i in range(_alchemy_zones.size() - 1, -1, -1):
		var zone := _alchemy_zones[i]
		if not is_instance_valid(zone) or not is_instance_valid(zone.owner_figure) or zone.owner_figure.team == team:
			if is_instance_valid(zone):
				remove_child(zone)
				zone.queue_free()
			_alchemy_zones.remove_at(i)
	for i in range(_temp_pins.size() - 1, -1, -1):
		var pin := _temp_pins[i]
		if not is_instance_valid(pin.owner_figure) or pin.owner_figure.team == team:
			remove_child(pin)
			pin.queue_free()
			_temp_pins.remove_at(i)


## Removes pins whose Pinhead is gone (knocked off), and zones and walls whose owner is gone.
func prune_temp_pins() -> void:
	for i in range(_alchemy_zones.size() - 1, -1, -1):
		if not is_instance_valid(_alchemy_zones[i]) or not is_instance_valid(_alchemy_zones[i].owner_figure) or _alchemy_zones[i].owner_figure.knocked_off:
			if is_instance_valid(_alchemy_zones[i]):
				remove_child(_alchemy_zones[i])
				_alchemy_zones[i].queue_free()
			_alchemy_zones.remove_at(i)
	for i in range(_shield_walls.size() - 1, -1, -1):
		if not is_instance_valid(_shield_walls[i]) or not is_instance_valid(_shield_walls[i].owner_figure) \
				or _shield_walls[i].owner_figure.knocked_off:
			if is_instance_valid(_shield_walls[i]):
				remove_child(_shield_walls[i])
				_shield_walls[i].queue_free()
			_shield_walls.remove_at(i)
	for i in range(_temp_pins.size() - 1, -1, -1):
		var pin := _temp_pins[i]
		if not is_instance_valid(pin.owner_figure) or pin.owner_figure.knocked_off:
			remove_child(pin)
			pin.queue_free()
			_temp_pins.remove_at(i)


## The temporary pins placed by figures of `team`: [{position, radius}] (for the enemy AI's bank shots).
func temp_pins_of(team: int) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for pin in _temp_pins:
		if is_instance_valid(pin) and is_instance_valid(pin.owner_figure) and pin.owner_figure.team == team:
			list.append({"position": pin.position, "radius": pin.radius})
	return list


func has_temp_pin(owner_figure: Figure) -> bool:
	for pin in _temp_pins:
		if pin.owner_figure == owner_figure:
			return true
	return false


# --- Shieldon Ooper's walls and the Alchemist's zones -----------------------------------

## Props up a wall for `owner_figure` (replacing its old one). Fails (false) if a figure is in the way.
func place_shield_wall(owner_figure: Figure, center: Vector2, size: Vector2, wall_rotation: float) -> bool:
	remove_shield_wall(owner_figure)
	var wall := _make_shield_wall(owner_figure, center, size, wall_rotation)
	if wall == null:
		return false
	_shield_walls.append(wall)
	return true


## Starter Walls (relic): a wall in front of `owner_figure` that pops up and stays until remove_starter_walls().
## It is the same ShieldWall as Shieldon Ooper's (so the enemy AI's shape casts see it). Fails (false) if blocked.
func place_starter_wall(owner_figure: Figure, center: Vector2, size: Vector2) -> bool:
	var wall := _make_shield_wall(owner_figure, center, size, 0.0)
	if wall == null:
		return false
	wall.pop_up()
	_starter_walls.append(wall)
	return true


func remove_starter_walls() -> void:
	for wall in _starter_walls:
		if is_instance_valid(wall):
			remove_child(wall)  # out of the physics space right away
			wall.queue_free()
	_starter_walls.clear()


## Builds a ShieldWall and adds it to the arena, or returns null if a figure or wall is in the way.
func _make_shield_wall(owner_figure: Figure, center: Vector2, size: Vector2, wall_rotation: float) -> ShieldWall:
	var rect := RectangleShape2D.new()
	rect.size = size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = rect
	query.transform = Transform2D(wall_rotation, center)
	query.collision_mask = Figure.LAYER_ON_DECK | Figure.LAYER_FLICKED | Figure.LAYER_ENEMY | Figure.LAYER_ARENA
	query.exclude = [owner_figure.get_rid()]
	if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
		return null
	var wall := ShieldWall.new()
	wall.size = size
	wall.owner_figure = owner_figure
	wall.collision_layer = Figure.LAYER_ARENA
	wall.collision_mask = 0
	var material := PhysicsMaterial.new()
	material.bounce = wall_bounce
	material.friction = 0.0
	wall.physics_material_override = material
	var shape := CollisionShape2D.new()
	shape.shape = rect
	wall.add_child(shape)
	wall.position = center
	wall.rotation = wall_rotation
	add_child(wall)
	return wall


func shield_wall_of(owner_figure: Figure) -> ShieldWall:
	for wall in _shield_walls:
		if is_instance_valid(wall) and wall.owner_figure == owner_figure:
			return wall
	return null


func remove_shield_wall(owner_figure: Figure) -> void:
	for i in range(_shield_walls.size() - 1, -1, -1):
		var wall := _shield_walls[i]
		if not is_instance_valid(wall):
			_shield_walls.remove_at(i)
		elif wall.owner_figure == owner_figure:
			remove_child(wall)  # out of the physics space right away
			wall.queue_free()
			_shield_walls.remove_at(i)


## Places the Alchemist's zone at `pos` (its old one goes) if the spot is empty. Returns whether it was placed.
func place_zone(owner_figure: Figure, pos: Vector2, stats: Dictionary, board: Rect2) -> bool:
	remove_zone(owner_figure)
	if not is_spot_free(get_world_2d().direct_space_state, board, pos, 30.0):
		return false
	var zone := AlchemyZone.new()
	zone.radius = stats.radius
	zone.knockback = stats.knockback
	zone.douse_rounds = stats.get("douse_rounds", 2)
	zone.owner_figure = owner_figure
	zone.position = pos
	zone.z_index = 0
	add_child(zone)
	_alchemy_zones.append(zone)
	return true


func remove_zone(owner_figure: Figure) -> void:
	for i in range(_alchemy_zones.size() - 1, -1, -1):
		var zone := _alchemy_zones[i]
		if not is_instance_valid(zone):
			_alchemy_zones.remove_at(i)
		elif zone.owner_figure == owner_figure:
			remove_child(zone)
			zone.queue_free()
			_alchemy_zones.remove_at(i)


## Figures that touch an Alchemist's zone (inside it or just brushing it) get Doused (called every physics frame).
func _douse_figures_in_zones(figures: Array) -> void:
	for node in figures:
		var figure := node as Figure
		if figure.knocked_off:
			continue
		for zone in _alchemy_zones:
			if is_instance_valid(zone) and is_instance_valid(zone.owner_figure) and zone.owner_figure.team != figure.team \
					and figure.global_position.distance_to(zone.position) <= zone.radius + figure.radius:
				figure.douse(zone.douse_rounds, zone.knockback)


## The strongest knockback multiplier of an Alchemist zone of the OTHER team at `pos` (1 = none).
func zone_multiplier_at(pos: Vector2, team: int) -> float:
	var best := 1.0
	for zone in _alchemy_zones:
		if is_instance_valid(zone) and is_instance_valid(zone.owner_figure) and zone.owner_figure.team != team \
				and pos.distance_to(zone.position) <= zone.radius:
			best = maxf(best, zone.knockback)
	return best


## Zones of `team` (the enemy AI counts figures inside them): [{position, radius}].
func zones_of(team: int) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for zone in _alchemy_zones:
		if is_instance_valid(zone) and is_instance_valid(zone.owner_figure) and zone.owner_figure.team == team:
			list.append({"position": zone.position, "radius": zone.radius})
	return list


# --- Engineer's turrets ---------------------------------------------------------------

## Tap with an Engineer selected: places its turret at `pos` (a second turret of the same Engineer is
## replaced), or takes the turret back if `pos` is on it. Returns "placed", "removed" or "blocked".
func toggle_turret(engineer: Figure, pos: Vector2, stats: Dictionary, board: Rect2) -> String:
	var mine := turret_of(engineer)
	if mine != null and mine.position.distance_to(pos) <= mine.radius + 10.0:
		remove_turret(engineer)
		return "removed"
	var old_spot := mine.position if mine != null else Vector2.INF
	if not place_turret(engineer, pos, stats, board):
		if old_spot != Vector2.INF:  # blocked: the old turret stays where it was
			place_turret(engineer, old_spot, stats, board)
		return "blocked"
	return "placed"


## Places the Engineer's turret if the spot is free (the old one goes). Returns whether it was placed.
func place_turret(engineer: Figure, pos: Vector2, stats: Dictionary, board: Rect2) -> bool:
	remove_turret(engineer)
	if not is_spot_free(get_world_2d().direct_space_state, board, pos, stats.radius):
		return false
	var turret := Turret.new()
	turret.setup(engineer, stats)
	turret.position = pos
	add_child(turret)
	_turrets.append(turret)
	return true


func turret_of(engineer: Figure) -> Turret:
	for turret in _turrets:
		if is_instance_valid(turret) and turret.owner_figure == engineer:
			return turret
	return null


func remove_turret(engineer: Figure) -> void:
	for i in range(_turrets.size() - 1, -1, -1):
		var turret := _turrets[i]
		if not is_instance_valid(turret):
			_turrets.remove_at(i)
		elif turret.owner_figure == engineer:
			remove_child(turret)  # out of the physics space right away
			turret.queue_free()
			_turrets.remove_at(i)


## Forgets turrets that are gone (knocked off the table, or their Engineer fell).
func prune_turrets() -> void:
	for i in range(_turrets.size() - 1, -1, -1):
		if not is_instance_valid(_turrets[i]) or _turrets[i].is_queued_for_deletion():
			_turrets.remove_at(i)


# --- Juicer's trail ----------------------------------------------------------

## One piece of boost trail left by `ability`'s Juicer, pushing figures along `direction`.
func add_trail_segment(owner_figure: Figure, center: Vector2, direction: Vector2, ability: JuicerAbility) -> void:
	var node := TrailSegment.new()
	node.radius = ability.segment_radius
	node.direction = direction
	node.position = center
	node.z_index = 0  # (the Board is drawn first, so these show up on top of it)
	add_child(node)
	_trail.append({"owner": owner_figure, "ability": ability, "center": center, "direction": direction,
			"rounds": ability.trail_rounds, "total": ability.trail_rounds, "node": node})
	# Too many pieces from one Juicer: its oldest one goes.
	var mine := 0
	for piece in _trail:
		if piece.owner == owner_figure:
			mine += 1
	var i := 0
	while mine > ability.max_segments and i < _trail.size():
		if _trail[i].owner == owner_figure:
			_trail[i].node.queue_free()
			_trail.remove_at(i)
			mine -= 1
		else:
			i += 1


func _apply_trail_piece(piece: Dictionary, figures: Array) -> void:
	var ability: JuicerAbility = piece.ability
	for node in figures:
		var figure := node as Figure
		# Like patches: only moving figures are pushed, so a resting one is never nudged.
		if figure.on_deck or figure.knocked_off or figure.is_slow():
			continue
		if figure.global_position.distance_to(piece.center) > ability.segment_radius:
			continue
		if figure.linear_velocity.dot(piece.direction) < ability.boost_max_speed:
			figure.apply_central_force(piece.direction * ability.boost_acceleration * figure.mass)


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
	node.z_index = 0  # (the Board is drawn first, so these show up on top of it)
	add_child(node)
	var zone := {"kind": kind, "center": center, "radius": radius, "rounds": rounds, "node": node, "inside": {}}
	zone.merge(extra)
	_zones.append(zone)


## One round has passed: bricks and zones with a limited life count down and vanish.
func tick_round() -> void:
	for i in range(_trail.size() - 1, -1, -1):
		_trail[i].rounds -= 1
		if _trail[i].rounds <= 0:
			_trail[i].node.queue_free()
			_trail.remove_at(i)
		else:
			_trail[i].node.life = float(_trail[i].rounds) / _trail[i].total
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
			figure.apply_central_force(offset.normalized() * zone.pull * RunManager.relic_pull_multiplier() * strength * figure.mass)
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
