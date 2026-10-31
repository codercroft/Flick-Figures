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
	add_action("Back", go_to_menu)


func _cell(figure: FigureData) -> Button:
	var seen := RunHistory.is_seen(figure)
	var button := Button.new()
	button.custom_minimum_size = CELL_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.17, 0.19, 0.25) if seen else Color(0.1, 0.11, 0.15)
		box.set_corner_radius_all(20)
		box.set_border_width_all(4)
		box.border_color = figure.rarity_color() if seen else Color(0.2, 0.22, 0.28)
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
	name_label.text = figure.display_name if seen else "???"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.add_theme_color_override("font_color", Color.WHITE if seen else Color(0.4, 0.42, 0.5))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)
	if seen:
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
