class_name UpgradeTree
extends Resource
## A figure's upgrade tree: two paths of three tiers. A figure's first upgrade picks its path (tier 1 of one path
## locks the other path); tiers are taken in order. Files: resources/upgrades/<figure>/tree.tres, listed in
## RunConfig.upgrade_trees.

@export var figure: FigureData
@export var path_a_name := "Path A"
@export var path_b_name := "Path B"
## Three tiers each, in order.
@export var path_a: Array[UpgradeData] = []
@export var path_b: Array[UpgradeData] = []


## The tiers of path 0 (A) or 1 (B).
func tiers(path: int) -> Array[UpgradeData]:
	return path_a if path == 0 else path_b


func path_name(path: int) -> String:
	return path_a_name if path == 0 else path_b_name
