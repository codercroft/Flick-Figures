extends MenuScreen
## The Compendium: a grid of every figure, grouped by rarity. A figure is unlocked once the player has met it
## in any way (offered in a draft or shop, owned, or faced as an enemy: RunHistory.mark_seen); locked ones are
## a dark silhouette with "???". Tap an unlocked figure for its page (FigurePage).

const COLUMNS := 3
const CELL_SIZE := Vector2(320.0, 330.0)

var _page := FigurePage.new()


func build() -> void:
	_show_grid()


func _show_grid() -> void:
	title.text = "Compendium"
	clear_content()
	clear_actions()
	var figures := _all_figures()
	var unlocked := 0
	for figure in figures:
		if RunHistory.is_seen(figure):
			unlocked += 1
	add_text("%d of %d figures discovered" % [unlocked, figures.size()], 32, Color(0.6, 0.63, 0.72))
	for rarity in 3:
		var group: Array[FigureData] = []
		for figure in figures:
			if figure.rarity == rarity:
				group.append(figure)
		if group.is_empty():
			continue
		group.sort_custom(func(a: FigureData, b: FigureData): return a.display_name < b.display_name)
		add_heading(group[0].rarity_name(), 40).add_theme_color_override("font_color", group[0].rarity_color())
		var grid := GridContainer.new()
		grid.columns = COLUMNS
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 14)
		content.add_child(grid)
		for figure in group:
			grid.add_child(_cell(figure))
	var bosses: Array[BossData] = RunManager.config.registry.bosses
	if not bosses.is_empty():
		var met := 0
		for boss in bosses:
			if RunHistory.is_boss_seen(boss):
				met += 1
		add_heading("Bosses (%d of %d met)" % [met, bosses.size()], 40).add_theme_color_override("font_color", Color(0.95, 0.4, 0.35))
		var boss_grid := GridContainer.new()
		boss_grid.columns = COLUMNS
		boss_grid.add_theme_constant_override("h_separation", 14)
		boss_grid.add_theme_constant_override("v_separation", 14)
		content.add_child(boss_grid)
		for boss in bosses:
			boss_grid.add_child(_boss_cell(boss))
	add_action("Back", go_to_menu)


func _boss_cell(boss: BossData) -> Button:
	var seen := RunHistory.is_boss_seen(boss)
	var button := _cell(boss.badge_figure(), seen, Color(0.95, 0.4, 0.35), boss.display_name)
	if seen:
		button.pressed.connect(_show_boss_page.bind(boss))
	return button


## A boss's page: picture, name, what the fight is, and the bodies' own ability text.
func _show_boss_page(boss: BossData) -> void:
	title.text = "Compendium"
	clear_content()
	clear_actions()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	column.add_child(header)
	var badge := FigureBadge.new()
	badge.data = boss.badge_figure()
	badge.custom_minimum_size = Vector2(190.0, 190.0)
	header.add_child(badge)
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(names)
	names.add_child(_boss_label(boss.display_name, 56, Color.WHITE))
	names.add_child(_boss_label("Boss", 38, Color(0.95, 0.4, 0.35)))
	column.add_child(_boss_label("The fight", 38, Color(0.9, 0.92, 0.98)))
	column.add_child(_boss_label(boss.description, 32, Color(0.78, 0.81, 0.9)))
	var listed: Array[String] = []
	for body in boss.enemies:
		if body.description != "" and not listed.has(body.description):
			listed.append(body.description)
	if not listed.is_empty():
		column.add_child(_boss_label("Bodies", 38, Color(0.9, 0.92, 0.98)))
		for text in listed:
			column.add_child(_boss_label(text, 32, Color(0.78, 0.81, 0.9)))
	scroll.scroll_vertical = 0
	add_action("Back", _show_grid)


func _boss_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _cell(figure: FigureData, seen := RunHistory.is_seen(figure), border := Color.WHITE, label := "") -> Button:
	var button := Button.new()
	button.custom_minimum_size = CELL_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.17, 0.19, 0.25) if seen else Color(0.1, 0.11, 0.15)
		box.set_corner_radius_all(20)
		box.set_border_width_all(4)
		box.border_color = (border if label != "" else figure.rarity_color()) if seen else Color(0.2, 0.22, 0.28)
		button.add_theme_stylebox_override(state, box)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)
	var badge := FigureBadge.new()
	badge.data = figure
	badge.locked = not seen
	badge.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(badge)
	var name_label := Label.new()
	name_label.text = (label if label != "" else figure.display_name) if seen else "???"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.add_theme_color_override("font_color", Color.WHITE if seen else Color(0.4, 0.42, 0.5))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)
	if seen:
		if label == "":
			button.pressed.connect(_show_page.bind(figure))
	else:
		button.focus_mode = Control.FOCUS_NONE
	return button


func _show_page(figure: FigureData) -> void:
	title.text = "Compendium"
	clear_content()
	clear_actions()
	_page = FigurePage.new()
	content.add_child(_page)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.show_figure(figure)
	scroll.scroll_vertical = 0
	add_action("Back", _show_grid)


## Every figure a player can meet: the Grunt and the draftable ones.
func _all_figures() -> Array[FigureData]:
	var registry: FigureRegistry = RunManager.config.registry
	var list: Array[FigureData] = []
	for figure in registry.grunts:
		list.append(figure)
	for figure in registry.draftable:
		if not list.has(figure):
			list.append(figure)
	return list
