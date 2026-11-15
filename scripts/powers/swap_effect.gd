class_name SwapEffect
extends PowerEffect
## Tap two figures: they swap positions (both stop). Tap the first again to unselect it, tap empty space to cancel.


func _init() -> void:
	target_mode = Target.TWO_FIGURES
	settle_after = true
	prompt = "Swap: tap the first figure"


func target_problem(_main, figure, _first) -> String:
	if figure.is_glued():
		return "Glued figures can't be swapped"
	if figure.is_frozen():
		return "Frozen figures can't be swapped"
	return ""


func apply(main, targets: Array) -> bool:
	if targets.size() != 2 or targets[0] == targets[1]:
		return false
	return main.swap_figures(targets[0], targets[1])
