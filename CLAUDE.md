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
- A flicked figure can't be flicked again until all the others have been flicked. Then the player reloads one figure from the board back to deck.

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
- Turn flow: player flicks one figure, everything settles, then each enemy flicks in turn (chosen by `enemy_ai.gd`), settling after each. If the player has no figure on deck at the start of their turn, they tap a figure on the board to reload it to deck first.
- Collision layers: 1 `on_deck`, 2 `flicked`, 3 `enemy`, 4 `arena` (walls and pins; every figure's mask includes it). On-deck figures are NOT frozen (enemies can shove them): layer 1, mask 3. Flicked player figures: layer 2, mask 2+3. Enemies: layer 3, mask 1+2+3. So player flicks ignore on-deck figures, but enemies hit them.
- The "table" is `board_rect` merged with `deck_rect` (Board node exports). Any figure (either team, on deck or not) whose center leaves the table is knocked off.

## Arenas

- Each combat uses an `ArenaData` layout (`scripts/arena_data.gd`, files in `resources/arenas/`, pool = `RunConfig.arenas`). `RunManager.arena` is picked in `_build_lineup()`: random, never the same twice in a row, and only `creeper_safe` ones when a creeping boss (Big Bad) is in the fight. `Arena` (`scripts/arena.gd`, node under Main) builds it; `main.gd` calls `arena.build(RunManager.arena, board.board_rect)` and shows the layout's name for ~2s (`ui.show_arena_name`).
- A layout is lists of `ArenaWall` (rotated rectangle, solid and bouncy), `ArenaPin` (small round bumper that kicks figures `pin_kick` x faster) and `ArenaPatch` (rectangle, not solid: SLOW adds damping, BOOST pushes in `direction_degrees`, TURN rotates a moving figure's velocity left or right, speed kept). All positions are in board space: (0,0) is the board's top-left, board is 900x1000, enemies at the top. Keep everything inside the board (the deck strip below must stay clear; `get_warnings()` flags it) and away from enemy spawn points (3 enemies at y=160/280, snipers, Big Bad at y=175).
- Patches only act on figures that are moving (not `is_slow()`), so they never keep a resting figure moving. Strengths are exports on the Arena node (`slow_damping`, `boost_acceleration`, `turn_rate_degrees`, `wall_bounce`, `pin_kick`...), with a per-patch `strength` multiplier. Layouts: Open Field, Corner Posts, Open Corners, Side Rails, Divider, The Funnel, Pinball, Mud Flats, Speedway, Whirlpool, Crosswinds. To add one: duplicate a `.tres`, edit it, add it to `run_config.tres`.
- The enemy AI's shape casts already include the arena layer: shots blocked by a wall or pin are skipped, and it won't count on a wall-blocked edge for a knock-off. It ignores patches.

## Enemy AI

- `scripts/enemy_ai.gd` (`EnemyAI` node under Main). `choose_shot()` tries candidate shots for each enemy (every player figure x angle offsets x power levels; speeds are fractions of `reference_speed` x the figure's flick power), and uses `PhysicsDirectSpaceState2D.cast_motion` to find the first figure each would hit (figures already touching the shooter count as hit at distance 0).
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
- Extra ability hooks beyond the four events: `on_impact(figure, other, speed, point)` (like `on_hit` but with the relative impact speed), `on_physics_process(figure, delta)` (continuous effects) and the modifier `get_knockback_multiplier(figure, source)` (applied to collisions and `take_knockback`).
- `resources/figure_registry.tres` (`FigureRegistry`): `grunts` (just the plain Grunt), `draftable` (reward pool; every non-grunt figure), and `bosses` (`BossData`: Big Bad, Sniper Squad), plus `random_grunt()`, `random_non_grunts(count)`, `random_draftable(count)` and `random_boss()`. A figure can be in more than one list.

## Run structure

- `scripts/run_manager.gd` is the `RunManager` autoload. It holds `deck` (4 `FigureData`), `combat_index`, `boss` and the current `enemies` lineup, and exposes `start_new_run()`, `combat_won()` (true when the boss was beaten), `offer_rewards()`, `replace_figure()`, `progress_text()` and `run_over_text()`. It never touches scenes.
- Rules live in `resources/run_config.tres` (`RunConfig`): starting figure and deck size, `grunts_per_combat = [3, 2, 1, 0]` (the rest of each 3-enemy lineup are distinct random non-grunts), `reward_choices`.
- Flow: the run starts on `scenes/map.tscn` (the main scene): a vertical map with 4 combat nodes and the boss node on top (placeholder shapes; checked = done, glowing = current, tap the current node to fight). `main.tscn` is one combat (it reads RunManager's deck and enemies). Win a normal combat: `RunManager.combat_won()`, then `scenes/reward.tscn` (pick 1 of 3 distinct draftables, then pick which deck figure it replaces; grunts listed first; a Back button), then back to the map, and the next combat loads `main.tscn` fresh, which fully resets the board. Lose, or beat the boss: the bottom-half result panel shows how far you got; tap calls `start_new_run()` and goes to the map. The reward screen's buttons are `FigureCard`s in a bottom-half column.

### Bosses

- `scripts/boss_data.gd` (`BossData`): name, description, map label/color, and the `enemies` (FigureData list) for the fight. One is picked at random per run from `FigureRegistry.bosses` (`resources/figures/boss_*.tres`).
- Boss stats live on the boss's figures in `resources/figures/`: mass, `accuracy`, `flick_power_multiplier`, and two FigureData fields: `can_flick` (false = the AI never flicks it) and `creep_distance` (slides that far straight toward the deck after every enemy turn; if its front edge reaches the deck line, the player loses; `board.show_deck_line` draws a faint dashed line there).
- Big Bad (`big_bad.tres`): one huge (radius 130, mass 10) figure that never flicks and creeps 60px per turn; knock it off to win. Sniper Squad (`sniper.tres` x5): small, light, accuracy 0.98, flick power 1.2.
- Slime (`boss_slime.tres`, third boss): starts as one large slime (radius 100, mass 5). `SlimeAbility` (`scripts/abilities/slime_ability.gd`) splits it when `on_impact` speed >= `split_speed` (700; medium 600) into `piece_count` (2) of the next size (medium: radius 70, mass 2.4, then small: radius 45, mass 0.9, which never split; lighter = easier to knock off), bursting sideways/away from the impact point at `burst_speed`. It works through `Figure.split_into()` -> signal `split_requested` -> `main._on_split_requested()`, which spawns the pieces as new enemies (they take their own turns from the next enemy turn) and retires the parent. The fight is won when every piece is off the table. Pieces ignore hits for `grace_ms` after birth.

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
