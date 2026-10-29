class_name EngineerAbility
extends FigureAbility
## Rare. While the Engineer is selected and before it is flicked, the player can TAP any empty spot on
## the board to place ONE turret there (placing another replaces it; tap the turret to take it back).
## The turret is a weak, light, pin-like object: figures knock it around and off the table. During the
## OPPOSING side's turn only, it fires a small pellet at the nearest opposing figure on the board
## (not one waiting on the deck) every
## `fire_interval` seconds. A pellet gives a small knockback (enough to nudge or deflect a moving
## figure, not to knock a resting one off from the middle of the board) and vanishes on a hit or after
## `pellet_range` px. An enemy Engineer places its turret at the start of the enemy turn, where it
## covers the player's likely flick lanes (see EnemyAI.choose_turret_spot).

@export_group("Turret")
## Size, weight and slide-damping of the turret (light, so it gets pushed around).
@export var turret_radius := 30.0
@export var turret_mass := 0.35
@export var turret_damping := 3.0
## Seconds between shots (only counted during the opposing side's turn).
@export var fire_interval := 1.5
@export_group("Pellet")
## Speed in px/s, how far it flies (px), and its knockback (a velocity change of a mass-1 figure, px/s).
@export var pellet_speed := 900.0
@export var pellet_range := 520.0
@export var pellet_impulse := 260.0
@export var pellet_radius := 9.0
## Aim ahead of a moving target.
@export var lead_target := true


func get_turret_stats(_figure: Figure) -> Dictionary:
	return {
		"radius": turret_radius, "mass": turret_mass, "damping": turret_damping, "interval": fire_interval,
		"speed": pellet_speed, "range": pellet_range, "impulse": pellet_impulse,
		"pellet_radius": pellet_radius, "lead": lead_target,
	}
