class_name StarterWallsEffect
extends RelicEffect
## Right before the enemy's first shot of each combat, a wall (Shieldon Ooper's ShieldWall) pops up in front of
## every player figure that is still unflicked on the deck, on the enemy-facing side (above it). The walls last
## through that whole enemy turn and are removed when the player's next turn starts (main._start_player_turn).
## (Shared resource: nothing is stored here.)

## Size of each wall (px) and the gap between the figure's edge and the wall (like Shieldon's defaults).
@export var wall_length := 190.0
@export var wall_thickness := 26.0
@export var wall_gap := 10.0
## How long the enemy waits for the pop-up animation before it shoots (seconds).
@export var pop_wait := 0.45


func on_first_enemy_turn(main) -> float:
	var placed := 0
	for figure in main._players:
		if not is_instance_valid(figure) or figure.knocked_off or not figure.on_deck or not figure.flickable:
			continue
		var center: Vector2 = figure.global_position + Vector2.UP * (figure.radius + wall_gap + wall_thickness / 2.0)
		if main.arena.place_starter_wall(figure, center, Vector2(wall_length, wall_thickness)):
			placed += 1
	return pop_wait if placed > 0 else 0.0
