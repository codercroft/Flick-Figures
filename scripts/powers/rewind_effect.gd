class_name RewindEffect
extends PowerEffect
## Undoes your last flick: every figure goes back to where it was before it.


func can_use(main) -> String:
	return "" if main.can_rewind() else "Nothing to rewind yet"


func apply(main, _targets: Array) -> bool:
	return main.rewind()
