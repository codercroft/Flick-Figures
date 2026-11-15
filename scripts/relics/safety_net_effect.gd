class_name SafetyNetEffect
extends RelicEffect
## At the start of the enemy's SECOND turn of each combat a wall runs along the whole bottom edge of the table (below
## the deck strip), so player figures can't be knocked off the bottom. It lasts through that enemy turn.
## Enemy version: the same wall along the TOP edge, through the player's second turn. (Shared resource: nothing is stored here.)

## Wall thickness (px) and how far past the table's corners it reaches.
@export var wall_thickness := 30.0
@export var wall_overhang := 60.0
## How long the enemy waits for the pop-up animation before it shoots (seconds).
@export var pop_wait := 0.45


func on_enemy_turn_start(main, index: int) -> float:
	if index != 1:
		return 0.0
	return pop_wait if main.arena.place_edge_wall(Figure.Team.PLAYER, main.board.get_table_rect(), false, wall_thickness, wall_overhang) else 0.0


func on_player_turn_start(main, index: int) -> void:
	if index == 1:
		main.arena.place_edge_wall(Figure.Team.ENEMY, main.board.get_table_rect(), true, wall_thickness, wall_overhang)
