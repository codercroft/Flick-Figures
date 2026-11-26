class_name ArenaData
extends Resource
## One arena layout. To make a new one, duplicate a file in resources/arenas/ and edit it in the
## Inspector, then add it to the `arenas` list in resources/run_config.tres.
## Everything goes inside the board: keep the deck strip below it clear.

enum Difficulty { EASY, MEDIUM, HARD }
const DIFFICULTY_NAMES := ["Easy", "Medium", "Hard"]
const DIFFICULTY_COLORS := [Color(0.55, 0.9, 0.55), Color(1.0, 0.82, 0.3), Color(1.0, 0.45, 0.4)]

@export var display_name := "Arena"
## How hard the layout is for the player. Random arenas roll a difficulty first (RunConfig.arena_odds_by_act).
@export var difficulty := Difficulty.EASY
## Whether a creeping boss (The Wall) can use this arena. Turn this off for layouts with walls, pins
## or patches in its path, since they would block or bend its creep.
@export var creeper_safe := true
@export var walls: Array[ArenaWall] = []
@export var pins: Array[ArenaPin] = []
@export var patches: Array[ArenaPatch] = []


func difficulty_name() -> String:
	return DIFFICULTY_NAMES[difficulty]


func difficulty_color() -> Color:
	return DIFFICULTY_COLORS[difficulty]


## Boost patches must stay at least this far (px) from the left and right edges of the board.
const BOOST_SIDE_MARGIN := 150


## Problems with this layout (empty if it looks fine) for a board of the given size.
func get_warnings(board_size: Vector2) -> PackedStringArray:
	var warnings: PackedStringArray = []
	for wall in walls:
		var half := (wall.size.rotated(deg_to_rad(wall.rotation_degrees)).abs()) / 2.0
		if wall.position.y + half.y > board_size.y + 1.0:
			warnings.append("wall at %s reaches into the deck strip" % wall.position)
	for pin in pins:
		if pin.position.y + pin.radius > board_size.y + 1.0:
			warnings.append("pin at %s reaches into the deck strip" % pin.position)
	for patch in patches:
		if patch.position.y + patch.size.y / 2.0 > board_size.y + 1.0:
			warnings.append("patch at %s reaches into the deck strip" % patch.position)
		# A boost near a side edge can push figures straight off the table.
		if patch.kind == ArenaPatch.Kind.BOOST and minf(patch.position.x - patch.size.x / 2.0,
				board_size.x - patch.position.x - patch.size.x / 2.0) < BOOST_SIDE_MARGIN:
			warnings.append("boost patch at %s is within %d px of a side edge" % [patch.position, BOOST_SIDE_MARGIN])
	return warnings


## True if a circle at `pos` (board space) of `radius` overlaps a wall or pin of this layout.
func blocks_circle(pos: Vector2, radius: float) -> bool:
	for wall in walls:
		var local := (pos - wall.position).rotated(-deg_to_rad(wall.rotation_degrees))
		var dx := maxf(absf(local.x) - wall.size.x / 2.0, 0.0)
		var dy := maxf(absf(local.y) - wall.size.y / 2.0, 0.0)
		if Vector2(dx, dy).length() < radius:
			return true
	for pin in pins:
		if pos.distance_to(pin.position) < radius + pin.radius:
			return true
	return false
