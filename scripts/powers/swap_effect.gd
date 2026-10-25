class_name SwapEffect
extends PowerEffect
## Tap two figures: they swap positions.


func _init() -> void:
	target_mode = Target.TWO_FIGURES
	settle_after = true
	prompt = "Tap the first figure"


func apply(main, targets: Array) -> bool:
	main.swap_figures(targets[0], targets[1])
	return true
