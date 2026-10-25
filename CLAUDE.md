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
- Turn flow: player flicks one figure, everything settles, then each enemy flicks in turn (at the nearest player figure, with random angle error), settling after each. If the player has no figure on deck at the start of their turn, they tap a figure on the board to reload it to deck first.
- Collision layers: 1 `on_deck`, 2 `flicked`, 3 `enemy`. On-deck figures are NOT frozen (enemies can shove them): layer 1, mask 3. Flicked player figures: layer 2, mask 2+3. Enemies: layer 3, mask 1+2+3. So player flicks ignore on-deck figures, but enemies hit them.
- The "table" is `board_rect` merged with `deck_rect` (Board node exports). Any figure (either team, on deck or not) whose center leaves the table is knocked off.

## Project settings

- Viewport 1080x1920, portrait, stretch mode `canvas_items`, aspect `keep_width`.
- `input_devices/pointing/emulate_touch_from_mouse` is enabled so the game can be tested with a mouse on a laptop. Write input handling against touch events (`InputEventScreenTouch` / `InputEventScreenDrag`), not mouse events.

## Code style

- The developer is learning Godot/GDScript and will tweak game feel a lot.
- Prefer simple, readable code over clever or abstract code.
- Expose every tunable value (flick strength, friction, mass, bounce, turn timings, etc.) as an `@export` variable, with a sensible default and a short comment, so it can be adjusted in the Inspector.
- Use static typing where it helps readability, and keep scripts small and focused.
