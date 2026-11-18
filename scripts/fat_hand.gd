class_name FatHand
extends AnimatableBody2D
## One of Fat Man's hands: a solid ball that rests at `home` between turns (so it can block shots at the stomach), reaches out
## to grab a player figure, carries it home and throws it. While it holds a figure, a hard enough hit from a player figure
## makes it drop the figure where it is (counterplay).

signal dropped(hand: FatHand)

## A player figure's closing speed (px/s) that makes the hand drop what it holds.
@export var drop_hit_speed := 800.0
@export var bounce := 0.5
@export var skin_color := Color(0.96, 0.76, 0.62)
@export var outline_color := Color(0.62, 0.38, 0.3)

var radius := 62.0
var home := Vector2.ZERO
var held: Figure


func setup(hand_radius: float, home_position: Vector2) -> void:
	radius = hand_radius
	home = home_position
	global_position = home
	sync_to_physics = true
	set_solid(true)
	collision_mask = 0
	var material := PhysicsMaterial.new()
	material.bounce = bounce
	material.friction = 0.0
	physics_material_override = material
	var circle := CircleShape2D.new()
	circle.radius = radius
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)
	add_to_group("fat_hands")
	z_index = 1
	queue_redraw()


## Solid = figures bounce off it (between turns); not solid while it moves, so it never shoves the figure it reaches for.
func set_solid(solid: bool) -> void:
	collision_layer = Figure.LAYER_ARENA if solid else 0


func is_holding() -> bool:
	return is_instance_valid(held) and held.held


func hit_by(figure: Figure, velocity: Vector2) -> void:
	if not is_holding() or figure.team != Figure.Team.PLAYER or collision_layer == 0:
		return
	var combat = RunManager.combat
	if combat == null or combat.turret_side != Figure.Team.PLAYER:
		return
	var normal := (figure.global_position - global_position).normalized()
	if absf(velocity.dot(normal)) >= drop_hit_speed:
		dropped.emit(self)


func _physics_process(_delta: float) -> void:
	if is_holding():
		held.teleport_to(global_position)  # (the held figure rides in the palm)
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, skin_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, outline_color, 6.0, true)
	var curl := 0.55 if is_holding() else 1.0
	for i in 4:  # fingers on the far side from the stomach (down), curled round the figure when holding
		var angle := deg_to_rad(40.0 + i * 33.0) 
		var tip := Vector2.from_angle(angle) * radius * (0.9 + 0.5 * curl)
		draw_circle(tip, radius * 0.26, skin_color)
		draw_arc(tip, radius * 0.26, 0.0, TAU, 12, outline_color, 4.0, true)
