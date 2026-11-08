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
## Frenzy path: its first kill each combat recharges an ally.
@export var first_blood_recharge := false
## Predator path: +x knockback against Doused or near-edge opponents; +x knockback for every kill this combat; and an
## ally's kill gives it a bonus flick (once per turn).
@export var predator_edge := 0.0
@export var kill_scaling := 0.0
@export var pack_hunter := false

## "No limit" for get_bloodlust_cap (the chain only ends when a flick gets no kill, or you skip).
const UNLIMITED := 1000000


var _kills := 0
var _first_blood_used := false
var _pack_used := false
var _stacks := 0
var _normal_damp := -1.0


func get_dealt_knockback_bonus(figure: Figure, other: Figure) -> float:
	var bonus := kill_scaling * _kills
	if predator_edge > 0.0:
		var main := figure.get_tree().current_scene
		var near_edge := false
		if main != null and "board" in main:
			var table: Rect2 = main.board.get_table_rect()
			near_edge = not table.grow(-150.0).has_point(other.global_position)
		if other.is_doused() or near_edge:
			bonus += predator_edge
	return bonus


## Pack Hunter: an ally's knock-off gives it a bonus flick (once per turn).
func on_opponent_knocked_off(figure: Figure, _victim: Figure) -> void:
	var main := figure.get_tree().current_scene
	if not pack_hunter or _pack_used or main == null or not ("_flicker" in main):
		return
	var flicker = main._flicker
	if is_instance_valid(flicker) and flicker != figure and flicker.team == figure.team and main.has_method("grant_bonus_flick"):
		_pack_used = true
		main.grant_bonus_flick(figure)


func on_turn_ended(figure: Figure) -> void:
	var main := figure.get_tree().current_scene
	if main != null and "turret_side" in main and main.turret_side != figure.team:
		_pack_used = false


func on_bloodlust_bonus(figure: Figure) -> void:
	_kills += 1
	if first_blood_recharge and not _first_blood_used:
		_first_blood_used = true
		_recharge_an_ally(figure)
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


## First Blood: one teammate that already went (or an enemy that already flicked) can act again.
func _recharge_an_ally(figure: Figure) -> void:
	var main := figure.get_tree().current_scene
	if main == null or not main.has_method("recharge_figure"):
		return
	for node in figure.get_tree().get_nodes_in_group("figures"):
		var ally := node as Figure
		if ally == null or ally == figure or ally.knocked_off or ally.team != figure.team:
			continue
		var spent: bool = (not ally.flickable) if ally.team == Figure.Team.PLAYER else main._enemy_cycle.has(ally.get_instance_id())
		if spent:
			main.recharge_figure(ally)
			ally.show_popup("First blood!", Color(1.0, 0.4, 0.4))
			return
