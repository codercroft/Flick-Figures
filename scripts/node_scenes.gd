class_name NodeScenes
extends RefCounted
## Which scene a map node opens, shared by the map screen and the main menu's Continue.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const MAP_SCENE := "res://scenes/map.tscn"
const COMBAT_SCENE := "res://scenes/main.tscn"
const SHOP_SCENE := "res://scenes/shop.tscn"
const REWARD_SCENE := "res://scenes/reward.tscn"


## Opens the scene for `RunManager.node` (already entered with RunManager.enter_node).
static func open_current_node(tree: SceneTree) -> void:
	match RunManager.node.type:
		MapNode.Type.SHOP:
			tree.change_scene_to_file(SHOP_SCENE)
		MapNode.Type.TREASURE:
			tree.change_scene_to_file(REWARD_SCENE)
		MapNode.Type.EVENT:
			if RunManager.event != null and RunManager.event.scene != null:
				tree.change_scene_to_packed(RunManager.event.scene)
			else:
				RunManager.finish_node()  # no event available: the stop is simply passed
				tree.change_scene_to_file(MAP_SCENE)
		_:
			tree.change_scene_to_file(COMBAT_SCENE)
