class_name EquipmentData
extends Resource
## One equipment item: attached to a single figure for the run. Simple stat changes are plain
## numbers here; anything fancier is an `effect` (any FigureAbility subclass, see
## scripts/equipment/). Make a new item by duplicating a .tres in resources/equipment/ and
## adding it to RunConfig.equipment_pool.

@export var display_name := "Item"
## One or two characters drawn on the little badge shown on an equipped figure.
@export var label := "?"
@export_multiline var description := ""
@export var color := Color(0.8, 0.8, 0.85)
## Economy items pay money; they are never handed to enemies (enemies carry no equipment).
@export var economy := false

@export_group("Stat changes")
## The figure's mass is multiplied by this.
@export var mass_multiplier := 1.0
## Added to the figure's bounce (Godot caps the total at 1).
@export var bounce_bonus := 0.0
## The figure's damping is multiplied by this (below 1 = slides farther).
@export var damping_multiplier := 1.0
## Extra money at the end of a won combat if the figure is still on the table.
@export var income_bonus := 0

@export_group("Effect")
## Optional special behavior using the ability hooks.
@export var effect: FigureAbility
