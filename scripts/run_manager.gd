extends Node
## Autoload: holds the state of the current run (deck, which combat, which boss) and builds
## each combat's enemy lineup. Scenes read from it and call its functions; it never touches scenes.

var config: RunConfig = preload("res://resources/run_config.tres")

var deck: Array[FigureData] = []
## 0 to combat_count() - 1 are the normal combats; combat_count() is the boss fight.
var combat_index := 0
var boss: BossData
## The enemies for the current combat.
var enemies: Array[FigureData] = []


func _ready() -> void:
	start_new_run()


func start_new_run() -> void:
	deck.clear()
	for i in config.deck_size:
		deck.append(config.starting_figure)
	combat_index = 0
	boss = config.registry.random_boss()
	_build_lineup()


func combat_count() -> int:
	return config.grunts_per_combat.size()


func is_boss_combat() -> bool:
	return combat_index >= combat_count()


## Call when the player wins a combat. Returns true if that was the boss (the run is won),
## otherwise moves on to the next combat.
func combat_won() -> bool:
	if is_boss_combat():
		return true
	combat_index += 1
	_build_lineup()
	return false


## The figures the reward screen offers: different from each other.
func offer_rewards() -> Array[FigureData]:
	return config.registry.random_draftable(config.reward_choices)


func replace_figure(slot: int, new_figure: FigureData) -> void:
	deck[slot] = new_figure


func progress_text() -> String:
	if is_boss_combat():
		return "Boss fight: %s" % boss.display_name
	return "Combat %d of %d" % [combat_index + 1, combat_count()]


func run_over_text(won: bool) -> String:
	var result := ""
	if won:
		result = "Run complete!\nYou beat %s" % boss.display_name
	elif is_boss_combat():
		result = "Run over\nYou reached the boss: %s" % boss.display_name
	else:
		result = "Run over\nYou reached combat %d of %d" % [combat_index + 1, combat_count()]
	return result + "\nTap to start a new run"


func _build_lineup() -> void:
	enemies.clear()
	var registry := config.registry
	if is_boss_combat():
		enemies.append_array(boss.enemies)
		return
	var grunt_count := config.grunts_per_combat[combat_index]
	for i in grunt_count:
		enemies.append(registry.random_grunt())
	enemies.append_array(registry.random_non_grunts(config.enemies_per_combat - grunt_count))
