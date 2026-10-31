class_name RunSave
extends RefCounted
## Saving and loading the current run (user://run_save.json). Everything is stored by resource path (figures,
## relics, powers, equipment, finishes, upgrades, bosses, encounters, events, arenas are all .tres files),
## plus the numbers and the act's map. `RunManager` is passed in as `run` (no direct reference, so there is
## no parse cycle with the autoload). The game autosaves whenever the player arrives at the map screen.
## `pending_node` is the map node the player entered after that save (-1 = none): quitting inside it and
## pressing Continue enters it again from the start (the lineup is the same: see RunManager.enter_node).

const PATH := "user://run_save.json"
const VERSION := 1


static func has_save() -> bool:
	return FileAccess.file_exists(PATH)


static func delete() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## Writes the whole run. `pending_node` = -1 (we are on the map).
static func save(run, pending_node := -1) -> void:
	var map_nodes := []
	for node in run.map.nodes:
		map_nodes.append({"id": node.id, "column": node.column, "lane": node.lane, "type": node.type,
				"next": node.next, "visited": node.visited})
	var data := {
		"version": VERSION,
		"seed": run.run_seed,
		"act": run.act,
		"current_node": run.current_node,
		"pending_node": pending_node,
		"money": run.money,
		"first_combat_played": run.first_combat_played,
		"minigame_penalty": run.minigame_penalty,
		"harder_fight": run.harder_fight,
		"penalty_text": run.penalty_text,
		"deck": _paths(run.deck),
		"picked": _paths(run.picked_figures),
		"deck_equipment": _paths(run.deck_equipment),
		"deck_finish": _paths(run.deck_finish),
		"deck_upgrade": _paths(run.deck_upgrade),
		"equipment_inventory": _paths(run.equipment_inventory),
		"relics": _paths(run.relics),
		"powers": _paths(run.powers),
		"act_bosses": _paths(run.act_bosses),
		"used_encounters": _paths(run.used_encounters),
		"used_events": _paths(run.used_events),
		"arena": _path(run.arena),
		"map": {"columns": run.map.columns, "lanes": run.map.lanes, "boss_id": run.map.boss_id, "nodes": map_nodes},
	}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[save] could not write %s" % PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))


## Remembers that the player entered a map node after the last save (a small edit of the saved file).
static func set_pending(node_id: int) -> void:
	var data := _read()
	if data.is_empty():
		return
	data["pending_node"] = node_id
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))


## Loads the saved run into `run`. Returns the pending node id (-1 = none), or -2 if there is no usable save.
static func load_into(run) -> int:
	var data := _read()
	if data.is_empty():
		return -2
	run.run_seed = int(data.get("seed", 0))
	run.act = int(data.get("act", 0))
	run.current_node = int(data.get("current_node", -1))
	run.money = int(data.get("money", 0))
	run.first_combat_played = bool(data.get("first_combat_played", true))
	run.minigame_penalty = bool(data.get("minigame_penalty", false))
	run.harder_fight = bool(data.get("harder_fight", false))
	run.penalty_text = str(data.get("penalty_text", ""))

	run.deck.clear()
	run.deck_equipment.clear()
	run.deck_finish.clear()
	run.deck_upgrade.clear()
	var deck_paths: Array = data.get("deck", [])
	for i in deck_paths.size():
		var figure = _load(deck_paths[i])
		run.deck.append(figure if figure is FigureData else run.config.starting_figure)
		run.deck_equipment.append(_item(data, "deck_equipment", i, EquipmentData))
		run.deck_finish.append(_item(data, "deck_finish", i, FinishData))
		run.deck_upgrade.append(_item(data, "deck_upgrade", i, UpgradeData))
	run.picked_figures.clear()
	for path in data.get("picked", []):
		var picked = _load(path)
		if picked is FigureData:
			run.picked_figures.append(picked)
	run.equipment_inventory.clear()
	for path in data.get("equipment_inventory", []):
		var item = _load(path)
		if item is EquipmentData:
			run.equipment_inventory.append(item)
	run.relics.clear()
	for path in data.get("relics", []):
		var relic = _load(path)
		if relic is RelicData:
			run.relics.append(relic)  # (not add_relic: on_acquired effects are already in the saved deck etc.)
	run.powers.clear()
	for path in data.get("powers", []):
		var power = _load(path)
		run.powers.append(power if power is PowerData else null)
	while run.powers.size() < run.config.power_slots:
		run.powers.append(null)
	run.act_bosses.clear()
	for path in data.get("act_bosses", []):
		var boss = _load(path)
		if boss is BossData:
			run.act_bosses.append(boss)
	run.used_encounters.clear()
	for path in data.get("used_encounters", []):
		var encounter = _load(path)
		if encounter is EncounterData:
			run.used_encounters.append(encounter)
	run.used_events.clear()
	for path in data.get("used_events", []):
		var event = _load(path)
		if event is EventData:
			run.used_events.append(event)
	var arena = _load(data.get("arena", ""))
	run.arena = arena if arena is ArenaData else null

	var map_data: Dictionary = data.get("map", {})
	var map := ActMap.new()
	map.columns = int(map_data.get("columns", 6))
	map.lanes = int(map_data.get("lanes", 4))
	map.boss_id = int(map_data.get("boss_id", -1))
	for entry in map_data.get("nodes", []):
		var node := MapNode.new()
		node.id = int(entry.id)
		node.column = int(entry.column)
		node.lane = int(entry.lane)
		node.type = int(entry.type)
		node.visited = bool(entry.visited)
		for target in entry.next:
			node.next.append(int(target))
		map.nodes.append(node)
	if map.nodes.is_empty() or run.deck.is_empty() or run.act_bosses.size() <= run.act:
		return -2  # a damaged save
	run.map = map
	return int(data.get("pending_node", -1))


static func _read() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and int(parsed.get("version", 0)) == VERSION:
		return parsed
	return {}


static func _path(resource: Resource) -> String:
	if resource == null:
		return ""
	if resource.resource_path == "":
		push_warning("[save] a resource without a file path was not saved: %s" % resource)
	return resource.resource_path


static func _paths(list: Array) -> Array:
	var paths := []
	for resource in list:
		paths.append(_path(resource))
	return paths


static func _load(path) -> Resource:
	if path is String and path != "" and ResourceLoader.exists(path):
		return load(path)
	return null


static func _item(data: Dictionary, key: String, index: int, type) -> Resource:
	var paths: Array = data.get(key, [])
	if index >= paths.size():
		return null
	var item := _load(paths[index])
	return item if is_instance_of(item, type) else null
