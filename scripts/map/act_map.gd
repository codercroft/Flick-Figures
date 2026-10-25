class_name ActMap
extends RefCounted
## One act's branching map (Slay the Spire style): columns of nodes, paths between them, 2-3
## choices per step, all converging on the boss. Built by ActMap.generate().

var columns := 6
var lanes := 4
var nodes: Array[MapNode] = []
var boss_id := -1


## Ids of the nodes in a column.
func column_ids(column: int) -> Array[int]:
	var ids: Array[int] = []
	for node in nodes:
		if node.column == column:
			ids.append(node.id)
	return ids


func boss() -> MapNode:
	return nodes[boss_id]


## The fewest shops on any path from the start to the boss (every path has one if this is >= 1).
func min_shops_on_any_path() -> int:
	var best := {}  # node id -> fewest shops on a path from the start to it
	for column in columns + 1:
		for id in column_ids(column):
			var node := nodes[id]
			var own := 1 if node.type == MapNode.Type.SHOP else 0
			if column == 0:
				best[id] = own
			else:
				var fewest := 999
				for other in nodes:
					if other.column == column - 1 and other.next.has(id) and best.has(other.id):
						fewest = mini(fewest, best[other.id])
				best[id] = own + (fewest if fewest != 999 else 0)
	return best[boss_id]


## True if no node is a dead end of elites: from every node at least one next step is not an elite.
func elites_are_optional() -> bool:
	for node in nodes:
		if node.next.is_empty():
			continue
		var has_other := false
		for id in node.next:
			if nodes[id].type != MapNode.Type.ELITE:
				has_other = true
		if not has_other:
			return false
	return true


static func generate(config: MapConfig, rng: RandomNumberGenerator = null) -> ActMap:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var map := ActMap.new()
	map.columns = config.columns
	map.lanes = config.lanes
	# 1. Which lanes exist in each column (at most one missing, never in the first column).
	var grid: Array = []  # grid[column][lane] = node id or -1
	for column in config.columns:
		var missing := -1
		if column > 0 and rng.randf() < config.missing_lane_chance:
			missing = rng.randi_range(0, config.lanes - 1)
		var row: Array[int] = []
		for lane in config.lanes:
			if lane == missing:
				row.append(-1)
				continue
			var node := MapNode.new()
			node.id = map.nodes.size()
			node.column = column
			node.lane = lane
			map.nodes.append(node)
			row.append(node.id)
		grid.append(row)
	# 2. Paths forward: each node picks 2-3 nodes of the next column within one lane. Lines that
	# would cross another line are only used when needed to reach the minimum number of choices.
	for column in config.columns - 1:
		var chosen := {}  # "from_lane>to_lane" -> true, to avoid crossing lines
		for lane in config.lanes:
			var from_id: int = grid[column][lane]
			if from_id == -1:
				continue
			var clear: Array[int] = []
			var crossing: Array[int] = []
			for target in [lane - 1, lane, lane + 1]:
				if target >= 0 and target < config.lanes and grid[column + 1][target] != -1:
					# A line lane -> lane-1 would cross the line (lane-1) -> lane.
					if target == lane - 1 and chosen.has("%d>%d" % [lane - 1, lane]):
						crossing.append(target)
					else:
						clear.append(target)
			clear.shuffle()
			var options: Array[int] = clear + crossing
			var want := clampi(rng.randi_range(config.min_choices, config.max_choices), 1, options.size())
			for i in want:
				map.nodes[from_id].next.append(grid[column + 1][options[i]])
				chosen["%d>%d" % [lane, options[i]]] = true
		# Every node of the next column needs a way in.
		for lane in config.lanes:
			var to_id: int = grid[column + 1][lane]
			if to_id == -1 or _has_incoming(map, column, to_id):
				continue
			for source_lane in [lane, lane - 1, lane + 1]:
				if source_lane >= 0 and source_lane < config.lanes and grid[column][source_lane] != -1:
					map.nodes[grid[column][source_lane]].next.append(to_id)
					break
	# 3. The boss: everything in the last column leads to it.
	var boss := MapNode.new()
	boss.id = map.nodes.size()
	boss.column = config.columns
	boss.lane = config.lanes / 2
	boss.type = MapNode.Type.BOSS
	map.nodes.append(boss)
	map.boss_id = boss.id
	for id in map.column_ids(config.columns - 1):
		map.nodes[id].next.append(boss.id)
	map._assign_types(config, rng)
	return map


static func _has_incoming(map: ActMap, column: int, id: int) -> bool:
	for node in map.nodes:
		if node.column == column and node.next.has(id):
			return true
	return false


func _assign_types(config: MapConfig, rng: RandomNumberGenerator) -> void:
	# Whole column of shops: every path crosses it.
	var shop_column := -1
	if not config.shop_columns.is_empty():
		shop_column = config.shop_columns[rng.randi_range(0, config.shop_columns.size() - 1)]
	for node in nodes:
		if node.type == MapNode.Type.BOSS or node.column == 0:
			continue
		if node.column == shop_column:
			node.type = MapNode.Type.SHOP
		elif absi(node.column - shop_column) > 1 and rng.randf() < config.extra_shop_chance:
			node.type = MapNode.Type.SHOP
		elif config.treasure_columns.has(node.column) and rng.randf() < config.treasure_chance:
			node.type = MapNode.Type.TREASURE
		elif node.column >= config.elite_from_column and rng.randf() < config.elite_chance:
			node.type = MapNode.Type.ELITE
	_make_elites_optional()
	# At least one treasure and one elite per act.
	if not _has_type(MapNode.Type.TREASURE):
		_convert_random(MapNode.Type.TREASURE, config.treasure_columns, rng)
	if not _has_type(MapNode.Type.ELITE):
		var later: Array[int] = []
		for column in range(config.elite_from_column, config.columns):
			if column != shop_column:
				later.append(column)
		_convert_random(MapNode.Type.ELITE, later, rng)
		_make_elites_optional()


func _has_type(node_type: MapNode.Type) -> bool:
	for node in nodes:
		if node.type == node_type:
			return true
	return false


## Turns a random plain combat node in one of `columns` into `node_type`.
func _convert_random(node_type: MapNode.Type, allowed_columns: Array[int], rng: RandomNumberGenerator) -> void:
	var candidates: Array[MapNode] = []
	for node in nodes:
		if node.type == MapNode.Type.COMBAT and allowed_columns.has(node.column):
			# An elite must stay optional: every node leading to it needs another way on.
			if node_type == MapNode.Type.ELITE and not _all_parents_have_alternatives(node.id):
				continue
			candidates.append(node)
	if not candidates.is_empty():
		candidates[rng.randi_range(0, candidates.size() - 1)].type = node_type


func _all_parents_have_alternatives(id: int) -> bool:
	for node in nodes:
		if node.next.has(id) and node.next.size() < 2:
			return false
	return true


## Elites are never forced: if all of a node's next steps are elites, one becomes a combat.
func _make_elites_optional() -> void:
	for node in nodes:
		if node.next.is_empty():
			continue
		var all_elite := true
		for id in node.next:
			if nodes[id].type != MapNode.Type.ELITE:
				all_elite = false
		if all_elite:
			nodes[node.next[0]].type = MapNode.Type.COMBAT
