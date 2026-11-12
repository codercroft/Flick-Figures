class_name CombinedAbility
extends FigureAbility
## Runs two abilities as one: a figure's own ability plus its equipment's effect. Events go to
## both, multipliers are multiplied, and the first ability that saves a figure from falling off wins.

var first: FigureAbility
var second: FigureAbility


func _init(a: FigureAbility = null, b: FigureAbility = null) -> void:
	first = a
	second = b


func on_flicked(figure: Figure, impulse: Vector2) -> void:
	first.on_flicked(figure, impulse)
	second.on_flicked(figure, impulse)


func on_hit(figure: Figure, other: Figure) -> void:
	first.on_hit(figure, other)
	second.on_hit(figure, other)


func on_impact(figure: Figure, other: Figure, speed: float, point: Vector2) -> void:
	first.on_impact(figure, other, speed, point)
	second.on_impact(figure, other, speed, point)


func on_stopped(figure: Figure) -> void:
	first.on_stopped(figure)
	second.on_stopped(figure)


func on_exploded(figure: Figure, source: Figure) -> void:
	first.on_exploded(figure, source)
	second.on_exploded(figure, source)


func on_physics_process(figure: Figure, delta: float) -> void:
	first.on_physics_process(figure, delta)
	second.on_physics_process(figure, delta)


func on_knocked_off(figure: Figure) -> void:
	first.on_knocked_off(figure)
	second.on_knocked_off(figure)


func on_left_table(figure: Figure, table: Rect2) -> bool:
	return first.on_left_table(figure, table) or second.on_left_table(figure, table)


func get_knockback_multiplier(figure: Figure, source: Figure) -> float:
	return first.get_knockback_multiplier(figure, source) * second.get_knockback_multiplier(figure, source)


func get_explosion_multiplier(figure: Figure, source: Figure) -> float:
	return first.get_explosion_multiplier(figure, source) * second.get_explosion_multiplier(figure, source)


func get_hit_multiplier(figure: Figure, other: Figure, impact_speed: float) -> float:
	return first.get_hit_multiplier(figure, other, impact_speed) * second.get_hit_multiplier(figure, other, impact_speed)


func get_flick_power_multiplier(figure: Figure) -> float:
	return first.get_flick_power_multiplier(figure) * second.get_flick_power_multiplier(figure)


func get_flicks_per_turn(figure: Figure) -> int:
	return maxi(first.get_flicks_per_turn(figure), second.get_flicks_per_turn(figure))


func get_incoming_aim_error_degrees(figure: Figure) -> float:
	return first.get_incoming_aim_error_degrees(figure) + second.get_incoming_aim_error_degrees(figure)


func on_hit_wall(figure: Figure, body: Node) -> void:
	first.on_hit_wall(figure, body)
	second.on_hit_wall(figure, body)


func get_wrap_count(figure: Figure) -> int:
	return first.get_wrap_count(figure) + second.get_wrap_count(figure)


func is_plowing(figure: Figure) -> bool:
	return first.is_plowing(figure) or second.is_plowing(figure)


func get_aura_radius(figure: Figure) -> float:
	return maxf(first.get_aura_radius(figure), second.get_aura_radius(figure))


func get_shot_stats(figure: Figure) -> Dictionary:
	var stats := first.get_shot_stats(figure)
	return stats if not stats.is_empty() else second.get_shot_stats(figure)


func fire_shot_at(figure: Figure, point: Vector2) -> void:
	first.fire_shot_at(figure, point)
	second.fire_shot_at(figure, point)


func get_zone_stats(figure: Figure) -> Dictionary:
	var stats := first.get_zone_stats(figure)
	return stats if not stats.is_empty() else second.get_zone_stats(figure)


func recharges_first_ally(figure: Figure) -> bool:
	return first.recharges_first_ally(figure) or second.recharges_first_ally(figure)


func eats_smaller(figure: Figure) -> bool:
	return first.eats_smaller(figure) or second.eats_smaller(figure)


func wants_ally_food(figure: Figure) -> bool:
	return first.wants_ally_food(figure) or second.wants_ally_food(figure)


func get_bloodlust_cap(figure: Figure) -> int:
	return maxi(first.get_bloodlust_cap(figure), second.get_bloodlust_cap(figure))


func has_active_wall(figure: Figure) -> bool:
	return first.has_active_wall(figure) or second.has_active_wall(figure)


func on_took_explosion(figure: Figure, impulse: Vector2) -> void:
	first.on_took_explosion(figure, impulse)
	second.on_took_explosion(figure, impulse)


func draw_overlay(figure: Figure) -> void:
	first.draw_overlay(figure)
	second.draw_overlay(figure)


func get_shell_state(figure: Figure) -> Dictionary:
	var state := first.get_shell_state(figure)
	return state if not state.is_empty() else second.get_shell_state(figure)


func predict_shell_damage(figure: Figure, shooter: Figure, closing_speed: float) -> float:
	return first.predict_shell_damage(figure, shooter, closing_speed) + second.predict_shell_damage(figure, shooter, closing_speed)


func detonate(figure: Figure) -> void:
	first.detonate(figure)
	second.detonate(figure)


func get_rally_speed(figure: Figure) -> float:
	return maxf(first.get_rally_speed(figure), second.get_rally_speed(figure))


func sets_off_team_explosives(figure: Figure) -> bool:
	return first.sets_off_team_explosives(figure) or second.sets_off_team_explosives(figure)


func get_glue_chain_cap(figure: Figure) -> int:
	return maxi(first.get_glue_chain_cap(figure), second.get_glue_chain_cap(figure))


func get_bummer_stats(figure: Figure) -> Dictionary:
	var stats := first.get_bummer_stats(figure)
	return stats if not stats.is_empty() else second.get_bummer_stats(figure)


func get_aura_flick_multiplier(figure: Figure) -> float:
	return first.get_aura_flick_multiplier(figure) * second.get_aura_flick_multiplier(figure)


func get_aura_knockback_multiplier(figure: Figure) -> float:
	return first.get_aura_knockback_multiplier(figure) * second.get_aura_knockback_multiplier(figure)


func on_opponent_knocked_off(figure: Figure, victim: Figure) -> void:
	first.on_opponent_knocked_off(figure, victim)
	second.on_opponent_knocked_off(figure, victim)


func get_pin_radius(figure: Figure) -> float:
	return maxf(first.get_pin_radius(figure), second.get_pin_radius(figure))


func get_turret_stats(figure: Figure) -> Dictionary:
	var stats := first.get_turret_stats(figure)
	return stats if not stats.is_empty() else second.get_turret_stats(figure)


func get_reverse_stats(figure: Figure) -> Dictionary:
	var stats := first.get_reverse_stats(figure)
	return stats if not stats.is_empty() else second.get_reverse_stats(figure)


func can_reverse(figure: Figure) -> bool:
	return first.can_reverse(figure) or second.can_reverse(figure)


func use_reverse(figure: Figure, direction := Vector2.ZERO) -> bool:
	if first.can_reverse(figure):
		return first.use_reverse(figure, direction)
	return second.use_reverse(figure, direction)


func get_ai_shield(figure: Figure) -> Dictionary:
	var info := first.get_ai_shield(figure)
	return info if not info.is_empty() else second.get_ai_shield(figure)


func get_mine_stats(figure: Figure) -> Dictionary:
	var stats := first.get_mine_stats(figure)
	return stats if not stats.is_empty() else second.get_mine_stats(figure)


func get_ai_blast(figure: Figure) -> Dictionary:
	var blast := first.get_ai_blast(figure)
	return blast if not blast.is_empty() else second.get_ai_blast(figure)


func has_path_pull(figure: Figure) -> bool:
	return first.has_path_pull(figure) or second.has_path_pull(figure)


func get_path_pull(figure: Figure, point: Vector2, mover_team := -1) -> Vector2:
	return first.get_path_pull(figure, point, mover_team) + second.get_path_pull(figure, point, mover_team)


func get_flick_bounce(figure: Figure) -> float:
	var a := first.get_flick_bounce(figure)
	var b := second.get_flick_bounce(figure)
	return a if b < 0.0 else (b if a < 0.0 else minf(a, b))


func cancels_rebound(figure: Figure) -> bool:
	return first.cancels_rebound(figure) or second.cancels_rebound(figure)


func setup_body(figure: Figure) -> void:
	first.setup_body(figure)
	second.setup_body(figure)


func draw_body(figure: Figure) -> void:
	first.draw_body(figure)
	second.draw_body(figure)


func on_shape_hit(figure: Figure, other: Figure, shape_node: Node, speed: float) -> void:
	first.on_shape_hit(figure, other, shape_node, speed)
	second.on_shape_hit(figure, other, shape_node, speed)


func get_hit_mass_multiplier(figure: Figure) -> float:
	return first.get_hit_mass_multiplier(figure) * second.get_hit_mass_multiplier(figure)


func draws_own_body(figure: Figure) -> bool:
	return first.draws_own_body(figure) or second.draws_own_body(figure)


func draws_own_label(figure: Figure) -> bool:
	return first.draws_own_label(figure) or second.draws_own_label(figure)


func on_turn_ended(figure: Figure) -> void:
	first.on_turn_ended(figure)
	second.on_turn_ended(figure)


func get_ai_aggro(figure: Figure) -> Dictionary:
	var info := first.get_ai_aggro(figure)
	return info if not info.is_empty() else second.get_ai_aggro(figure)





func on_bloodlust_bonus(figure: Figure) -> void:
	first.on_bloodlust_bonus(figure)
	second.on_bloodlust_bonus(figure)


func on_became_flickable(figure: Figure) -> void:
	first.on_became_flickable(figure)
	second.on_became_flickable(figure)


func on_round_ticked(figure: Figure) -> void:
	first.on_round_ticked(figure)
	second.on_round_ticked(figure)


func get_toss_stats(figure: Figure) -> Dictionary:
	var stats := first.get_toss_stats(figure)
	return stats if not stats.is_empty() else second.get_toss_stats(figure)


func accept_rejoin(figure: Figure, at: Vector2) -> bool:
	return first.accept_rejoin(figure, at) or second.accept_rejoin(figure, at)


func get_rejoin_target(figure: Figure) -> Figure:
	var target := first.get_rejoin_target(figure)
	return target if target != null else second.get_rejoin_target(figure)


func get_spray_stats(figure: Figure) -> Dictionary:
	var stats := first.get_spray_stats(figure)
	return stats if not stats.is_empty() else second.get_spray_stats(figure)


func set_spray(figure: Figure, active: bool, point := Vector2.ZERO) -> void:
	first.set_spray(figure, active, point)
	second.set_spray(figure, active, point)


func get_absorb_speed(figure: Figure) -> float:
	return maxf(first.get_absorb_speed(figure), second.get_absorb_speed(figure))


func get_escape_speed(figure: Figure) -> float:
	return maxf(first.get_escape_speed(figure), second.get_escape_speed(figure))


func get_held_figure(figure: Figure) -> Figure:
	var held := first.get_held_figure(figure)
	return held if held != null else second.get_held_figure(figure)


func get_dealt_knockback_bonus(figure: Figure, other: Figure) -> float:
	return first.get_dealt_knockback_bonus(figure, other) + second.get_dealt_knockback_bonus(figure, other)


func get_enemy_aura(figure: Figure) -> Dictionary:
	var aura := first.get_enemy_aura(figure)
	return aura if not aura.is_empty() else second.get_enemy_aura(figure)


func get_tap_ability(figure: Figure) -> Dictionary:
	var tap := first.get_tap_ability(figure)
	return tap if not tap.is_empty() else second.get_tap_ability(figure)


func use_tap_ability(figure: Figure, point: Vector2) -> bool:
	if not first.get_tap_ability(figure).is_empty():
		return first.use_tap_ability(figure, point)
	return second.use_tap_ability(figure, point)


func get_reward_choice_bonus(figure: Figure) -> int:
	return first.get_reward_choice_bonus(figure) + second.get_reward_choice_bonus(figure)


func on_projectile_hit(figure: Figure, target: Figure, direction := Vector2.ZERO) -> void:
	first.on_projectile_hit(figure, target, direction)
	second.on_projectile_hit(figure, target, direction)


func get_stuck_enemy_flick_multiplier(figure: Figure) -> float:
	return first.get_stuck_enemy_flick_multiplier(figure) * second.get_stuck_enemy_flick_multiplier(figure)





func get_pin_options(figure: Figure) -> Dictionary:
	var options := first.get_pin_options(figure)
	return options if not options.is_empty() else second.get_pin_options(figure)


func ai_wants_tap(figure: Figure, opponents: Array) -> bool:
	return first.ai_wants_tap(figure, opponents) or second.ai_wants_tap(figure, opponents)


func ai_tap_point(figure: Figure, opponents: Array) -> Vector2:
	var point := first.ai_tap_point(figure, opponents)
	return point if point != Vector2.INF else second.ai_tap_point(figure, opponents)
