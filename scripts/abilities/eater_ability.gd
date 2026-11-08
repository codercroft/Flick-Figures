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
## The Collector elite sets this: the enemy AI feeds Eater its own smaller teammates to grow.
@export var feeds_on_allies := false
## Appetite path: +$ per meal (the player's side), it can eat figures its own size, and its growth cap.
@export var meal_money := 0
@export var can_eat_equal := false
## Digest path: +x knockback dealt per meal, and it can eat boss minions (medium / small slimes, Skull Balls...).
@export var meal_knockback := 0.0
@export var eat_minions := false

var _meals := 0


func on_hit(figure: Figure, other: Figure) -> void:
	var too_big := other.radius > figure.radius if can_eat_equal else other.radius >= figure.radius
	var protected: bool = other.data.uneatable and not (eat_minions and not other.data.boss_body)
	if figure.knocked_off or other.knocked_off or too_big or protected:
		return
	var combat = RunManager.combat
	if combat == null:
		return
	combat.force_knock_off(other)
	_meals += 1
	if meal_money > 0 and figure.team == Figure.Team.PLAYER:
		RunManager.money += meal_money
	var new_radius := minf(sqrt(figure.radius * figure.radius + area_gain * other.radius * other.radius), max_radius)
	var new_mass := minf(figure.mass + mass_gain * other.mass, max_mass)
	figure.set_size(new_radius, new_mass)
	figure.show_popup("Munch!", Color(1.0, 0.6, 0.4))


func eats_smaller(_figure: Figure) -> bool:
	return true


func wants_ally_food(_figure: Figure) -> bool:
	return feeds_on_allies


func get_dealt_knockback_bonus(_figure: Figure, _other: Figure) -> float:
	return meal_knockback * _meals
