class_name BossData
extends Resource
## One boss fight. Its enemy figures carry the stats you tune (mass, accuracy, flick power,
## creep distance), so edit those in resources/figures/ (e.g. wall_piece.tres, sniper.tres).

@export var display_name := "Boss"
@export_multiline var description := ""
## Placeholder text and color for this boss's node on the run map.
@export var map_label := "B"
@export var map_color := Color(0.8, 0.2, 0.2)
## Optional little icon drawn above the label on the map (FigureIcons.Icon, 0 = none).
@export var map_icon: FigureIcons.Icon = FigureIcons.Icon.NONE
## The enemy figures for the boss fight, left to right.
@export var enemies: Array[FigureData] = []
## How many flicks the enemy side takes per turn in this fight (each one is the best shot of
## any enemy figure; the same figure can't flick twice in a row).
@export var enemy_flicks_per_turn := 1
## The enemy side flicks once per turn for each of its units on the table (Slime: every piece; Skull-o-tron:
## the core and each Skull Ball), up to Main.max_enemy_flicks, instead of `enemy_flicks_per_turn`.
@export var flick_per_unit := false
## Line the enemies up in one straight row across the board (The Wall) instead of staggering them.
@export var straight_row := false
## A solid wall along the whole top edge of the table, behind the boss, so it cannot be knocked straight
## off the back in one shot (Slime, Skull-o-tron).
@export var back_wall := false
