class_name EncounterEnemy
extends Resource
## One kind of enemy in a named encounter: a figure, how many of it, and optional stat boosts.
## The boosts stack on top of the act's difficulty multipliers.

@export var figure: FigureData
@export var count := 1
## Where each copy starts, in board space ((0, 0) = top-left of the board, y grows toward the player's
## deck, enemies live in the top half). Missing entries (or none) use the normal spread-out row.
@export var positions: Array[Vector2] = []
## Equipment every copy of this enemy always carries (on top of nothing else: it replaces the random roll).
@export var equipment: EquipmentData
@export_group("Boosts")
@export var mass_multiplier := 1.0
@export var flick_power_multiplier := 1.0
@export var accuracy_multiplier := 1.0
## Added to the figure's bounce (Godot caps the total at 1).
@export var bounce_bonus := 0.0
## Multiplies the figure's ability numbers (radius, pull, bounce...): same list as Glow-in-the-dark.
@export var ability_strength := 1.0


## The boost as a stat-scale dictionary (what Figure.setup reads).
func boost() -> Dictionary:
	return {"mass": mass_multiplier, "power": flick_power_multiplier, "accuracy": accuracy_multiplier,
			"bounce": bounce_bonus, "ability": ability_strength}
