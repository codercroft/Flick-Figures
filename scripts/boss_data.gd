class_name BossData
extends Resource
## One boss fight. Its enemy figures carry the stats you tune (mass, accuracy, flick power,
## creep distance), so edit those in resources/figures/ (e.g. big_bad.tres, sniper.tres).

@export var display_name := "Boss"
@export_multiline var description := ""
## Placeholder text and color for this boss's node on the run map.
@export var map_label := "B"
@export var map_color := Color(0.8, 0.2, 0.2)
## The enemy figures for the boss fight, left to right.
@export var enemies: Array[FigureData] = []
