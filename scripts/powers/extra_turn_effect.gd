class_name ExtraTurnEffect
extends PowerEffect
## Take another flick right away: after your next flick settles, you flick again before the
## enemy gets to act.

## How many extra flicks it gives.
@export var extra_flicks := 1


func apply(main, _targets: Array) -> bool:
	main.extra_turns += extra_flicks
	return true
