class_name FatStomach
extends StaticBody2D
## Fat Man's stomach: a huge fixed circle at the top of the table (a static body, it can never be knocked off). A hit counts
## when a PLAYER figure strikes it on the player's turn at a closing speed above `min_hit_speed`, or a player-side explosion
## reaches it with enough force; at most ONE counted hit per player flick. Reaching `hits_needed` wins the fight.

signal hit_counted(remaining: int)

## A figure's closing speed (px/s) along the stomach's surface that counts as a hit.
@export var min_hit_speed := 700.0
## An explosion counts when its push at the stomach's surface is at least this.
@export var min_blast_force := 500.0
@export var bounce := 0.6
@export var skin_color := Color(0.96, 0.76, 0.62)
@export var outline_color := Color(0.62, 0.38, 0.3)

var radius := 280.0
var hits_needed := 4
var hits := 0
var _last_flick := -1
var _wobble := 0.0:
	set(value):
		_wobble = value
		queue_redraw()


func setup(stomach_radius: float, needed: int) -> void:
	radius = stomach_radius
	hits_needed = needed
	collision_layer = Figure.LAYER_ARENA
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
	add_to_group("fat_stomach")
	queue_redraw()


func remaining() -> int:
	return maxi(hits_needed - hits, 0)


func defeated() -> bool:
	return hits >= hits_needed


func _player_turn() -> bool:
	var combat = RunManager.combat
	return combat != null and combat.turret_side == Figure.Team.PLAYER


## A player figure hit the stomach with `velocity` (just before the impact).
func hit_by(figure: Figure, velocity: Vector2) -> void:
	if figure.team != Figure.Team.PLAYER or not _player_turn():
		return
	var normal := (figure.global_position - global_position).normalized()
	if absf(velocity.dot(normal)) >= min_hit_speed:
		_register()


## An explosion at `center`; only the player's side counts.
func take_explosion(center: Vector2, blast_radius: float, force: float, source_team: int) -> void:
	if source_team != Figure.Team.PLAYER or not _player_turn():
		return
	var gap := maxf(center.distance_to(global_position) - radius, 0.0)
	if gap >= blast_radius:
		return
	if force * (1.0 - gap / blast_radius) >= min_blast_force:
		_register()


func _register() -> void:
	if defeated():
		return
	var combat = RunManager.combat
	var flick: int = combat.player_flicks if combat != null else 0
	if flick == _last_flick:
		return  # already counted for this flick
	_last_flick = flick
	hits += 1
	hit_counted.emit(remaining())
	var tween := create_tween()
	tween.tween_property(self, "_wobble", 1.0, 0.08)
	tween.tween_property(self, "_wobble", 0.0, 0.4)
	_popup("HIT!  %d left" % remaining() if remaining() > 0 else "Down he goes!")


func _popup(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(-220.0, radius * 0.45)
	label.size = Vector2(440.0, 70.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 56)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 12)
	label.z_index = 10
	add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 80.0, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tween.chain().tween_callback(label.queue_free)


func _draw() -> void:
	var squash := 1.0 + 0.06 * sin(_wobble * PI)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(squash, 1.0 / squash))
	draw_circle(Vector2.ZERO, radius, skin_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, outline_color, 8.0, true)
	draw_arc(Vector2(-radius * 0.35, -radius * 0.35), radius * 0.45, deg_to_rad(190.0), deg_to_rad(250.0), 12, Color(1, 1, 1, 0.35), 10.0, true)
	# the belly button, in the middle
	var navel := Vector2(0.0, radius * 0.05)
	draw_circle(navel, radius * 0.07, outline_color.darkened(0.2))
	draw_arc(navel, radius * 0.1, 0.0, TAU, 20, outline_color, 5.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the hits left: one big number and a row of pips under the belly button
	var font := ThemeDB.fallback_font
	var text := str(remaining())
	var size := 120
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
	draw_string(font, Vector2(-width / 2.0, radius * 0.55), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.45, 0.15, 0.1))
	var spacing := 44.0
	var start_x := -spacing * (hits_needed - 1) / 2.0
	for i in hits_needed:
		var center := Vector2(start_x + spacing * i, radius * 0.68)
		if i < remaining():
			draw_circle(center, 15.0, Color(0.85, 0.2, 0.15))
		else:
			draw_arc(center, 13.0, 0.0, TAU, 14, Color(0.45, 0.15, 0.1, 0.6), 4.0, true)
