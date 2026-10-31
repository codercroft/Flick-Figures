class_name FigurePage
extends VBoxContainer
## One figure's Compendium page: picture, rarity, the empty 3D viewer slot (FigureInspector), the ability
## description, key stats, its figure-specific upgrade and the player's personal stats from the run history.
## `show_figure(data)` fills it; the Compendium screen adds the Back button.


func show_figure(data: FigureData) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("separation", 12)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	add_child(header)
	var badge := FigureBadge.new()
	badge.data = data
	badge.custom_minimum_size = Vector2(190.0, 190.0)
	header.add_child(badge)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(names)
	names.add_child(_label(data.display_name, 56, Color.WHITE))
	names.add_child(_label(data.rarity_name(), 38, data.rarity_color()))

	var inspector := FigureInspector.new()  # (the slot for a future 3D viewer)
	add_child(inspector)
	inspector.show_figure(data)

	add_child(_label("Ability", 38, Color(0.9, 0.92, 0.98)))
	add_child(_label(data.description if data.description != "" else "No special ability.", 32, Color(0.78, 0.81, 0.9)))

	add_child(_label("Stats", 38, Color(0.9, 0.92, 0.98)))
	for line in [
		"Mass: %s" % _number(data.mass),
		"Flick power: x%s" % _number(data.flick_power_multiplier),
		"Knockback taken: x%s" % _number(data.knockback_taken_multiplier),
		"Bounce: %s" % _number(data.bounce),
	]:
		add_child(_label(line, 32, Color(0.78, 0.81, 0.9)))

	add_child(_label("Upgrade", 38, Color(0.9, 0.92, 0.98)))
	var upgrades := RunManager.upgrades_for(data)
	if upgrades.is_empty():
		add_child(_label("No figure-specific upgrade yet.", 32, Color(0.6, 0.63, 0.72)))
	for upgrade in upgrades:
		add_child(_label("%s: %s" % [upgrade.display_name, upgrade.description], 32, Color(1.0, 0.82, 0.25)))

	add_child(_label("Your stats", 38, Color(0.9, 0.92, 0.98)))
	var stats := RunHistory.stats_for(data)
	add_child(_label("Times picked: %d" % stats.picked, 32, Color(0.78, 0.81, 0.9)))
	add_child(_label("In the final deck: %d runs" % stats.in_deck, 32, Color(0.78, 0.81, 0.9)))
	var rate := "no finished run with it yet" if stats.win_rate < 0.0 else "%d%% (%d of %d)" % [roundi(stats.win_rate * 100.0), stats.wins, stats.in_deck]
	add_child(_label("Win rate with it: %s" % rate, 32, Color(0.78, 0.81, 0.9)))


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _number(value: float) -> String:
	return str(snappedf(value, 0.01))
