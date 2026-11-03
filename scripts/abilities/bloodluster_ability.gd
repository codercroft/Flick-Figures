class_name BloodlusterAbility
extends FigureAbility
## If its flick knocks an opposing figure off the table (any knock-off that flick causes, knock-on hits included)
## it can be flicked again right away from where it stopped, before the other side moves; the player may tap to
## skip it. It chains for as long as each flick gets a kill (no cap). No bonus if Bloodluster itself was knocked
## off. Bonus flicks do not count against the flick cycle (it is only marked flicked once).
## Each kill that earns a bonus flick adds a stack of linear damping, so the chain travels less and less far.
## The stacks reset at the start of every round and whenever it becomes flickable again.

## Extra damping per stack (0.35 = +35% of its normal damping per stack).
@export var damping_per_stack := 0.35
@export var pip_color := Color(1.0, 0.3, 0.3)

## "No limit" for get_bloodlust_cap (the chain only ends when a flick gets no kill, or you skip).
const UNLIMITED := 1000000


var _stacks := 0
var _normal_damp := -1.0


func on_bloodlust_bonus(figure: Figure) -> void:
	if _stacks == 0:
		_normal_damp = figure.linear_damp
	_stacks += 1
	figure.linear_damp = _normal_damp * (1.0 + damping_per_stack * _stacks)
	figure.queue_redraw()


func on_became_flickable(figure: Figure) -> void:
	_reset(figure)


func on_round_ticked(figure: Figure) -> void:
	_reset(figure)


func _reset(figure: Figure) -> void:
	if _stacks == 0:
		return
	_stacks = 0
	figure.linear_damp = _normal_damp
	figure.queue_redraw()


## One red pip per stack above the figure, and the label of the damping it adds.
func draw_overlay(figure: Figure) -> void:
	var spacing := 22.0
	var start_x := -spacing * (_stacks - 1) / 2.0
	for i in _stacks:
		figure.draw_circle(Vector2(start_x + spacing * i, -figure.radius - 18.0), 8.0, pip_color)
	if _stacks > 0:
		figure.draw_circle(Vector2.ZERO, figure.radius, Color(pip_color, 0.12 * _stacks))


func get_bloodlust_cap(_figure: Figure) -> int:
	return UNLIMITED
