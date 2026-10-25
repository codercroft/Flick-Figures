class_name FigureRegistry
extends Resource
## Which figures exist and how a run may use them. A figure can be in both lists.

## Basic figures: the enemy side's filler, and what the player's deck starts with.
@export var grunts: Array[FigureData] = []
## Figures the player can be offered in a draft.
@export var draftable: Array[FigureData] = []
## The "economy" tag: figures that only make sense for the player (like Cha-ching). They can be
## drafted or sold, but are never put in an enemy lineup.
@export var economy: Array[FigureData] = []


## Boss figures, one of which a run picks to end on.
@export var bosses: Array[BossData] = []


func random_grunt() -> FigureData:
	return grunts.pick_random() if not grunts.is_empty() else null


## `count` different bosses (repeats only if there are fewer bosses than that).
func random_bosses(count: int) -> Array[BossData]:
	var pool := bosses.duplicate()
	pool.shuffle()
	var picked: Array[BossData] = []
	for i in count:
		if pool.is_empty():
			break
		picked.append(pool.pop_back())
	while picked.size() < count and not bosses.is_empty():
		picked.append(bosses.pick_random())
	return picked


func random_boss() -> BossData:
	return bosses.pick_random() if not bosses.is_empty() else null


## Up to `count` different figures for an enemy lineup: draftable, not grunts, not economy.
func random_non_grunts(count: int) -> Array[FigureData]:
	var pool: Array[FigureData] = []
	for figure in draftable:
		if not grunts.has(figure) and not economy.has(figure):
			pool.append(figure)
	pool.shuffle()
	return pool.slice(0, count)


## Up to `count` different draftable figures, skipping any in `exclude`.
func random_draftable(count: int, exclude: Array[FigureData] = []) -> Array[FigureData]:
	var pool: Array[FigureData] = []
	for figure in draftable:
		if not exclude.has(figure):
			pool.append(figure)
	pool.shuffle()
	return pool.slice(0, count)


## Up to `count` different draftable figures, with rarity weights (common, uncommon, rare): each pick
## first rolls a rarity by weight, then takes a random figure of that rarity (rarities with no
## figures left are skipped).
func random_draftable_weighted(count: int, weights: Vector3, exclude: Array[FigureData] = []) -> Array[FigureData]:
	var by_rarity: Array = [[], [], []]
	for figure in draftable:
		if not exclude.has(figure):
			by_rarity[clampi(figure.rarity, 0, 2)].append(figure)
	for list in by_rarity:
		list.shuffle()
	var picked: Array[FigureData] = []
	while picked.size() < count:
		var total := 0.0
		for rarity in 3:
			if not by_rarity[rarity].is_empty():
				total += maxf(weights[rarity], 0.0)
		var choice := -1
		if total > 0.0:
			var roll := randf() * total
			for rarity in 3:
				if by_rarity[rarity].is_empty():
					continue
				roll -= maxf(weights[rarity], 0.0)
				if roll <= 0.0:
					choice = rarity
					break
		if choice == -1:  # all weights are zero (or rounding): take whatever is left
			for rarity in 3:
				if not by_rarity[rarity].is_empty():
					choice = rarity
					break
		if choice == -1:
			break
		picked.append(by_rarity[choice].pop_back())
	return picked


func is_grunt(figure: FigureData) -> bool:
	return grunts.has(figure)


func is_draftable(figure: FigureData) -> bool:
	return draftable.has(figure)


func is_economy(figure: FigureData) -> bool:
	return economy.has(figure)
