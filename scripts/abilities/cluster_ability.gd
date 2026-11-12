class_name ClusterAbility
extends FigureAbility
## Cluster is `count` small clustlings packed tightly together and moving as ONE rigid body: one circle collision
## shape per clustling (radius 45, a tight triangle for 3, a diamond for 4), each drawn as its own little figure.
## Instead of flicking, a quick TAP on the board tosses one clustling toward that spot: its circle leaves the body
## and it becomes its own figure (a fresh, flickable one that counts for win/loss); the cluster gets lighter. Tossing
## uses the Cluster's action (toss OR flick). It can't toss its last clustling. A loose clustling that touches its
## own cluster rejoins it in the free spot (ClustlingAbility). Only the main cluster pays combat income.

## What gets tossed out.
@export var piece: FigureData
## How many clustlings the FigureData's mass describes.
@export var base_count := 3
## How many clustlings it starts with (the Big Bunch upgrade makes it 4).
@export var start_count := 3
## Radius of one clustling (also its collision circle in the body).
@export var clustling_radius := 45.0
## How fast (px/s) a tossed clustling leaves.
@export var toss_speed := 950.0
## Swarm path: clustlings (the cluster and the loose ones) deal this much more knockback (0.25 = +25%).
@export var clustling_knockback := 0.0
## Rebound path: tossing does not use up the flick (Toss and Flick); loose clustlings slide home when your turn ends.
@export var toss_keeps_action := false
@export var slide_home := false

var count := 3
var _mass_each := 0.0
var _tossed_this_turn := false
var _toss_offered := false  # the "toss again" offer for the last toss was made
var _slots: Array[Vector2] = []     # where each clustling sits (layout space)
var _taken: Array[bool] = []        # is the slot filled right now
var _shapes: Array[CollisionShape2D] = []
var _origin := Vector2.ZERO         # the layout point that is the body's origin (the centre of the filled slots)


func setup_body(figure: Figure) -> void:
	_mass_each = figure.mass / float(base_count)
	count = start_count
	_slots = _layout(start_count)
	_taken.clear()
	_shapes.clear()
	figure.use_custom_shapes()
	figure.lock_rotation = true
	for i in _slots.size():
		_taken.append(true)
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = clustling_radius
		shape.shape = circle
		figure.add_child(shape)
		_shapes.append(shape)
	_origin = _centroid()
	_update_body(figure)


## Tight packings of touching circles: 1 centre, 2 side by side, 3 a triangle, 4 a diamond, more a ring.
func _layout(n: int) -> Array[Vector2]:
	var r := clustling_radius
	var out: Array[Vector2] = []
	match n:
		1:
			out.append(Vector2.ZERO)
		2:
			out.append(Vector2(-r, 0))
			out.append(Vector2(r, 0))
		3:
			out.append(Vector2(0, -r * 1.1547))
			out.append(Vector2(-r, r * 0.5774))
			out.append(Vector2(r, r * 0.5774))
		4:
			out.append(Vector2(0, -r * 1.4142))
			out.append(Vector2(r * 1.4142, 0))
			out.append(Vector2(0, r * 1.4142))
			out.append(Vector2(-r * 1.4142, 0))
		_:
			var ring := r / sin(PI / n)
			for i in n:
				out.append(Vector2.from_angle(TAU * i / n - PI / 2.0) * ring)
	return out


func _centroid() -> Vector2:
	var sum := Vector2.ZERO
	var filled := 0
	for i in _slots.size():
		if _taken[i]:
			sum += _slots[i]
			filled += 1
	return sum / maxf(filled, 1)


## Re-centres the body on the filled slots, places the shapes and sets the size and mass.
func _update_body(figure: Figure) -> void:
	var centre := _centroid()
	figure.global_position += centre - _origin  # the origin moves, the clustlings do not
	_origin = centre
	var reach := 0.0
	for i in _slots.size():
		_shapes[i].set_deferred("disabled", not _taken[i])
		_shapes[i].position = _slots[i] - _origin
		if _taken[i]:
			reach = maxf(reach, (_slots[i] - _origin).length())
	figure.set_size(reach + clustling_radius, _mass_each * count)  # (radius = a circle around all of them, for the AI)


func get_toss_stats(_figure: Figure) -> Dictionary:
	return {"speed": toss_speed, "can": count > 1 and piece != null, "piece": piece, "keeps_action": toss_keeps_action}


func get_dealt_knockback_bonus(_figure: Figure, _other: Figure) -> float:
	return clustling_knockback


## The tap action: toss the clustling that sits most toward `point`.
func fire_shot_at(figure: Figure, point: Vector2) -> void:
	if count <= 1 or piece == null:
		return
	var offset := point - figure.global_position
	var direction := offset.normalized() if offset.length() > 1.0 else Vector2.UP
	var best := -1
	var best_dot := -INF
	for i in _slots.size():
		if _taken[i] and (_slots[i] - _origin).dot(direction) > best_dot:
			best_dot = (_slots[i] - _origin).dot(direction)
			best = i
	_tossed_this_turn = true
	_toss_offered = false
	var spawn_at := figure.global_position + (_slots[best] - _origin) + direction * 8.0
	_taken[best] = false
	count -= 1
	_update_body(figure)
	var parent := figure
	figure.shed([{
		"data": piece, "position": spawn_at, "velocity": direction * toss_speed, "flickable": true,
		"on_spawn": func(spawned: Figure) -> void:
			spawned.ability.parent = parent
			spawned.ability.knockback_bonus = clustling_knockback
			spawned.ability.slide_home = slide_home,
	}])
	figure.show_popup("Toss!", Color(0.7, 0.9, 1.0))


## A clustling of ours came home: it takes the free spot nearest to where it touched. False if the cluster is full.
func accept_rejoin(figure: Figure, at: Vector2) -> bool:
	var best := -1
	var best_dist := INF
	for i in _slots.size():
		if not _taken[i]:
			var d := (figure.global_position + _slots[i] - _origin).distance_to(at)
			if d < best_dist:
				best_dist = d
				best = i
	if best < 0:
		return false
	_taken[best] = true
	count += 1
	_update_body(figure)
	figure.show_popup("+1", Color(0.7, 0.9, 1.0))
	return true


func draws_own_body(_figure: Figure) -> bool:
	return true


func draws_own_label(_figure: Figure) -> bool:
	return true


## Each clustling is its own small figure.
func draw_body(figure: Figure) -> void:
	if _slots.is_empty():
		return
	var greyed := figure.team == Figure.Team.PLAYER and not figure.flickable
	var fill := figure.data.color.lerp(Figure.GREYED_OUT, 0.85) if greyed else figure.data.color
	var ring := Figure.ENEMY_RING if figure.team == Figure.Team.ENEMY else Figure.PLAYER_RING
	for i in _slots.size():
		if not _taken[i]:
			continue
		var spot := _slots[i] - _origin
		figure.draw_circle(spot, clustling_radius, fill)
		figure.draw_arc(spot, clustling_radius - 3.0, 0.0, TAU, 28, ring, 5.0, true)
		figure.draw_circle(spot + Vector2(-1, -1) * clustling_radius * 0.3, clustling_radius * 0.2, fill.lightened(0.4))


func on_turn_ended(_figure: Figure) -> void:
	_tossed_this_turn = false
	_toss_offered = false


## After a toss settles the player may toss again, as many times as there are clustlings to spare (never the last one).
## (With Toss and Flick tossing keeps the action, so no window is needed.)
func wants_post_action(figure: Figure) -> String:
	if _tossed_this_turn and not _toss_offered and not toss_keeps_action and count > 1 and piece != null and not figure.knocked_off:
		_toss_offered = true
		return "toss"
	return ""
