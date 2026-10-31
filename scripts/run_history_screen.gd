extends MenuScreen
## Run History: the stats (overall and per figure, sortable, top figures at a glance) and the list of past
## runs, newest first. Tap a run to expand its details.

const TOP_COUNT := 5

var _sort := "picked"  # "picked" or "win_rate"
var _show_all := false
var _expanded := {}  # run index -> true


func build() -> void:
	title.text = "Run History"
	add_action("Back", go_to_menu)
	_rebuild()


func _rebuild() -> void:
	var offset := scroll.scroll_vertical
	clear_content()
	_build_stats()
	_build_runs()
	_restore_scroll.call_deferred(offset)


func _restore_scroll(offset: int) -> void:
	scroll.scroll_vertical = offset


func _build_stats() -> void:
	var overall := RunHistory.overall_stats()
	add_heading("Stats")
	if overall.runs == 0:
		add_text("No finished runs yet. Win or lose a run and it shows up here.", 32, Color(0.6, 0.63, 0.72))
		return
	add_text("Runs played: %d     Wins: %d     Win rate: %d%%\nFurthest act reached: %d of %d" % [
			overall.runs, overall.wins, roundi(overall.win_rate * 100.0), overall.furthest_act, RunManager.config.acts], 32)
	add_heading("Figures", 36)
	var sort_row := HBoxContainer.new()
	sort_row.add_theme_constant_override("separation", 12)
	content.add_child(sort_row)
	sort_row.add_child(_sort_button("Most picked", "picked"))
	sort_row.add_child(_sort_button("Win rate", "win_rate"))
	var ranked := RunHistory.ranked_figures(_sort)
	var shown := ranked.size() if _show_all else mini(TOP_COUNT, ranked.size())
	for i in shown:
		var record: Dictionary = ranked[i]
		var rate := "-" if record.win_rate < 0.0 else "%d%% (%d/%d)" % [roundi(record.win_rate * 100.0), record.wins, record.in_deck]
		add_text("%d. %s\n     picked %d  |  in final deck %d  |  win rate %s" % [i + 1, record.name, record.picked, record.in_deck, rate], 30)
	if ranked.size() > TOP_COUNT:
		var toggle := Button.new()
		toggle.text = "Show fewer" if _show_all else "Show all %d figures" % ranked.size()
		toggle.custom_minimum_size = Vector2(0.0, 80.0)
		toggle.add_theme_font_size_override("font_size", 32)
		toggle.pressed.connect(func():
			_show_all = not _show_all
			_rebuild())
		content.add_child(toggle)


func _sort_button(text: String, key: String) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_pressed = _sort == key
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, 80.0)
	button.add_theme_font_size_override("font_size", 32)
	button.pressed.connect(func():
		_sort = key
		_rebuild())
	return button


func _build_runs() -> void:
	var runs := RunHistory.runs()
	if runs.is_empty():
		return
	add_heading("Runs")
	for i in runs.size():
		var entry: Dictionary = runs[i]
		var result := "WON" if entry.won else "LOST"
		var where := "all %d acts" % entry.acts if entry.won else "Act %d, %s" % [entry.act, entry.node]
		var header := Button.new()
		header.text = "%s   %s\n%s" % [result, entry.date, where]
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.custom_minimum_size = Vector2(0.0, 110.0)
		header.add_theme_font_size_override("font_size", 32)
		header.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6) if entry.won else Color(1.0, 0.6, 0.55))
		header.pressed.connect(func():
			_expanded[i] = not _expanded.get(i, false)
			_rebuild())
		content.add_child(header)
		if _expanded.get(i, false):
			add_text(_details(entry), 28)


func _details(entry: Dictionary) -> String:
	var lines: PackedStringArray = []
	if entry.boss != "":
		lines.append("Ended by: %s" % entry.boss)
	lines.append("Final deck:")
	for slot in entry.deck:
		var extras: PackedStringArray = []
		for key in ["finish", "upgrade", "equipment"]:
			if slot[key] != "":
				extras.append(slot[key])
		lines.append("  - %s%s" % [slot.name, " (%s)" % ", ".join(extras) if not extras.is_empty() else ""])
	lines.append("Relics: %s" % (", ".join(entry.relics) if not entry.relics.is_empty() else "none"))
	var picked: PackedStringArray = []
	for pick in entry.picked:
		picked.append(pick.name)
	lines.append("Figures picked: %s" % (", ".join(picked) if not picked.is_empty() else "none"))
	return "\n".join(lines)
