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

- `scenes/main.tscn` (main scene): Main (`main.gd`) > Board (`board.gd`), Figures (container), AimLine (`aim_line.gd`).
- `scenes/figure.tscn`: a bare RigidBody2D with `figure.gd`; collision shape and physics are set up in code.
- `scripts/main.gd`: spawns figures, handles touch input, runs the turn (IDLE > AIMING > MOVING), knocks figures off. All feel tunables are `@export`s on the Main node.
- Collision layers: 1 `on_deck`, 2 `flicked`. On-deck figures are frozen on layer 1 with mask 0. Flicked figures use layer 2 and mask 2, so they ignore on-deck figures and hit each other. Enemies will need mask 1 to hit on-deck figures.
- Board and deck rectangles are `@export`s on the Board node; a figure whose center leaves `board_rect` (after entering it) is knocked off.

## Project settings

- Viewport 1080x1920, portrait, stretch mode `canvas_items`, aspect `keep_width`.
- `input_devices/pointing/emulate_touch_from_mouse` is enabled so the game can be tested with a mouse on a laptop. Write input handling against touch events (`InputEventScreenTouch` / `InputEventScreenDrag`), not mouse events.

## Code style

- The developer is learning Godot/GDScript and will tweak game feel a lot.
- Prefer simple, readable code over clever or abstract code.
- Expose every tunable value (flick strength, friction, mass, bounce, turn timings, etc.) as an `@export` variable, with a sensible default and a short comment, so it can be adjusted in the Inspector.
- Use static typing where it helps readability, and keep scripts small and focused.
