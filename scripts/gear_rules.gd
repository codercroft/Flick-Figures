class_name GearRules
extends RefCounted
## Which equipment and finishes make sense for a figure, so enemies never carry gear that does
## nothing for them (Glow-in-the-dark on a figure with no ability, Wings on a Ghost...) and prefer
## gear that fits their role (heavy gear on Duwall, power gear on Powerhouse).
## The per-item rules live on the EquipmentData / FinishData resources ("Who it suits").


## True if `item` (EquipmentData or FinishData) would do something for `figure`.
static func fits(item: Resource, figure: FigureData) -> bool:
	if item.needs_ability_numbers and not _has_ability_numbers(figure):
		return false
	for script in item.incompatible_abilities:
		if figure.ability != null and figure.ability.get_script() == script:
			return false
	if item is EquipmentData:
		# A bounce bonus does nothing on a figure that already bounces perfectly (Godot caps it at 1).
		if item.bounce_bonus > 0.0 and figure.bounce >= 1.0:
			return false
		# The same ability twice (Magnet Charm on a Magnet) just doubles up nothing new.
		if item.effect != null and figure.ability != null and item.effect.get_script() == figure.ability.get_script():
			return false
	return true


## A random item from `items` that fits `figure`, favoring its role; null if none fits.
static func pick(items: Array, figure: FigureData) -> Resource:
	var weights: Array[float] = []
	var candidates: Array = []
	var total := 0.0
	var roles := roles_for(figure)
	for item in items:
		if not fits(item, figure):
			continue
		var weight := 1.0
		for role in roles:
			weight += float(item.role_weights.get(role, 0.0))
		candidates.append(item)
		weights.append(weight)
		total += weight
	if candidates.is_empty():
		return null
	var roll := randf() * total
	for i in candidates.size():
		roll -= weights[i]
		if roll <= 0.0:
			return candidates[i]
	return candidates[candidates.size() - 1]


## What a figure is good at, from its stats and ability.
static func roles_for(figure: FigureData) -> Array[String]:
	var roles: Array[String] = []
	if figure.mass >= 1.3 or figure.knockback_taken_multiplier < 0.9:
		roles.append("heavy")
	if figure.mass <= 0.9:
		roles.append("light")
	if figure.flick_power_multiplier >= 1.4:
		roles.append("power")
	if figure.bounce >= 0.9:
		roles.append("bouncy")
	if figure.damping_multiplier <= 0.8:
		roles.append("slider")
	if figure.ability != null and "explosion_radius" in figure.ability:
		roles.append("explosive")
	return roles


static func _has_ability_numbers(figure: FigureData) -> bool:
	if figure.ability == null:
		return false
	for key in Figure.STRENGTH_PROPERTIES:
		if key in figure.ability:
			return true
	return false
