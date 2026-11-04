class_name CostumeChangeEffect
extends RelicEffect
## Lets you equip, unequip and swap equipment in the Inventory during combat (own turn, nothing moving).
## It costs no flick. RunManager.equipment_change_allowed() and Main.can_swap_equipment() do the checking.


func enables_combat_equip() -> bool:
	return true
