class_name SandboxSetup
extends RefCounted
## Sandbox mode: the setup that the real combat scene (main.tscn) is built from, kept between scene reloads.
## Nothing here touches run saves, unlocks, run history or the Compendium: `prepare()` only fills RunManager's
## in-memory combat fields (a saved run is reloaded from its file by Continue; New Run resets everything).
## Structural changes (arena, boss, encounter, relics, ascension) change this data and reload the scene.

enum Mode { PLAY, EDIT }

static var active := false
static var mode := Mode.PLAY
static var arena: ArenaData  # null = whatever the lineup brings (an encounter's own layout, the open boss field)
static var ascension := 0
static var act := 0  # 0-based
static var lineup_kind := "none"  # "none", "boss" or "encounter"
static var boss: BossData
static var encounter: EncounterData
## Figures placed by hand: {data, team, pos (world), equipment, finish, upgrade (Vector2i), node (live Figure)}.
static var entries: Array[Dictionary] = []
static var player_relics: Array[RelicData] = []
static var enemy_relics: Array[RelicData] = []
static var player_powers: Array[PowerData] = []
static var ai_off := false
static var free_flick := false
static var sheet_open := true


## From the main menu: a fresh sandbox.
static func begin() -> void:
	active = true
	mode = Mode.PLAY
	arena = RunManager.config.arenas[0] if not RunManager.config.arenas.is_empty() else null
	ascension = 0
	act = 0
	lineup_kind = "none"
	boss = null
	encounter = null
	entries.clear()
	player_relics.clear()
	enemy_relics.clear()
	player_powers.clear()
	ai_off = false
	free_flick = false
	sheet_open = true


static func end() -> void:
	active = false
	RunManager.sandbox_encounter = null


static func is_elite(data: EncounterData) -> bool:
	return RunManager.config.elite_encounters.has(data)


## Fills RunManager's combat fields from this setup (called before main.tscn loads).
static func prepare() -> void:
	var run := RunManager
	run.ascension = ascension
	run.act = act
	run.in_second_boss = false
	run.deck.clear()
	run.deck_equipment.clear()
	run.deck_finish.clear()
	run.deck_upgrade.clear()
	run.relics.assign(player_relics)
	run.powers.clear()
	for i in run.config.power_slots:
		run.powers.append(player_powers[i] if i < player_powers.size() else null)
	var node := MapNode.new()
	node.column = 2
	node.type = MapNode.Type.COMBAT
	run.sandbox_encounter = null
	match lineup_kind:
		"boss":
			node.type = MapNode.Type.BOSS
			run.boss = boss
			run.node = node
			run._build_lineup()
		"encounter":
			node.type = MapNode.Type.ELITE if is_elite(encounter) else MapNode.Type.COMBAT
			run.sandbox_encounter = encounter
			run.node = node
			if encounter.mirror_deck:  # Mirror Match copies the player's deck: use the placed player figures
				for entry in entries:
					if entry.team == Figure.Team.PLAYER:
						run.deck.append(entry.data)
						run.deck_equipment.append(entry.equipment)
						run.deck_finish.append(entry.finish)
						run.deck_upgrade.append(entry.upgrade)
				if run.deck.is_empty():
					for i in run.config.deck_size:
						run.deck.append(run.config.starting_figure)
						run.deck_equipment.append(null)
						run.deck_finish.append(null)
						run.deck_upgrade.append(RunManager.NO_UPGRADE)
			run._build_lineup()
			run.deck.clear()  # (the placed figures fill the deck arrays again when they spawn)
			run.deck_equipment.clear()
			run.deck_finish.clear()
			run.deck_upgrade.clear()
		_:
			run.node = node
			run.boss = null
			run.clear_lineup()
	if arena != null:
		run.arena = arena
	elif run.arena == null and not run.config.arenas.is_empty():
		run.arena = run.config.arenas[0]
	for relic in enemy_relics:
		if not run.enemy_relics.has(relic):
			run.enemy_relics.append(relic)
