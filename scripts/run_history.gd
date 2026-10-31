class_name RunHistory
extends RefCounted
## The player's long-term records, saved in user://run_history.json and kept between sessions:
##  - `runs`: one entry per finished run (see record_run for the fields)
##  - `seen`: the figures the player has ever met (offered in a draft or shop, owned, or faced as an enemy),
##    which is what unlocks them in the Compendium.
## Everything is static, so any script can call RunHistory.mark_seen(figure). Figures are stored by resource path.

const PATH := "user://run_history.json"
const VERSION := 1

static var _data := {}
static var _loaded := false


# --- Seen figures (Compendium unlocks) ----------------------------------------------------

static func mark_seen(figure: FigureData) -> void:
	if figure == null or figure.resource_path == "":
		return
	_load()
	var seen: Array = _data.seen
	if not seen.has(figure.resource_path):
		seen.append(figure.resource_path)
		_save()


static func mark_seen_all(figures: Array) -> void:
	for figure in figures:
		mark_seen(figure)


static func is_seen(figure: FigureData) -> bool:
	_load()
	return figure != null and _data.seen.has(figure.resource_path)


# --- Recording a run ---------------------------------------------------------------------

## Adds a finished run. `run` is the RunManager (passed in, no direct reference).
## Fields: ts (unix time), date, won, act (1-based act reached), acts (total), node (text), boss (the boss that
## ended a lost run, "" otherwise), deck [{figure, name, finish, upgrade, equipment}], relics [names],
## picked [{figure, name}] (every figure the player took during the run, in order).
static func record_run(run, won: bool) -> void:
	_load()
	var deck := []
	for i in run.deck.size():
		deck.append({
			"figure": run.deck[i].resource_path,
			"name": run.deck[i].display_name,
			"finish": run.deck_finish[i].display_name if run.deck_finish[i] != null else "",
			"upgrade": run.deck_upgrade[i].display_name if run.deck_upgrade[i] != null else "",
			"equipment": run.deck_equipment[i].display_name if run.deck_equipment[i] != null else "",
		})
	var relics := []
	for relic in run.relics:
		relics.append(relic.display_name)
	var picked := []
	for figure in run.picked_figures:
		picked.append({"figure": figure.resource_path, "name": figure.display_name})
	var node_text := "Act cleared" if won else "Start of the act"
	var boss_name := ""
	if run.node != null:
		node_text = "Boss" if run.node.type == MapNode.Type.BOSS else "%s, stop %d" % [MapNode.type_name(run.node.type), run.node.column + 1]
		if not won and run.node.type == MapNode.Type.BOSS and run.boss != null:
			boss_name = run.boss.display_name
	_data.runs.append({
		"ts": int(Time.get_unix_time_from_system()),
		"date": Time.get_datetime_string_from_system(false, true).left(16),
		"won": won,
		"act": run.act + 1,
		"acts": run.config.acts,
		"node": node_text,
		"boss": boss_name,
		"deck": deck,
		"relics": relics,
		"picked": picked,
	})
	_save()


# --- Reading -----------------------------------------------------------------------------

## Finished runs, newest first.
static func runs() -> Array:
	_load()
	var list: Array = _data.runs.duplicate()
	list.reverse()
	return list


## {runs, wins, win_rate (0-1), furthest_act}.
static func overall_stats() -> Dictionary:
	_load()
	var wins := 0
	var furthest := 0
	for entry in _data.runs:
		if entry.won:
			wins += 1
		furthest = maxi(furthest, int(entry.act))
	var count: int = _data.runs.size()
	return {"runs": count, "wins": wins, "win_rate": float(wins) / count if count > 0 else 0.0, "furthest_act": furthest}


## Per figure, keyed by resource path: {name, picked, in_deck, wins, win_rate (-1 if never in a final deck)}.
## "picked" counts every time it was taken, "in_deck" the runs it ended in the final deck (once per run), "wins"
## those runs that were won.
static func figure_stats() -> Dictionary:
	_load()
	var stats := {}
	for entry in _data.runs:
		for pick in entry.picked:
			_figure_entry(stats, pick.figure, pick.name).picked += 1
		var in_this_run := {}
		for slot in entry.deck:
			in_this_run[slot.figure] = slot.name
		for path in in_this_run:
			var record := _figure_entry(stats, path, in_this_run[path])
			record.in_deck += 1
			if entry.won:
				record.wins += 1
	for path in stats:
		var record: Dictionary = stats[path]
		record["win_rate"] = float(record.wins) / record.in_deck if record.in_deck > 0 else -1.0
	return stats


## The stats of one figure (zeros if it never showed up).
static func stats_for(figure: FigureData) -> Dictionary:
	var all := figure_stats()
	return all.get(figure.resource_path, {"name": figure.display_name, "picked": 0, "in_deck": 0, "wins": 0, "win_rate": -1.0})


## Figure stats as a list, best first. `by` = "picked" (most picked) or "win_rate" (highest win rate; figures
## that never made a final deck go last).
static func ranked_figures(by: String) -> Array:
	var list := figure_stats().values()
	list.sort_custom(func(a, b):
		if by == "win_rate":
			if a.win_rate != b.win_rate:
				return a.win_rate > b.win_rate
			if a.in_deck != b.in_deck:
				return a.in_deck > b.in_deck
		elif a.picked != b.picked:
			return a.picked > b.picked
		return a.name < b.name)
	return list


static func _figure_entry(stats: Dictionary, path: String, figure_name: String) -> Dictionary:
	if not stats.has(path):
		stats[path] = {"name": figure_name, "picked": 0, "in_deck": 0, "wins": 0, "win_rate": -1.0}
	return stats[path]


# --- Storage -----------------------------------------------------------------------------

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_data = {"version": VERSION, "runs": [], "seen": []}
	if not FileAccess.file_exists(PATH):
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_data.runs = parsed.get("runs", [])
		_data.seen = parsed.get("seen", [])


static func _save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[history] could not write %s" % PATH)
		return
	file.store_string(JSON.stringify(_data, "\t"))
