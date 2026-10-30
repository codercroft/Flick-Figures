class_name EaterAbility
extends FigureAbility
## Eats any figure (either team) it touches that is smaller than it: the eaten figure is removed (it counts as
## knocked off) and Eater grows, its radius and mass increasing in proportion to what it ate, up to caps.
## Bosses and boss pieces (FigureData.uneatable) can never be eaten.

## Share of the eaten figure's AREA added to Eater's area (its radius grows with the square root).
@export var area_gain := 0.6
## Share of the eaten figure's mass added to Eater's mass.
@export var mass_gain := 0.7
## Eater never grows past these.
@export var max_radius := 110.0
@export var max_mass := 4.0


func on_hit(figure: Figure, other: Figure) -> void:
	if figure.knocked_off or other.knocked_off or other.radius >= figure.radius or other.data.uneatable:
		return
	var combat = RunManager.combat
	if combat == null:
		return
	combat.force_knock_off(other)
	var new_radius := minf(sqrt(figure.radius * figure.radius + area_gain * other.radius * other.radius), max_radius)
	var new_mass := minf(figure.mass + mass_gain * other.mass, max_mass)
	figure.set_size(new_radius, new_mass)
	figure.show_popup("Munch!", Color(1.0, 0.6, 0.4))


func eats_smaller(_figure: Figure) -> bool:
	return true
