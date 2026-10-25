class_name MapNode
extends RefCounted
## One stop on an act's map.

enum Type { COMBAT, ELITE, SHOP, TREASURE, BOSS }

var id := 0
var column := 0
var lane := 0
var type := Type.COMBAT
## Ids of the nodes you can go to next from here.
var next: Array[int] = []
var visited := false


static func type_name(node_type: Type) -> String:
	return ["Combat", "Elite", "Shop", "Treasure", "Boss"][node_type]
