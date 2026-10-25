class_name ExtraPocketEffect
extends RelicEffect
## One more deck slot (a starting figure fills it).

@export var extra_slots := 1


func on_acquired(run) -> void:
	for i in extra_slots:
		run.add_deck_slot()
