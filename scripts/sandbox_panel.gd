class_name SandboxPanel
extends CanvasLayer
## Sandbox mode's controls on top of the real combat scene: a strip of play controls at the bottom (always
## visible, thumb reach) and a collapsible setup sheet (arena, figures, bosses, fights, relics and powers).
## Edit mode (the Edit button) lets you tap a figure to select it, drag it to move it, or tap empty board to
## place the figure picked in the Figures tab. Structural changes rewrite SandboxSetup and reload the scene.

## Extra height (game units) the combat scene keeps free at the bottom for the strip.
const STRIP_RESERVE := 250.0
const STRIP_HEIGHT := 190.0
const EXTRA_FIGURES := ["swarmling", "sniper", "splitter_mini", "skull_ball", "clustling", "slime_small", "slime_medium", "slime_large", "wall_piece"]

static var tab := "Figures"
static var place_data: FigureData
static var place_team := Figure.Team.PLAYER

var main: Node
var _strip := PanelContainer.new()
var _sheet := PanelContainer.new()
var _content := VBoxContainer.new()
var _status := Label.new()
var _buttons := {}
var _selected: Figure
var _drag_index := -1
var _drag_fig: Figure
var _drag_moved := false
var _press_pos := Vector2.ZERO
var _dirty := false  # relic / power choices changed: "Apply" reloads


func setup(combat: Node) -> void:
	main = combat
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 25
	var bottom: float = SafeArea.insets().bottom
	_build_strip(bottom)
	main.ui.skip_button.offset_top = _strip.offset_top - 80.0  # (the bonus-flick Skip button sits above the strip)
	main.ui.skip_button.offset_bottom = _strip.offset_top - 10.0
	_build_sheet(bottom)
	_refresh_buttons()
	_show_tab(tab)
	_sheet.visible = SandboxSetup.sheet_open
	_update_status()


# --- Layout ---------------------------------------------------------------------------------

func _box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_content_margin_all(10)
	box.set_corner_radius_all(14)
	return box


func _build_strip(bottom: float) -> void:
	_strip.anchor_top = 1.0
	_strip.anchor_bottom = 1.0
	_strip.anchor_right = 1.0
	_strip.offset_left = 16.0
	_strip.offset_right = -16.0
	_strip.offset_bottom = -(250.0 + bottom + 10.0)
	_strip.offset_top = _strip.offset_bottom - STRIP_HEIGHT
	_strip.add_theme_stylebox_override("panel", _box(Color(0.08, 0.09, 0.13, 0.95)))
	add_child(_strip)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_strip.add_child(column)
	_status.add_theme_font_size_override("font_size", 24)
	_status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 34)
	column.add_child(_status)
	var row1 := HBoxContainer.new()
	var row2 := HBoxContainer.new()
	for row in [row1, row2]:
		row.add_theme_constant_override("separation", 6)
		column.add_child(row)
	_add_button(row1, "setup", "Setup", _toggle_sheet)
	_add_button(row1, "mode", "Edit", _toggle_mode)
	_add_button(row1, "ai", "AI on", _toggle_ai)
	_add_button(row1, "free", "Free off", _toggle_free)
	_add_button(row1, "menu", "Menu", _leave)
	_add_button(row2, "reset", "Reset", _reset)
	_add_button(row2, "clear", "Clear", _clear_board)
	_add_button(row2, "pause", "Pause", _toggle_pause)
	_add_button(row2, "step", "Step", _step)


func _add_button(row: HBoxContainer, key: String, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 64)
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(callback)
	row.add_child(button)
	_buttons[key] = button
	return button


func _build_sheet(bottom: float) -> void:
	_sheet.anchor_right = 1.0
	_sheet.anchor_top = 0.0
	_sheet.anchor_bottom = 1.0
	_sheet.offset_left = 16.0
	_sheet.offset_right = -16.0
	_sheet.offset_top = TopBar.height() + 380.0
	_sheet.offset_bottom = _strip.offset_top - 8.0
	_sheet.add_theme_stylebox_override("panel", _box(Color(0.1, 0.11, 0.16, 0.97)))
	add_child(_sheet)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_sheet.add_child(column)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	column.add_child(tabs)
	for name in ["Arena", "Figures", "Boss", "Fights", "Items"]:
		var button := Button.new()
		button.text = name
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 64)
		button.add_theme_font_size_override("font_size", 26)
		button.pressed.connect(_show_tab.bind(name))
		tabs.add_child(button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)


func is_over_ui(screen_pos: Vector2) -> bool:
	return _strip.get_global_rect().has_point(screen_pos) or (_sheet.visible and _sheet.get_global_rect().has_point(screen_pos))


# --- Strip buttons ----------------------------------------------------------------------------

func _refresh_buttons() -> void:
	_buttons.mode.text = "Play" if SandboxSetup.mode == SandboxSetup.Mode.EDIT else "Edit"
	_buttons.ai.text = "AI off" if SandboxSetup.ai_off else "AI on"
	_buttons.free.text = "Free on" if SandboxSetup.free_flick else "Free off"
	_buttons.pause.text = "Resume" if main.get_tree().paused else "Pause"
	_buttons.setup.text = "Hide" if _sheet.visible else "Setup"
	for key in ["ai", "free"]:
		var on: bool = SandboxSetup.ai_off if key == "ai" else SandboxSetup.free_flick
		_buttons[key].modulate = Color(1.0, 0.8, 0.4) if on else Color.WHITE
	_buttons.mode.modulate = Color(0.6, 0.9, 1.0) if SandboxSetup.mode == SandboxSetup.Mode.EDIT else Color.WHITE


func _update_status() -> void:
	if SandboxSetup.mode == SandboxSetup.Mode.EDIT:
		if place_data != null:
			_status.text = "Placing %s (%s): tap the board or deck. Tap a figure to select, drag to move." % [place_data.display_name, "Player" if place_team == Figure.Team.PLAYER else "Enemy"]
		elif is_instance_valid(_selected):
			_status.text = "Selected: %s. Drag to move; Setup > Figures to edit or delete." % _selected.data.display_name
		else:
			_status.text = "Edit mode: tap a figure to select it, drag to move it."
	elif SandboxSetup.free_flick:
		_status.text = "Free flick: flick anything, any time."
	elif SandboxSetup.ai_off:
		_status.text = "AI off: you flick the enemy side too."
	else:
		_status.text = "Sandbox: normal play."


func _toggle_sheet() -> void:
	_sheet.visible = not _sheet.visible
	SandboxSetup.sheet_open = _sheet.visible
	_refresh_buttons()


func _toggle_mode() -> void:
	if SandboxSetup.mode == SandboxSetup.Mode.EDIT:
		set_mode_play()
	else:
		SandboxSetup.mode = SandboxSetup.Mode.EDIT
		main._deselect()
		main.aim_line.clear()
	_refresh_buttons()
	_update_status()


func set_mode_play() -> void:
	SandboxSetup.mode = SandboxSetup.Mode.PLAY
	place_data = null
	_select(null)


func _toggle_ai() -> void:
	SandboxSetup.ai_off = not SandboxSetup.ai_off
	if not SandboxSetup.ai_off:
		main.sandbox_resume_ai()
	_refresh_buttons()
	_update_status()


func _toggle_free() -> void:
	SandboxSetup.free_flick = not SandboxSetup.free_flick
	if not SandboxSetup.free_flick:
		main.sandbox_end_free_flick()
	_refresh_buttons()
	_update_status()


func _toggle_pause() -> void:
	main.get_tree().paused = not main.get_tree().paused
	_refresh_buttons()


func _step() -> void:
	var tree := main.get_tree()
	if not tree.paused:
		return
	tree.paused = false
	await tree.create_timer(0.1, true).timeout
	tree.paused = true


func _reset() -> void:
	reload()


func _clear_board() -> void:
	SandboxSetup.lineup_kind = "none"
	SandboxSetup.boss = null
	SandboxSetup.encounter = null
	SandboxSetup.entries.clear()
	reload()


func _leave() -> void:
	main.get_tree().paused = false
	SandboxSetup.end()
	main.get_tree().change_scene_to_file(NodeScenes.MENU_SCENE)


## Rebuilds the combat from the stored setup.
func reload() -> void:
	main.get_tree().paused = false
	SandboxSetup.prepare()
	main.get_tree().reload_current_scene()


# --- Setup sheet -------------------------------------------------------------------------------

func _clear_content() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func _show_tab(name: String) -> void:
	tab = name
	_clear_content()
	match name:
		"Arena":
			_tab_arena()
		"Figures":
			_tab_figures()
		"Boss":
			_tab_boss()
		"Fights":
			_tab_fights()
		"Items":
			_tab_items()


func _list_button(text: String, callback: Callable, highlighted := false, color := Color.WHITE) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 70)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 26)
	button.modulate = Color(1.0, 0.9, 0.45) if highlighted else color
	button.pressed.connect(callback)
	return button


func _heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	_content.add_child(label)


func _grid(columns := 2) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	return grid


func _tab_arena() -> void:
	var grid := _grid(2)
	grid.add_child(_list_button("Auto (lineup's own)", _set_arena.bind(null), SandboxSetup.arena == null))
	for arena in RunManager.config.arenas:
		grid.add_child(_list_button(arena.display_name, _set_arena.bind(arena), SandboxSetup.arena == arena))
	grid.add_child(_list_button("Boss field", _set_arena.bind(RunManager.config.boss_arena), SandboxSetup.arena == RunManager.config.boss_arena))


func _set_arena(arena: ArenaData) -> void:
	SandboxSetup.arena = arena
	reload()


## Every figure that can be placed: Grunt, every draftable figure and the extras (Swarmling, Sniper, boss pieces...).
func placeable_figures() -> Array[FigureData]:
	var list: Array[FigureData] = []
	var registry := RunManager.config.registry
	list.append_array(registry.grunts)
	for data in registry.draftable:
		if not list.has(data):
			list.append(data)
	for file in EXTRA_FIGURES:
		var data := load("res://resources/figures/%s.tres" % file) as FigureData
		if data != null and not list.has(data):
			list.append(data)
	return list


func _tab_figures() -> void:
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 8)
	_content.add_child(sides)
	sides.add_child(_list_button("Side: Player", _set_team.bind(Figure.Team.PLAYER), place_team == Figure.Team.PLAYER, Color(0.7, 0.85, 1.0)))
	sides.add_child(_list_button("Side: Enemy", _set_team.bind(Figure.Team.ENEMY), place_team == Figure.Team.ENEMY, Color(1.0, 0.7, 0.7)))
	if is_instance_valid(_selected):
		_selected_section()
	_heading("Tap a figure, then tap the board or deck")
	var grid := _grid(3)
	for data in placeable_figures():
		grid.add_child(_list_button(data.display_name, _pick_figure.bind(data), place_data == data))


func _set_team(team: int) -> void:
	place_team = team
	_show_tab("Figures")


func _pick_figure(data: FigureData) -> void:
	place_data = data
	SandboxSetup.mode = SandboxSetup.Mode.EDIT
	main._deselect()
	_select(null)
	_sheet.visible = false  # the board stays usable: the sheet folds away while you place
	SandboxSetup.sheet_open = false
	_refresh_buttons()
	_update_status()


func _entry_of(figure: Figure) -> Dictionary:
	for entry in SandboxSetup.entries:
		if entry.get("node") == figure:
			return entry
	return {}


func _selected_section() -> void:
	_heading("Selected: %s (%s)" % [_selected.data.display_name, "Player" if _selected.team == Figure.Team.PLAYER else "Enemy"])
	_content.add_child(_list_button("Delete this figure", _delete_selected, false, Color(1.0, 0.6, 0.6)))
	var entry := _entry_of(_selected)
	if entry.is_empty():
		var note := Label.new()
		note.text = "(From the loaded lineup: it can be moved or deleted. Gear editing is for placed figures.)"
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_size_override("font_size", 22)
		_content.add_child(note)
		return
	var config := RunManager.config
	var tree := RunManager.tree_for(entry.data)
	if tree != null:
		_content.add_child(_option("Upgrade", _upgrade_names(tree), _upgrade_index(entry.upgrade), _set_upgrade))
	var finishes: Array[String] = ["No finish"]
	for finish in config.finish_pool:
		finishes.append(finish.display_name)
	_content.add_child(_option("Finish", finishes, config.finish_pool.find(entry.finish) + 1, _set_finish))
	var items: Array[String] = ["No equipment"]
	for item in config.equipment_pool:
		items.append(item.display_name)
	_content.add_child(_option("Equipment", items, config.equipment_pool.find(entry.equipment) + 1, _set_equipment))


func _option(label: String, items: Array[String], selected: int, callback: Callable) -> Control:
	var row := HBoxContainer.new()
	var text := Label.new()
	text.text = label
	text.custom_minimum_size = Vector2(190, 0)
	text.add_theme_font_size_override("font_size", 26)
	row.add_child(text)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.custom_minimum_size = Vector2(0, 70)
	option.add_theme_font_size_override("font_size", 24)
	option.get_popup().add_theme_font_size_override("font_size", 28)
	for item in items:
		option.add_item(item)
	option.select(clampi(selected, 0, items.size() - 1))
	option.item_selected.connect(callback)
	row.add_child(option)
	return row


func _upgrade_names(tree: UpgradeTree) -> Array[String]:
	var names: Array[String] = ["None"]
	for path in 2:
		var tiers := tree.tiers(path)
		for i in tiers.size():
			names.append("%s%d: %s" % ["AB"[path], i + 1, tiers[i].display_name])
	return names


func _upgrade_index(state: Vector2i) -> int:
	return 0 if state.x < 0 or state.y <= 0 else 1 + state.x * 3 + (state.y - 1)


func _set_upgrade(index: int) -> void:
	var entry := _entry_of(_selected)
	entry.upgrade = Vector2i(-1, 0) if index == 0 else Vector2i((index - 1) / 3, (index - 1) % 3 + 1)
	_respawn(entry)


func _set_finish(index: int) -> void:
	var entry := _entry_of(_selected)
	entry.finish = null if index == 0 else RunManager.config.finish_pool[index - 1]
	_respawn(entry)


func _set_equipment(index: int) -> void:
	var entry := _entry_of(_selected)
	entry.equipment = null if index == 0 else RunManager.config.equipment_pool[index - 1]
	_respawn(entry)


## Gear changed: the figure is rebuilt in place with the new gear.
func _respawn(entry: Dictionary) -> void:
	var old: Figure = entry.node
	entry.pos = old.global_position
	var slot: int = old.deck_slot
	main.sandbox_remove(old)
	entry.slot = slot
	var figure: Figure = main.sandbox_spawn(entry)
	_select(figure)
	_show_tab("Figures")


func _delete_selected() -> void:
	var figure := _selected
	_select(null)
	var entry := _entry_of(figure)
	if not entry.is_empty():
		SandboxSetup.entries.erase(entry)
	main.sandbox_remove(figure)
	_show_tab("Figures")
	_update_status()


func _tab_boss() -> void:
	_heading("Act (scales the boss from Ascension 3)")
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 8)
	_content.add_child(acts)
	for i in RunManager.config.acts:
		acts.add_child(_list_button("Act %d" % (i + 1), _set_act.bind(i), SandboxSetup.act == i))
	var levels: Array[String] = []
	for level in RunManager.config.ascension.max_level + 1:
		levels.append("Ascension %d" % level)
	_content.add_child(_option("Level", levels, SandboxSetup.ascension, _set_ascension))
	_heading("Spawn a boss (replaces the enemy side)")
	var grid := _grid(2)
	for boss in RunManager.config.registry.bosses:
		grid.add_child(_list_button(boss.display_name, _pick_boss.bind(boss), SandboxSetup.lineup_kind == "boss" and SandboxSetup.boss == boss))


func _set_act(act: int) -> void:
	SandboxSetup.act = act
	reload()


func _set_ascension(level: int) -> void:
	SandboxSetup.ascension = level
	reload()


func _pick_boss(boss: BossData) -> void:
	SandboxSetup.lineup_kind = "boss"
	SandboxSetup.boss = boss
	SandboxSetup.encounter = null
	reload()


func _tab_fights() -> void:
	_heading("Regular encounters")
	var grid := _grid(2)
	for encounter in RunManager.config.regular_encounters:
		grid.add_child(_list_button("%s (A%s)" % [encounter.display_name, ",".join(encounter.acts.map(func(a): return str(a)))], _pick_encounter.bind(encounter), SandboxSetup.encounter == encounter))
	_heading("Elites")
	var elites := _grid(2)
	for encounter in RunManager.config.elite_encounters:
		elites.add_child(_list_button("%s (A%s)" % [encounter.display_name, ",".join(encounter.acts.map(func(a): return str(a)))], _pick_encounter.bind(encounter), SandboxSetup.encounter == encounter, Color(1.0, 0.85, 0.5)))


func _pick_encounter(encounter: EncounterData) -> void:
	SandboxSetup.lineup_kind = "encounter"
	SandboxSetup.encounter = encounter
	SandboxSetup.boss = null
	reload()


var _relic_side := Figure.Team.PLAYER

func _tab_items() -> void:
	_content.add_child(_list_button("Apply and reload" if _dirty else "Apply (no changes)", _apply, _dirty))
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 8)
	_content.add_child(sides)
	sides.add_child(_list_button("Relics: Player", _set_relic_side.bind(Figure.Team.PLAYER), _relic_side == Figure.Team.PLAYER, Color(0.7, 0.85, 1.0)))
	sides.add_child(_list_button("Relics: Enemy", _set_relic_side.bind(Figure.Team.ENEMY), _relic_side == Figure.Team.ENEMY, Color(1.0, 0.7, 0.7)))
	var config := RunManager.config
	var pool: Array = config.relic_pool if _relic_side == Figure.Team.PLAYER else config.elite_config.enemy_relic_pool
	var held: Array = SandboxSetup.player_relics if _relic_side == Figure.Team.PLAYER else SandboxSetup.enemy_relics
	var grid := _grid(2)
	for relic in pool:
		var on := held.has(relic)
		grid.add_child(_list_button(("[x] " if on else "[ ] ") + relic.display_name, _toggle_relic.bind(relic), on))
	_heading("Powers (player only, %d slots; the enemy has no powers)" % config.power_slots)
	var powers := _grid(2)
	for power in config.power_pool:
		var on := SandboxSetup.player_powers.has(power)
		powers.add_child(_list_button(("[x] " if on else "[ ] ") + power.display_name, _toggle_power.bind(power), on))


func _set_relic_side(team: int) -> void:
	_relic_side = team
	_show_tab("Items")


func _toggle_relic(relic: RelicData) -> void:
	var list: Array = SandboxSetup.player_relics if _relic_side == Figure.Team.PLAYER else SandboxSetup.enemy_relics
	if list.has(relic):
		list.erase(relic)
	else:
		list.append(relic)
	_dirty = true
	_show_tab("Items")


func _toggle_power(power: PowerData) -> void:
	var list := SandboxSetup.player_powers
	if list.has(power):
		list.erase(power)
	elif list.size() < RunManager.config.power_slots:
		list.append(power)
	_dirty = true
	_show_tab("Items")


func _apply() -> void:
	reload()


# --- Edit mode: select, move, place ----------------------------------------------------------------

func _select(figure: Figure) -> void:
	if is_instance_valid(_selected):
		_selected.selected = false
	_selected = figure
	if is_instance_valid(figure):
		figure.selected = true
	_update_status()


func _figure_at(world: Vector2) -> Figure:
	var best: Figure = null
	var best_distance := INF
	for figure in main.get_all_figures():
		var distance: float = figure.global_position.distance_to(world)
		if not figure.knocked_off and distance <= figure.radius + 24.0 and distance < best_distance:
			best = figure
			best_distance = distance
	return best


func _input(event: InputEvent) -> void:
	if SandboxSetup.mode != SandboxSetup.Mode.EDIT or RunInfo.is_open:
		return
	if event is InputEventScreenTouch:
		var world: Vector2 = main._to_world(event.position)
		if event.pressed:
			if is_over_ui(event.position) or _drag_index != -1:
				return
			_drag_index = event.index
			_drag_moved = false
			_press_pos = event.position
			_drag_fig = _figure_at(world)
		elif event.index == _drag_index:
			_drag_index = -1
			_finish_touch(world)
	elif event is InputEventScreenDrag and event.index == _drag_index:
		if is_instance_valid(_drag_fig) and (_drag_moved or event.position.distance_to(_press_pos) > 14.0):
			_drag_moved = true
			var world: Vector2 = main._to_world(event.position)
			_move_figure(_drag_fig, world)


func _move_figure(figure: Figure, world: Vector2) -> void:
	var table: Rect2 = main.board.get_table_rect()
	world = Vector2(clampf(world.x, table.position.x + 20.0, table.end.x - 20.0), clampf(world.y, table.position.y + 20.0, table.end.y - 20.0))
	figure.global_position = world
	figure.linear_velocity = Vector2.ZERO
	figure.angular_velocity = 0.0
	if figure.team == Figure.Team.PLAYER:
		figure.on_deck = main.board.deck_rect.has_point(world)
		figure.deck_position = world
	var entry := _entry_of(figure)
	if not entry.is_empty():
		entry.pos = world


func _finish_touch(world: Vector2) -> void:
	if is_instance_valid(_drag_fig):
		if not _drag_moved:
			place_data = null
			_select(_drag_fig)
			if _sheet.visible and tab == "Figures":
				_show_tab("Figures")
		_drag_fig = null
		return
	if _drag_moved:
		return
	var table: Rect2 = main.board.get_table_rect()
	if place_data != null and table.has_point(world):
		var entry := {"data": place_data, "team": place_team, "pos": world, "equipment": null, "finish": null, "upgrade": Vector2i(-1, 0), "node": null}
		SandboxSetup.entries.append(entry)
		var figure: Figure = main.sandbox_spawn(entry)
		_select(figure)
	else:
		_select(null)
	_update_status()
