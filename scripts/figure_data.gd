class_name FigureData
extends Resource
## Everything that makes one kind of figure different. Make a new figure by
## duplicating a .tres in resources/figures/ and changing the values in the Inspector.

@export var display_name := "Figure"
@export var color := Color.WHITE
@export var radius := 60.0
@export var mass := 1.0
@export_range(0.0, 1.0) var bounce := 0.7
## Multiplies the base damping set on the Main node. Below 1 = slides farther.
@export var damping_multiplier := 1.0
## Multiplies the flick force. Launch speed = force * this / mass.
@export var flick_power_multiplier := 1.0
## Multiplies the speed this figure gains from being hit or blasted. 0.5 = half knockback.
@export var knockback_taken_multiplier := 1.0
## Optional special behavior. Pick a FigureAbility subclass (e.g. BomboAbility) in the Inspector.
@export var ability: FigureAbility
