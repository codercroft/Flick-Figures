# Flick Figures

Mobile game built in Godot 4 with GDScript.

## Concept

- Turn-based roguelike, portrait orientation, playable entirely with one thumb.
- Top-down tabletop view (no gravity). Little plastic toy figures are flicked (mostly UP the board) at enemy figures. The player can flick in any direction: drag opposite to where you want it to go.
- **Win condition:** knock all of the opponent's figures off the board.

## Rules

- The player's unflicked figures sit "on deck" at the bottom of the board.
- Flicked figures stay where they land.
- The player's flicks pass through their own on-deck figures, but collide with flicked figures.
- Enemies can hit on-deck figures.
- A flicked figure can't be flicked again until all the others have been flicked. Then (default) every remaining figure becomes flickable again right where it stands: there is NO reload step. The old rule (tap one board figure to reload it to the deck) still exists behind `Main.reload_enabled` (@export, off by default, for a future relic).

## UI

- Keep ALL UI in the bottom half of the screen (thumb reach). The top half is the board/enemy area.

## Workflow

- Always commit and push directly to `main` (no branches or PRs). The developer pulls locally and tests in the Godot editor.

## Project structure

- `scenes/main.tscn` (main scene): Main (`main.gd`) > Board (`board.gd`), Figures (container), AimLine (`aim_line.gd`), UI (`ui.gd`, a CanvasLayer with the turn label and win/lose panel, both anchored to the bottom half).
- `scenes/figure.tscn`: a bare RigidBody2D with `figure.gd`; collision shape and physics are set up in code. `figure.team` is PLAYER or ENEMY.
- `scripts/main.gd`: spawns figures, handles touch input, runs the turn loop with `await` (`State`: PLAYER_TURN > AIMING > SETTLING > ENEMY_TURN, then back; GAME_OVER on win/lose, tap to restart). All feel tunables are `@export`s on the Main node.
- Aiming: tap a figure to select it (yellow ring), then press and drag ANYWHERE; direction and power come from the drag relative to where that touch started (full power at `max_pull_fraction` = 30% of screen width), and the aim line is drawn from the selected figure. Pressing directly on a figure still selects and aims in one motion. Touches are ignored outside the player's turn (`_input` guard).
- Settling: a figure is "slow" below `stop_speed` and "resting" after `settle_frames` slow frames in a row (then its velocity is zeroed). Abilities that push continuously (Magnet) must skip slow figures (`is_slow()`). `_wait_until_settled()` force-stops everything after `max_settle_time` (6s), shows an orange readout of what is still moving after `settle_debug_after` (5s) and prints it, and a `turn_timeout` watchdog hands control back if a turn ever hangs. Never touch a Figure from a snapshot list without `is_instance_valid` (use `_is_alive`): knocked-off figures are freed after their fade, and a script error inside the turn coroutine silently freezes the turn.
- Turn flow: the sides alternate flicks. The player flicks ONE figure, everything settles, then the enemy side takes `enemy flicks per turn` flicks (default 1), then back to the player. At the start of a player turn, if no figure is flickable, `_make_all_flickable()` re-arms the whole squad in place (or, with `Main.reload_enabled`, the player taps a board figure to reload it to deck first).
- Enemy flicks: for each flick `enemy_ai.choose_flick()` evaluates the best shot of EVERY candidate enemy figure and takes the single best one overall (real attacks outrank repositioning, which outranks passing; if nobody has anything it passes and the turn ends early). With `Main.no_repeat_enemy` (@export, default true) the enemy that flicked last is not a candidate, unless it is the only one that can flick. With 2+ flicks per turn each flick picks the best remaining shot and waits for the board to settle before the next. Creepers (The Wall) still creep after the whole enemy turn, ALL together in one go (every piece launched at the same moment, same distance each, then one settle).
- Enemy flicks per turn lives in the lineup data: `RunConfig.enemy_flicks_per_combat` (one entry per normal combat, default 1 each) and `BossData.enemy_flicks_per_turn` (The Wall 1, Sniper Squad 2, Slime 1); `RunManager.enemy_flicks_per_turn` holds the current combat's value and `main.gd` reads it (`_enemy_flicks`). Elites or later acts can set higher values there. Slime: every enemy split adds `Main.flicks_per_split` (1) flick, capped at `Main.max_enemy_flicks` (4), and it can apply mid-turn.
- Figures have two separate flags: `on_deck` (WHERE it is: collision layers, Magnet, Mr Potential) and `flickable` (may be flicked this round; unflickable player figures are drawn greyed out). `launch()` sets `on_deck = false` and `flickable = false`; `return_to_deck()` sets both true again.
- Collision layers: 1 `on_deck`, 2 `flicked`, 3 `enemy`, 4 `arena` (walls and pins; every figure's mask includes it). On-deck figures are NOT frozen (enemies can shove them): layer 1, mask 3. Flicked player figures: layer 2, mask 2+3. Enemies: layer 3, mask 1+2+3. So player flicks ignore on-deck figures, but enemies hit them.
- The "table" is `board_rect` merged with `deck_rect` (Board node exports). Any figure (either team, on deck or not) whose center leaves the table is knocked off.

## Arenas

- Each combat uses an `ArenaData` layout (`scripts/arena_data.gd`, files in `resources/arenas/`, pool = `RunConfig.arenas`). `RunManager.arena` is picked in `_build_lineup()`: random, never the same twice in a row, and only `creeper_safe` ones when a creeping boss (The Wall) is in the fight. `Arena` (`scripts/arena.gd`, node under Main) builds it; `main.gd` calls `arena.build(RunManager.arena, board.board_rect)` and shows the layout's name for ~2s (`ui.show_arena_name`).
- A layout is lists of `ArenaWall` (rotated rectangle, solid and bouncy), `ArenaPin` (small round bumper that kicks figures `pin_kick` x faster) and `ArenaPatch` (rectangle, not solid: SLOW adds damping, BOOST pushes in `direction_degrees` (`boost_acceleration` on the Arena node, default 470, was 1400: it was far too strong), TURN rotates a moving figure's velocity left or right, speed kept). All positions are in board space: (0,0) is the board's top-left, board is 900x1000, enemies at the top. Keep everything inside the board (the deck strip below must stay clear; `get_warnings()` flags it) and away from enemy spawn points (4 enemies at y=160/280, snipers, The Wall at y=160).
- Patches only act on figures that are moving (not `is_slow()`), so they never keep a resting figure moving. Strengths are exports on the Arena node (`slow_damping`, `boost_acceleration`, `turn_rate_degrees`, `wall_bounce`, `pin_kick`...), with a per-patch `strength` multiplier. Layouts: Open Field, Corner Posts, Open Corners, Side Rails, Divider, The Funnel, Pinball, Mud Flats, Speedway, Whirlpool, Crosswinds. To add one: duplicate a `.tres`, edit it, add it to `run_config.tres`.
- The enemy AI's shape casts already include the arena layer: shots blocked by a wall or pin are skipped, and it won't count on a wall-blocked edge for a knock-off. It ignores patches.

## Enemy AI

- `scripts/enemy_ai.gd` (`EnemyAI` node under Main). `choose_flick()` runs `_best_shot_for()` for each candidate enemy (see Enemy flicks above) and that tries candidate shots (every player figure x angle offsets x power levels; speeds are fractions of `reference_speed` x the figure's flick power), and uses `PhysicsDirectSpaceState2D.cast_motion` to find the first figure each would hit (figures already touching the shooter count as hit at distance 0).
- Scoring: `_predict_collision()` does elastic-collision maths along the line of centers (masses, Godot's summed-and-capped bounce, knockback multipliers) to get both figures' velocities right after impact, and `_leave_chance()` turns "slide distance vs distance to the table edge" into a 0-1 chance of going off (ramping from 70% to 120% of the way). Hit on a player figure = `hit_player_bonus` + `kill_bonus` x chance the target is knocked off + `edge_bonus` x how far it is pushed toward the edge; minus `self_knock_off_penalty` x chance the SHOOTER leaves the table (default 300, more than a hit + kill + edge, so a self-knockoff outweighs the kill), minus the same penalty x chance of missing (aim error) x chance the shooter then slides off, minus `overpower_penalty` x power (so the lowest power that still knocks the target off wins). Hitting an ally first is penalized unless the ally is lined up with a player figure behind it. If no attack scores above `min_attack_score` it makes a small safe repositioning flick, or passes. Not modelled: ability side effects such as Crazy Man's bounce boost.
- Aim error comes from `FigureData.accuracy` (1 = perfect) scaled by the AI's `max_aim_error_degrees`. Power levels, scores and distances are all exports on the EnemyAI node; `debug_draw_shots` draws each enemy's chosen shot (red attack, orange via ally, yellow reposition).
- Prediction assumes linear damping: speed falls by `damp * distance`, so slide distance = (speed - stop_speed) / damp.

## Figures (data-driven)

- `scripts/figure_data.gd` (`FigureData` Resource): display_name, color, radius, mass, bounce, damping_multiplier, flick_power_multiplier, knockback_taken_multiplier, and an `ability` slot. Figures are `.tres` files in `resources/figures/`: Roller, Duwall, Powerhouse, Bombo (player) and Grunt (enemy). Make a new figure by duplicating one in the editor.
- Which figures fight comes from the `RunManager` autoload (the player's deck and the current combat's enemy lineup), not from Main exports. Main's `figure_damping` is the base damping that each figure's `damping_multiplier` scales.
- Abilities: `scripts/abilities/figure_ability.gd` (`FigureAbility` Resource) is the base class with no-op hooks `on_flicked`, `on_hit`, `on_stopped`, `on_exploded`. Subclass it (see `bombo_ability.gd`) and pick it in the FigureData's `ability` slot; ability tunables are `@export`s on the subclass. Each figure runs its own duplicate of the ability, so per-figure state is safe. To add a new event, call it from `figure.gd` (hooks are called deferred from physics callbacks).
- `Figure.explode(radius, force, spared)` pushes nearby figures (except `spared`) (linear falloff) and fires `on_exploded` on them. `take_knockback()` and the collision handling in `_integrate_forces` apply `knockback_taken_multiplier`.
- Bombo explodes on its first hit after each flick (resets on flick), and survives.

### Figure roster, registry and icons

- Every figure works on either side; a white ring means player, a red ring means enemy. Each figure shows a short `label` and a small `icon` (`FigureData.icon`, drawn by `scripts/figure_icons.gd`; add an enum entry + a `match` case to make a new one).
- Figures: Roller (R), Duwall (D), Powerhouse (P: 2x flick power, but takes 2x knockback from enemy figures), Bombo (B), Crazy Man (CM: bounce 1 + `bounce_boost`, since Godot sums bounce values and caps at 1), Mr Potential (MP: 2x knockback from own team while on board), Sneaky Bomber (SB: explodes at the end of a flick that touched nothing, radius 270, pushes everyone), Magnet (MG: while on board, bends the path of MOVING figures of both sides for slingshot curves: no pull inside `inner_radius`, growing to `pull_acceleration` at `pull_radius`, never pulls resting figures or itself; fast shots bend ~10-15 degrees, slower ones much more or get captured), Bumper (BP: heavy and slow, anything that bounces off it is launched with `bump_ratio` x its rebound speed), Firecracker (FC: explodes when a TEAMMATE hits it, sparing that teammate, and when caught in an explosion; chain reactions, `rearm_ms` stops loops).
- Second batch of figures (all draftable, `scripts/abilities/*_ability.gd`, every number an `@export` on the ability):
  - Speedo (SD): light (mass 0.6), flick power 0.75. `get_flicks_per_turn()` = 2: after its first flick settles `main._offer_bonus_flick()` lets the player flick it again, or tap to skip. Enemy Speedos take the extra shot only if `choose_flick(..., min_score)` finds an attack scoring >= `EnemyAI.bonus_flick_min_score` (120). `Figure.turn_flicks` is reset every turn.
  - Ghost (GH): `on_left_table()` hook (main calls it before knocking a figure off): if it is mid-own-flick and `figure.touched_since_flick` is false (no figure or wall touched), it wraps to the opposite edge of the table keeping its velocity, `max_wraps_per_flick` (1) times.
  - Glue Guy (GG): first collision glues it to that figure with a rigid `PinJoint2D` (`Figure.glue_to()`, both bodies are rotation-locked so they move as one heavier body). Any explosion reaching either one calls `unglue()`; knock-off also unglues.
  - Splitter (SX): first impact after a flick (>= `min_hit_speed`) splits it into `piece_count` Minis (`splitter_mini.tres`, `pays_income = false`) via `split_into()`; they are normal team figures for win/loss, born out on the board and unflickable until the squad re-arms. `split_into(pieces, grants_flicks)`: only Slime passes true (adds to enemy flicks per turn).
  - Rally (RY): on flick, `nudge()`s every other teammate that is not on deck forward (`nudge_speed`; up for player, down for enemy).
  - Popcorn (PC): explosion multiplier 0, then `on_exploded` launches it in a random direction at `launch_speed` (3000).
  - Bunker (BK): explosion multiplier 0; each explosion reaching it adds `mass_gain` mass up to `max_mass`.
  - Piggy Bank (PB, economy): when it is the hitter, extra knockback on the other figure = `min(RunManager.money * bonus_per_dollar, max_bonus)` of a normal hit.
  - Piñata (PN, economy): explosion push scaled by `explosion_push_scale` (0.4), pays `payout` $ per explosion, `max_payouts` times per combat.
  - New hooks on `FigureAbility`: `get_explosion_multiplier(figure, source)` (explosions go through `Figure.take_explosion()`), `get_flicks_per_turn(figure)`, `on_left_table(figure, table)`. Helpers on Figure: `nudge(velocity_change)`, `show_popup(text)`.
- Extra ability hooks beyond the four events: `on_impact(figure, other, speed, point)` (like `on_hit` but with the relative impact speed), `on_physics_process(figure, delta)` (continuous effects) and the modifier `get_knockback_multiplier(figure, source)` (applied to collisions and `take_knockback`).
- `resources/figure_registry.tres` (`FigureRegistry`): `grunts` (just the plain Grunt), `draftable` (reward pool and shop stock; every non-grunt figure), `economy` (the "economy" tag: Cha-ching, Piggy Bank, Piñata and any future economy figures; they can be drafted or sold but `random_non_grunts()` never puts them in an enemy lineup, so add new economy figures to this list), and `bosses` (`BossData`: The Wall, Sniper Squad, Slime), plus `random_grunt()`, `random_non_grunts(count)`, `random_draftable(count)` and `random_boss()`. A figure can be in more than one list.

## Run structure

- `scripts/run_manager.gd` is the `RunManager` autoload. It holds `deck` (4 `FigureData`), `combat_index`, `boss` and the current `enemies` lineup, and exposes `start_new_run()`, `combat_won()` (true when the boss was beaten), `offer_rewards()`, `replace_figure()`, `progress_text()` and `run_over_text()`. It never touches scenes.
- Rules live in `resources/run_config.tres` (`RunConfig`): starting figure and deck size, `grunts_per_combat = [4, 3, 2, 1, 0]` and `enemies_per_combat = 4` (5 combats per floor before the boss; the rest of each 4-enemy lineup are distinct random non-grunts, never economy figures), `reward_choices`.
- Flow: the run starts on `scenes/map.tscn` (the main scene): a vertical map with 5 combat nodes and the boss node on top (placeholder shapes; checked = done, glowing = current, tap the current node to fight). `main.tscn` is one combat (it reads RunManager's deck and enemies). Win a normal combat: `RunManager.combat_won()`, then `scenes/reward.tscn` (pick 1 of 3 distinct draftables, then pick which deck figure it replaces; grunts listed first; a Back button), then back to the map, and the next combat loads `main.tscn` fresh, which fully resets the board. Lose, or beat the boss: the bottom-half result panel shows how far you got; tap calls `start_new_run()` and goes to the map. The reward screen's buttons are `FigureCard`s in a bottom-half column.

### Bosses

- `scripts/boss_data.gd` (`BossData`): name, description, map label/color, and the `enemies` (FigureData list) for the fight. One is picked at random per run from `FigureRegistry.bosses` (`resources/figures/boss_*.tres`).
- Boss stats live on the boss's figures in `resources/figures/`: mass, `accuracy`, `flick_power_multiplier`, and two FigureData fields: `can_flick` (false = the AI never flicks it) and `creep_distance` (slides that far straight toward the deck after every enemy turn; if its front edge reaches the deck line, the player loses; `board.show_deck_line` draws a faint dashed line there).
- The Wall (`boss_the_wall.tres`, `wall_piece.tres` x5, map label WL): five heavy pieces (radius 88, mass 6) in one straight row (`BossData.straight_row`) spanning the board from left edge to right edge. After every enemy turn ALL pieces creep toward the deck together by `creep_distance` (55) each, from wherever they currently are (knocked-back pieces keep creeping). If any piece's front edge reaches the deck line you lose; knock all 5 off to win. They don't flick by default: `can_flick` on `wall_piece.tres` is the toggle (turn it on and they flick like any enemy, with `no_repeat_enemy` rules). Sniper Squad (`sniper.tres` x5): small, light, accuracy 0.98, flick power 1.5 (`flick_power_multiplier` on `sniper.tres`).
- Slime (`boss_slime.tres`, third boss): starts as one large slime (radius 100, mass 5). `SlimeAbility` (`scripts/abilities/slime_ability.gd`) splits it when `on_impact` speed >= `split_speed` (700; medium 600) into `piece_count` (2) of the next size (medium: radius 70, mass 2.4, then small: radius 45, mass 0.9, which never split; lighter = easier to knock off), bursting sideways/away from the impact point at `burst_speed`. It works through `Figure.split_into()` -> signal `split_requested` -> `main._on_split_requested()`, which spawns the pieces as new enemies (they take their own turns from the next enemy turn) and retires the parent. The fight is won when every piece is off the table. Pieces ignore hits for `grace_ms` after birth.

## Economy and shop

- Money lives on `RunManager` (`money`, `last_income`). When a normal combat is won, `main._end_game` calls `RunManager.award_income(figures_on_table)` (before `combat_won()`): `RunConfig.income_per_figure` ($1) per own figure still on the table (deck or board) plus each figure's `FigureData.income_bonus`. The reward screen shows `income_text()` (gold line under the title); the map shows "$N" top right. `RunConfig.starting_money` sets the start.
- Cha-ching (`cha_ching.tres`, CC, coin icon `COIN`): no ability, `income_bonus = 2`, draftable.
- `FigureData.rarity` (0 Common, 1 Uncommon, 2 Rare) drives shop prices.
- The shop is optional and is NOT a combat. `RunConfig.shop_position` (3) = the shop sits just before that combat index (between combats 3 and 4); `RunManager.shop_available()` is true then until `leave_shop()` (`shop_done`). On the map it is a `$` node off to the side of the path (tap to visit, or just tap the glowing combat node to skip). `enter_shop()` rolls `shop_offers` once, so leaving and returning keeps the same stock.
- Config: `resources/shop_config.tres` (`ShopConfig`) holds `item_types: Array[ShopItemType]`; `make_offers(registry)` concatenates what each type's `create_offers()` returns (`ShopOffer`: title, description, price, optional figure, `needs_slot`, `slot_prompt`, `sold`, `on_buy` Callable, `buy(slot)`). Types so far: `FigureForSaleType` (`count`, `price_by_rarity` [3,5,8]) and `ReplaceServiceType` (`price`, swaps a deck figure for a random new one). To add relics/upgrades/services: subclass `ShopItemType` in `scripts/shop/`, override `create_offers()`, add a sub-resource to `shop_config.tres`. `shop.gd` needs no change.
- Shop UI (`scenes/shop.tscn`, `shop.gd`) is a bottom-half column of `FigureCard`s (price in the text, disabled when sold/unaffordable); offers that need a deck slot go to a "which figure?" picker (grunts first, Back button).

## Game feel

- `scripts/game_feel.gd` (GameFeel node, with a Camera2D child used for screen shake) holds all the "juice": squash/stretch, impact particles, screen shake, knock-off pop, and haptics (`Input.vibrate_handheld`, mobile only). Each effect has an `@export` bool switch on that node; all other numbers are exports too.
- Figures only emit signals (`flicked`, `impacted`, `fell_off`); `main.gd` connects them to GameFeel when spawning. Impact speed is the relative speed just before the collision. Squash/pop are drawn in `Figure._draw` (the RigidBody is never scaled).
- Haptics need the Android Vibrate permission, which is already ticked in the committed `export_presets.cfg`.

## Builds

- `.github/workflows/build.yml` runs on every push to `main`: it exports an Android APK (debug-signed with the committed, public `signing/debug.keystore`, so new builds install over old ones) and a web build, then republishes them on the GitHub release tagged `latest` ("Latest build"). `export_presets.cfg` is committed (Android + Web presets, no secrets). See `BUILDING.md` for how to install and share. The renderer is GL Compatibility (needed for web, and the safest on phones).
- A real release keystore (for Google Play) must go in GitHub secrets, never in the repo.

## Project settings

- Viewport 1080x1920, portrait, stretch mode `canvas_items`, aspect `keep_width`.
- `input_devices/pointing/emulate_touch_from_mouse` is enabled so the game can be tested with a mouse on a laptop. Write input handling against touch events (`InputEventScreenTouch` / `InputEventScreenDrag`), not mouse events.

## Code style

- The developer is learning Godot/GDScript and will tweak game feel a lot.
- Prefer simple, readable code over clever or abstract code.
- Expose every tunable value (flick strength, friction, mass, bounce, turn timings, etc.) as an `@export` variable, with a sensible default and a short comment, so it can be adjusted in the Inspector.
- Use static typing where it helps readability, and keep scripts small and focused.
