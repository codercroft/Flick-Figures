class_name FigureAbility
extends Resource
## Base class for figure abilities. Make a new ability by extending this script and
## overriding any of the hooks below. There are event hooks (on_*) and one modifier hook. Every figure gets its own copy of its ability,
## so it is safe to keep per-figure state in variables.


## This figure was just flicked (by the player or an enemy).
func on_flicked(_figure: Figure, _impulse: Vector2) -> void:
	pass


## This figure bumped into another figure. Called on both figures involved.
func on_hit(_figure: Figure, _other: Figure) -> void:
	pass


## This figure hit another figure at `speed` px/s (relative speed just before the hit) at `point`.
## Called on both figures involved. Like on_hit, but with how hard it was.
func on_impact(_figure: Figure, _other: Figure, _speed: float, _point: Vector2) -> void:
	pass


## This figure was moving and has now come to rest.
func on_stopped(_figure: Figure) -> void:
	pass


## This figure was pushed by an explosion set off by `source`.
func on_exploded(_figure: Figure, _source: Figure) -> void:
	pass


## Called every physics frame (for abilities that act continuously, like a magnet).
func on_physics_process(_figure: Figure, _delta: float) -> void:
	pass


## Modifier, not an event: how much knockback `figure` takes from `source` (a figure that hit
## it or exploded next to it; null if unknown). 1.0 = normal, 2.0 = double.
func get_knockback_multiplier(_figure: Figure, _source: Figure) -> float:
	return 1.0


## Modifier: how much of an explosion's push `figure` takes (applied before the normal push).
## 1.0 = normal, 0.0 = immune. Collisions use get_knockback_multiplier instead.
func get_explosion_multiplier(_figure: Figure, _source: Figure) -> float:
	return 1.0


## Modifier: how much of an explosion's push counts as SHELL damage (Duwall) on `figure`. Separate from
## get_explosion_multiplier, so an explosion-proof figure can still be cracked (1.0 = full, 0.5 = half).
func get_explosion_damage_multiplier(_figure: Figure) -> float:
	return 1.0


## Modifier: how many flicks this figure gets per turn (the extra ones come after the board settles).
func get_flicks_per_turn(_figure: Figure) -> int:
	return 1


## The figure's center just left the table. Return true to save it (e.g. move it back on);
## return false and it is knocked off.
func on_left_table(_figure: Figure, _table: Rect2) -> bool:
	return false


## The figure was knocked off the table (not when it is retired, e.g. a Splitter splitting).
func on_knocked_off(_figure: Figure) -> void:
	pass


## Modifier: multiplies this figure's flick force (Jet Pack's extra flick is half power).
func get_flick_power_multiplier(_figure: Figure) -> float:
	return 1.0


## Modifier: extra aim error (degrees) for enemy shots aimed at this figure (Lucky Charm).
func get_incoming_aim_error_degrees(_figure: Figure) -> float:
	return 0.0


## Extra knockback this figure's hits deal to `other` as a share (0.2 = +20% of the speed the victim gained). Summed
## over abilities; applied by Figure for every figure-on-figure hit.
func get_dealt_knockback_bonus(_figure: Figure, _other: Figure) -> float:
	return 0.0


## An aura that affects OPPOSING figures near this one: {"radius", "knockback" (x taken), "flick" (x flick power)}, or {}.
func get_enemy_aura(_figure: Figure) -> Dictionary:
	return {}


## A tap ability: {"kind": "self" (tap this selected figure again) or "point" (tap empty board), "ready": bool,
## "uses_action": bool (it uses up the figure's action for the cycle), "hint": text}; {} = none. `use_tap_ability`
## runs it and returns true if it happened.
func get_tap_ability(_figure: Figure) -> Dictionary:
	return {}


func use_tap_ability(_figure: Figure, _point: Vector2) -> bool:
	return false


## Pinhead's upgrades: {"per_turn", "max", "permanent", "kick" (x launch), "douse", "explode_radius", "explode_force"}.
func get_pin_options(_figure: Figure) -> Dictionary:
	return {}


## Enemy AI: should this (enemy) figure use its "self" tap ability now, given the player's figures?
func ai_wants_tap(_figure: Figure, _opponents: Array) -> bool:
	return false


## Enemy AI: where this (enemy) figure wants to use its "point" tap ability (Vector2.INF = not now).
func ai_tap_point(_figure: Figure, _opponents: Array) -> Vector2:
	return Vector2.INF


## Extra figure choices after this figure survives a won combat (Cha-ching's Extra Option).
func get_reward_choice_bonus(_figure: Figure) -> int:
	return 0


## A projectile this figure fired hit `target` (a figure).
func on_projectile_hit(_figure: Figure, _target: Figure, _direction := Vector2.ZERO) -> void:
	pass


## Flick-power factor on an OPPOSING figure that is glued to this one (Glue Guy's Tar).
func get_stuck_enemy_flick_multiplier(_figure: Figure) -> float:
	return 1.0


## Helper: sets off every other explosive teammate on the table (the registry's "explosive" tag).
func detonate_allies(figure: Figure) -> void:
	var registry := RunManager.config.registry if RunManager.config != null else null
	if registry == null:
		return
	for node in figure.get_tree().get_nodes_in_group("figures"):
		var other := node as Figure
		if other == figure or other.knocked_off or other.team != figure.team or other.on_deck:
			continue
		if registry.is_explosive(other.base_data):
			other.ability.detonate(other)


## Modifier for collisions only (not explosions): how much of a hit from `other` this figure
## takes, given the relative `impact_speed`. 0 = ignores it (Anchor).
func get_hit_multiplier(_figure: Figure, _other: Figure, _impact_speed: float) -> float:
	return 1.0


## Helper: call from on_impact. Gives the figure `other` that `figure` just hit extra speed equal to
## `bonus` times the speed it gained from the hit (0.4 = +40% knockback). Only when `figure` is
## the one doing the hitting.
func extra_hit_knockback(figure: Figure, other: Figure, bonus: float) -> void:
	var direction := (other.global_position - figure.global_position).normalized()
	if figure._prev_velocity.dot(direction) + other._prev_velocity.dot(direction) <= 0.0:
		return
	other.nudge((other.linear_velocity - other._prev_velocity) * bonus)


## This figure touched a wall, pin or other non-figure body (called deferred).
func on_hit_wall(_figure: Figure, _body: Node) -> void:
	pass


## How many times this figure would wrap around the table edge on a free flight (Ghost, Wings).
## The enemy AI uses it so a wrap isn't treated as falling off.
func get_wrap_count(_figure: Figure) -> int:
	return 0


## True while this figure pushes through what it hits (Pusher during its own flick): it does not
## rebound, so other abilities (Bumper's extra launch) leave it alone.
func is_plowing(_figure: Figure) -> bool:
	return false


## AURA (Crazy Man): a radius (px) around this figure inside which its TEAMMATES get the two
## multipliers below. 0 = no aura. The figure itself is not inside its own aura.
func get_aura_radius(_figure: Figure) -> float:
	return 0.0


## Glue Guy's upgrade: the biggest glue chain (figures stuck together) in which stuck figures also become
## sticky. 0 = this ability does not make glue chains.
func get_glue_chain_cap(_figure: Figure) -> int:
	return 0


## BUMMER AURA: {radius, power, aim_error_degrees, aim_line_scale} (see BummerAbility) or {} for none.
## OPPOSING figures inside the radius flick recklessly.
func get_bummer_stats(_figure: Figure) -> Dictionary:
	return {}


## Aura: flick power multiplier for teammates inside the radius.
func get_aura_flick_multiplier(_figure: Figure) -> float:
	return 1.0


## Aura: multiplier on the knockback teammates inside the radius take (below 1 = tougher).
func get_aura_knockback_multiplier(_figure: Figure) -> float:
	return 1.0


## Called on the player's figures when an ENEMY figure is knocked off the table (Cha-ching pays).
func on_opponent_knocked_off(_figure: Figure, _victim: Figure) -> void:
	pass


## Pinhead: the radius of the temporary pin this figure may place before it is flicked (0 = none).
func get_pin_radius(_figure: Figure) -> float:
	return 0.0


## After this figure's action settles on the player's turn: "spray" (a Spitter may still spray) or "toss" (a Cluster may toss
## another clustling) to offer that, "" for nothing. Called once per offer (the ability remembers it made one).
func wants_post_action(_figure: Figure) -> String:
	return ""


## Wikka Wat: the reverse it may use while moving ({charges_left, per_turn, seek}, {} = none). `can_reverse` says whether it can
## be used right now; `use_reverse(figure, direction)` reverses (or redirects) its momentum. The enemy AI reads these.
func get_reverse_stats(_figure: Figure) -> Dictionary:
	return {}


func can_reverse(_figure: Figure) -> bool:
	return false


func use_reverse(_figure: Figure, _direction := Vector2.ZERO) -> bool:
	return false


## Ultimate Shieldon, for the enemy AI: {arc} while it has a shield mechanic, else {}.
func get_ai_shield(_figure: Figure) -> Dictionary:
	return {}


## Land Miner: the mines it lays while moving ({spacing, trigger_radius, radius, force}, {} = none). The enemy AI reads it.
func get_mine_stats(_figure: Figure) -> Dictionary:
	return {}


## Engineer: the turret this figure may place before it is flicked ({} = none). See EngineerAbility.
func get_turret_stats(_figure: Figure) -> Dictionary:
	return {}


## BLASTOID: the shot this figure may fire instead of flicking ({speed, range, radius, blast_radius,
## blast_force}); {} = none. A tap on the board calls `fire_shot_at`.
func get_shot_stats(_figure: Figure) -> Dictionary:
	return {}


func fire_shot_at(_figure: Figure, _point: Vector2) -> void:
	pass


## ALCHEMIST: the debuff zone this figure may place instead of flicking ({radius, knockback}); {} = none.
func get_zone_stats(_figure: Figure) -> Dictionary:
	return {}


## Energizer, for the AI: the first allied figure it hits during its flick becomes flickable again.
func recharges_first_ally(_figure: Figure) -> bool:
	return false


## Eater, for the AI: eats any figure it touches that is smaller than it.
func eats_smaller(_figure: Figure) -> bool:
	return false


## Eater, for the AI: eating its own smaller teammates is a good thing (The Collector).
func wants_ally_food(_figure: Figure) -> bool:
	return false


## Trangle: true if the ability draws the whole body itself (draw_body), so the usual circle is not drawn.
func draws_own_body(_figure: Figure) -> bool:
	return false


## Cluster: true if the ability draws the figure\'s label / icon itself (or wants none).
func draws_own_label(_figure: Figure) -> bool:
	return false


## Called on every figure when a turn ends (the player's, and the enemy's): per-turn counters reset here.
func on_turn_ended(_figure: Figure) -> void:
	pass


## Aggro-bom, for the enemy AI: {needed, met, radius, force} (collisions it needs, how many it has counted, the
## explosion), or {} for any other figure.
func get_ai_aggro(_figure: Figure) -> Dictionary:
	return {}


## Bloodluster: how many bonus flicks a turn it may earn by knocking opposing figures off (0 = none).
func get_bloodlust_cap(_figure: Figure) -> int:
	return 0


## Shieldon, for the AI: this figure currently has a wall standing (moving it makes the wall vanish).
func has_active_wall(_figure: Figure) -> bool:
	return false


## Duwall: called when an explosion's push reaches this figure (`impulse` is what it delivers).
func on_took_explosion(_figure: Figure, _impulse: Vector2) -> void:
	pass


## Drawn on top of the figure (Duwall's cracks and shell bits).
func draw_overlay(_figure: Figure) -> void:
	pass


## Duwall, for the enemy AI: {remaining, max} shell strength while the shell is intact, else {}.
func get_shell_state(_figure: Figure) -> Dictionary:
	return {}


## Duwall: the shell damage a hit by `shooter` at `closing_speed` would deal to `figure`.
func predict_shell_damage(_figure: Figure, _shooter: Figure, _closing_speed: float) -> float:
	return 0.0


## ENEMY AI HINTS (the AI reads these to plan shots that use abilities; they change nothing in play).

## The explosion this figure is expected to set off, or {}: {"radius", "force", "when"} where when is
## "hit" (on its first hit), "stop" (where it stops, if it touched nothing) .
func get_ai_blast(_figure: Figure) -> Dictionary:
	return {}


## "Explosive" figures (Bombo, Sneaky Bomber, Blastoid, Aggro-bom) blow up on command when a teammate that
## "sets off explosives" (Bombo's Shrapnel upgrade) triggers them: explode now, using the normal blast numbers.
func detonate(_figure: Figure) -> void:
	pass


## Cluster: tap-to-toss stats ({} = none): {"speed", "can"}. A quick tap on the board calls `fire_shot_at`.
func get_toss_stats(_figure: Figure) -> Dictionary:
	return {}


## Clustling: asked of the cluster it touches; true if it takes the clustling back in.
func accept_rejoin(_figure: Figure, _at: Vector2) -> bool:
	return false


## Clustling: the cluster this loose piece belongs to (the enemy AI walks it back), or null.
func get_rejoin_target(_figure: Figure) -> Figure:
	return null


## Spitter: spray stats ({} = none): {"range", "speed", "drops_per_second", "impulse", "water"}.
func get_spray_stats(_figure: Figure) -> Dictionary:
	return {}


## Spitter: the player (or the AI) starts / aims / stops the spray. `point` is where it is aimed (world space).
func set_spray(_figure: Figure, _active: bool, _point := Vector2.ZERO) -> void:
	pass


## Absorber: the impact speed needed to absorb a smaller figure (0 = cannot, or it already holds one).
func get_absorb_speed(_figure: Figure) -> float:
	return 0.0


## Absorber holding a figure: the impact speed from a teammate of the held figure that frees it (0 = holds nothing).
## The held figure itself is returned by get_held_figure.
func get_escape_speed(_figure: Figure) -> float:
	return 0.0


func get_held_figure(_figure: Figure) -> Figure:
	return null


## AI hint: Rally's aimed nudge speed on its teammates (0 = none).
func get_rally_speed(_figure: Figure) -> float:
	return 0.0


## AI hint: hitting anything with this figure also sets off the team's other explosive figures (Bombo's Shrapnel).
func sets_off_team_explosives(_figure: Figure) -> bool:
	return false


## True if this figure bends the path of moving figures near it (Magnet).
func has_path_pull(_figure: Figure) -> bool:
	return false


## The pull (px/s per second) this figure puts on a moving figure of team `mover_team` at `point` (Magnet:
## opposing figures only; -1 = any team).
func get_path_pull(_figure: Figure, _point: Vector2, _mover_team := -1) -> Vector2:
	return Vector2.ZERO


## The bounce this figure has during its OWN flick, or -1 for its normal bounce (Pusher: 0).
func get_flick_bounce(_figure: Figure) -> float:
	return -1.0


## True if this figure never rebounds after hitting something during its own flick (Pusher).
func cancels_rebound(_figure: Figure) -> bool:
	return false


## BODY HOOKS (bosses with a custom shape, Skull-o-tron).

## Called once when the figure is ready: add extra collision shapes, allow spinning...
func setup_body(_figure: Figure) -> void:
	pass


## Drawn first, under the round body, in the figure's own (rotating) coordinates.
func draw_body(_figure: Figure) -> void:
	pass


## A figure hit one of this figure's EXTRA collision shapes (`shape_node`) at relative speed `speed`.
func on_shape_hit(_figure: Figure, _other: Figure, _shape_node: Node, _speed: float) -> void:
	pass


## ENEMY AI HINT: multiplier on this figure's mass when it hits something during its own flick (Pusher).
func get_hit_mass_multiplier(_figure: Figure) -> float:
	return 1.0


## Bloodluster: it was just granted a bonus flick (a kill earned it).
func on_bloodlust_bonus(_figure: Figure) -> void:
	pass


## The figure can be flicked again (a new flick cycle, Energizer's recharge, back on deck).
func on_became_flickable(_figure: Figure) -> void:
	pass


## Called on every figure at the start of each round (the player's turn start): short effects wear off.
func on_round_ticked(_figure: Figure) -> void:
	pass
