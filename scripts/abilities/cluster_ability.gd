class_name ClusterAbility
extends FigureAbility
## Cluster starts as 3 small clustlings moving together as ONE body. Instead of flicking, a quick TAP on the board
## tosses one clustling toward that spot: it becomes its own figure (a fresh, flickable one that counts for
## win/loss) and the cluster gets smaller and lighter. Tossing uses the Cluster's action (toss OR flick). It
## can't toss its last clustling. A loose clustling that touches its own cluster rejoins it (see ClustlingAbility).
## Only the main cluster pays combat income (the clustling's data has pays_income off).

## What gets tossed out.
@export var piece: FigureData
## How many clustlings the FigureData's mass describes (its radius is recomputed from the count).
@export var base_count := 3
## How many clustlings it starts with (the Big Bunch upgrade makes it 4).
@export var start_count := 3
## Size of one clustling; the cluster's radius is this x (1 + radius_growth x sqrt(count - 1)).
@export var clustling_radius := 45.0
@export var radius_growth := 0.45
## How fast (px/s) a tossed clustling leaves.
@export var toss_speed := 700.0

var count := 3
var _mass_each := 0.0


func setup_body(figure: Figure) -> void:
	_mass_each = figure.mass / float(base_count)
	count = start_count
	_apply_size(figure)


func radius_for(clustlings: int) -> float:
	return clustling_radius * (1.0 + radius_growth * sqrt(maxf(clustlings - 1, 0.0)))


func _apply_size(figure: Figure) -> void:
	figure.set_size(radius_for(count), _mass_each * count)


func get_toss_stats(_figure: Figure) -> Dictionary:
	return {"speed": toss_speed, "can": count > 1 and piece != null, "piece": piece}


## The tap action: toss one clustling toward `point`.
func fire_shot_at(figure: Figure, point: Vector2) -> void:
	if count <= 1 or piece == null:
		return
	var offset := point - figure.global_position
	var direction := offset.normalized() if offset.length() > 1.0 else Vector2.UP
	count -= 1
	_apply_size(figure)
	var spawn_at := figure.global_position + direction * (figure.radius + piece.radius + 6.0)
	var parent := figure
	figure.shed([{
		"data": piece, "position": spawn_at, "velocity": direction * toss_speed, "flickable": true,
		"on_spawn": func(spawned: Figure) -> void: spawned.ability.parent = parent,
	}])
	figure.show_popup("Toss!", Color(0.7, 0.9, 1.0))


## A clustling of ours came home.
func accept_rejoin(figure: Figure) -> bool:
	count += 1
	_apply_size(figure)
	figure.show_popup("+1", Color(0.7, 0.9, 1.0))
	return true


## Draws the clustlings inside the body.
func draw_overlay(figure: Figure) -> void:
	var small := minf(clustling_radius * 0.8, figure.radius * 0.55)
	var ring := figure.radius - small - 3.0
	for i in count:
		var spot := Vector2.ZERO if count == 1 else Vector2.from_angle(TAU * i / count - PI / 2.0) * ring
		figure.draw_circle(spot, small, Color(1, 1, 1, 0.22))
		figure.draw_arc(spot, small, 0.0, TAU, 20, Color(1, 1, 1, 0.65), 3.0, true)
