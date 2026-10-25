class_name FigureRegistry
extends Resource
## Which figures exist and how a run may use them. A figure can be in both lists.

## Basic figures the enemy side fields.
@export var grunts: Array[FigureData] = []
## Figures the player can be offered in a draft.
@export var draftable: Array[FigureData] = []


func random_grunt() -> FigureData:
	return grunts.pick_random() if not grunts.is_empty() else null


## Up to `count` different draftable figures, skipping any in `exclude`.
func random_draftable(count: int, exclude: Array[FigureData] = []) -> Array[FigureData]:
	var pool: Array[FigureData] = []
	for figure in draftable:
		if not exclude.has(figure):
			pool.append(figure)
	pool.shuffle()
	return pool.slice(0, count)


func is_grunt(figure: FigureData) -> bool:
	return grunts.has(figure)


func is_draftable(figure: FigureData) -> bool:
	return draftable.has(figure)
