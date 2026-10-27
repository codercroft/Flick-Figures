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
	# Rarely a layout has no way to cover every path with a few shops; just roll another one.
	for attempt in 200:
		var map := _generate_once(config, rng)
		if map != null:
			return map
	push_warning("ActMap: no valid layout in 200 tries, using the last one")
	return _generate_once(config, rng, true)


static func _generate_once(config: MapConfig, rng: RandomNumberGenerator, force := false) -> ActMap:
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
	if not map._assign_types(config, rng) and not force:
		return null
	return map


static func _has_incoming(map: ActMap, column: int, id: int) -> bool:
	for node in map.nodes:
		if node.column == column and node.next.has(id):
			return true
	return false


## Gives every node its type. Returns false if no shop placement covers every path.
func _assign_types(config: MapConfig, rng: RandomNumberGenerator) -> bool:
	# The chest row: ONE whole column of chests, so every path passes exactly one chest.
	var chest_column := clampi(config.chest_column, 1, columns - 1)
	for node in nodes:
		if node.column == chest_column and node.type != MapNode.Type.BOSS:
			node.type = MapNode.Type.TREASURE
	# Shops: a few random nodes that together sit on every path.
	var eligible: Array[int] = []
	for node in nodes:
		if node.column >= 1 and node.column != chest_column and node.type != MapNode.Type.BOSS:
			eligible.append(node.id)
	var shops := _random_shop_cover(eligible, config.shop_count_min, config.shop_count_max, rng)
	if shops.is_empty():
		return false
	for id in shops:
		nodes[id].type = MapNode.Type.SHOP
	# Elites: only from the middle on, never forced, at least one per act.
	for node in nodes:
		if node.type == MapNode.Type.COMBAT and node.column >= config.elite_from_column \
				and rng.randf() < config.elite_chance:
			node.type = MapNode.Type.ELITE
	_make_elites_optional()
	if not _has_type(MapNode.Type.ELITE):
		var later: Array[int] = []
		for column in range(config.elite_from_column, columns):
			later.append(column)
		_convert_random(MapNode.Type.ELITE, later, rng)
		_make_elites_optional()
	return true


## A random set of `min_count` to `max_count` of the `eligible` nodes such that every path from the
## start to the boss passes at least one of them. Empty if there is none.
func _random_shop_cover(eligible: Array[int], min_count: int, max_count: int, rng: RandomNumberGenerator) -> Array[int]:
	var by_size := {}  # set size -> every covering set of that size
	var pick: Array[int] = []
	_collect_covers(eligible, 0, pick, clampi(max_count, 1, 4), by_size)
	var sizes: Array[int] = []
	for size in by_size:
		if size >= min_count:
			sizes.append(size)
	if sizes.is_empty():
		return []
	var covers: Array = by_size[sizes[rng.randi_range(0, sizes.size() - 1)]]
	var chosen: Array = covers[rng.randi_range(0, covers.size() - 1)]
	var result: Array[int] = []
	result.assign(chosen)
	return result


func _collect_covers(eligible: Array[int], start: int, pick: Array[int], max_count: int, by_size: Dictionary) -> void:
	if not pick.is_empty() and _covers_every_path(pick):
		if not by_size.has(pick.size()):
			by_size[pick.size()] = []
		by_size[pick.size()].append(pick.duplicate())
		return  # adding more nodes to a covering set would only be a bigger version of it
	if pick.size() >= max_count:
		return
	for i in range(start, eligible.size()):
		pick.append(eligible[i])
		_collect_covers(eligible, i + 1, pick, max_count, by_size)
		pick.pop_back()


## True if the boss cannot be reached from the start without passing one of `blocked` nodes.
func _covers_every_path(blocked: Array[int]) -> bool:
	var open := {}
	for id in column_ids(0):
		open[id] = true
	for column in columns:
		for id in column_ids(column):
			if not open.has(id):
				continue
			for next_id in nodes[id].next:
				if not blocked.has(next_id):
					open[next_id] = true
	return not open.has(boss_id)


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
