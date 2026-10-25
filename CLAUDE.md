# Flick Figures

Mobile game built in Godot 4 with GDScript.

## Concept

- Turn-based roguelike, portrait orientation, playable entirely with one thumb.
- Top-down tabletop view (no gravity). Little plastic toy figures are flicked UP the board at enemy figures.
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
- Turn flow: player flicks one figure, everything settles, then each enemy flicks in turn (chosen by `enemy_ai.gd`), settling after each. If the player has no figure on deck at the start of their turn, they tap a figure on the board to reload it to deck first.
- Collision layers: 1 `on_deck`, 2 `flicked`, 3 `enemy`. On-deck figures are NOT frozen (enemies can shove them): layer 1, mask 3. Flicked player figures: layer 2, mask 2+3. Enemies: layer 3, mask 1+2+3. So player flicks ignore on-deck figures, but enemies hit them.
- The "table" is `board_rect` merged with `deck_rect` (Board node exports). Any figure (either team, on deck or not) whose center leaves the table is knocked off.

## Enemy AI

- `scripts/enemy_ai.gd` (`EnemyAI` node under Main). `choose_shot()` tries candidate shots for each enemy (every player figure x angle offsets x power levels), uses `PhysicsDirectSpaceState2D.cast_motion` to find the first figure each would hit, and scores them: big bonus for hitting a player figure (extra near the table edge in the push direction), big penalty for hitting an ally first (unless the ally is lined up with a player figure behind it), penalty if the shooter would probably slide off. If no attack scores well it makes a small safe repositioning flick, or passes.
- Aim error comes from `FigureData.accuracy` (1 = perfect) scaled by the AI's `max_aim_error_degrees`. Power levels, scores and distances are all exports on the EnemyAI node; `debug_draw_shots` draws each enemy's chosen shot (red attack, orange via ally, yellow reposition).
- Prediction assumes linear damping: speed falls by `damp * distance`, so slide distance = (speed - stop_speed) / damp.

## Figures (data-driven)

- `scripts/figure_data.gd` (`FigureData` Resource): display_name, color, radius, mass, bounce, damping_multiplier, flick_power_multiplier, knockback_taken_multiplier, and an `ability` slot. Figures are `.tres` files in `resources/figures/`: Roller, Duwall, Powerhouse, Bombo (player) and Grunt (enemy). Make a new figure by duplicating one in the editor.
- Main's `player_figures` array is the player's starting roster (one of each, one deck slot per entry); `enemy_figure` is what every enemy uses; `figure_damping` is the base damping that each figure's `damping_multiplier` scales.
- Abilities: `scripts/abilities/figure_ability.gd` (`FigureAbility` Resource) is the base class with no-op hooks `on_flicked`, `on_hit`, `on_stopped`, `on_exploded`. Subclass it (see `bombo_ability.gd`) and pick it in the FigureData's `ability` slot; ability tunables are `@export`s on the subclass. Each figure runs its own duplicate of the ability, so per-figure state is safe. To add a new event, call it from `figure.gd` (hooks are called deferred from physics callbacks).
- `Figure.explode(radius, force)` pushes nearby figures (linear falloff) and fires `on_exploded` on them. `take_knockback()` and the collision handling in `_integrate_forces` apply `knockback_taken_multiplier`.
- Bombo explodes on its first hit after each flick (resets on flick), and survives.

### Figure roster, registry and icons

- Every figure works on either side; a white ring means player, a red ring means enemy. Each figure shows a short `label` and a small `icon` (`FigureData.icon`, drawn by `scripts/figure_icons.gd`; add an enum entry + a `match` case to make a new one).
- Figures: Roller (R), Duwall (D), Powerhouse (P), Bombo (B), Crazy Man (CM: bounce 1 + `bounce_boost`, since Godot sums bounce values and caps at 1), Mr Potential (MP: 2x knockback from own team while on board), Sneaky Bomber (SB: explodes at the end of a flick that touched nothing, pushes everyone), Magnet (MG: pulls moving figures of BOTH sides while on board), Bumper (BP: extra knockback on whatever bounces off it), Firecracker (FC: explodes when hit by an explosion; chain reactions, `rearm_ms` stops loops).
- Extra ability hooks beyond the four events: `on_physics_process(figure, delta)` (continuous effects) and the modifier `get_knockback_multiplier(figure, source)` (applied to collisions and `take_knockback`).
- `resources/figure_registry.tres` (`FigureRegistry`): `grunts` (enemy fodder) and `draftable` (player draft pool) lists, plus `random_grunt()` and `random_draftable(count, exclude)` for the run system. A figure can be in both lists.

## Game feel

- `scripts/game_feel.gd` (GameFeel node, with a Camera2D child used for screen shake) holds all the "juice": squash/stretch, impact particles, screen shake, knock-off pop, and haptics (`Input.vibrate_handheld`, mobile only). Each effect has an `@export` bool switch on that node; all other numbers are exports too.
- Figures only emit signals (`flicked`, `impacted`, `fell_off`); `main.gd` connects them to GameFeel when spawning. Impact speed is the relative speed just before the collision. Squash/pop are drawn in `Figure._draw` (the RigidBody is never scaled).
- Android export preset needs the Vibrate permission ticked (`export_presets.cfg` is git-ignored, so set it locally).

## Project settings

- Viewport 1080x1920, portrait, stretch mode `canvas_items`, aspect `keep_width`.
- `input_devices/pointing/emulate_touch_from_mouse` is enabled so the game can be tested with a mouse on a laptop. Write input handling against touch events (`InputEventScreenTouch` / `InputEventScreenDrag`), not mouse events.

## Code style

- The developer is learning Godot/GDScript and will tweak game feel a lot.
- Prefer simple, readable code over clever or abstract code.
- Expose every tunable value (flick strength, friction, mass, bounce, turn timings, etc.) as an `@export` variable, with a sensible default and a short comment, so it can be adjusted in the Inspector.
- Use static typing where it helps readability, and keep scripts small and focused.
