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
## How many flicks the enemy side takes each turn in the current combat.
var enemy_flicks_per_turn := 1
## True when the enemies start in one straight row (The Wall).
var enemies_in_row := false
## The arena layout for the current combat.
var arena: ArenaData
var money := 0
## What the last won combat paid: {figures, base, bonus, total}.
var last_income := {"figures": 0, "base": 0, "bonus": 0, "total": 0}
var shop_offers: Array[ShopOffer] = []
var shop_done := false  # visited (and left) the shop this run


func _ready() -> void:
	start_new_run()


func start_new_run() -> void:
	deck.clear()
	for i in config.deck_size:
		deck.append(config.starting_figure)
	combat_index = 0
	money = config.starting_money
	last_income = {"figures": 0, "base": 0, "bonus": 0, "total": 0}
	shop_offers.clear()
	shop_done = false
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


## Pays for a won combat: income_per_figure for each figure still on the table, plus each figure's
## own income_bonus (Cha-ching). Call it before combat_won().
func award_income(figures_on_table: Array[FigureData]) -> void:
	var base := figures_on_table.size() * config.income_per_figure
	var bonus := 0
	for figure in figures_on_table:
		bonus += figure.income_bonus
	last_income = {"figures": figures_on_table.size(), "base": base, "bonus": bonus, "total": base + bonus}
	money += base + bonus


func income_text() -> String:
	var text := "Earned $%d: $%d for %d figures" % [last_income.total, last_income.base, last_income.figures]
	if last_income.bonus > 0:
		text += ", +$%d bonus" % last_income.bonus
	return text + ". You have $%d." % money


func spend(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	return true


## True while the optional shop is on offer: between the combats before and after config.shop_position.
func shop_available() -> bool:
	return config.shop != null and combat_index == config.shop_position and not shop_done and not is_boss_combat()


## Opens the shop: its stock is rolled once and kept until the shop is left.
func enter_shop() -> void:
	if shop_offers.is_empty():
		shop_offers = config.shop.make_offers(config.registry)


func leave_shop() -> void:
	shop_done = true


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
		enemy_flicks_per_turn = boss.enemy_flicks_per_turn
		enemies_in_row = boss.straight_row
	else:
		var grunt_count := config.grunts_per_combat[combat_index]
		for i in grunt_count:
			enemies.append(registry.random_grunt())
		enemies.append_array(registry.random_non_grunts(config.enemies_per_combat - grunt_count))
		enemy_flicks_per_turn = 1
		enemies_in_row = false
		if combat_index < config.enemy_flicks_per_combat.size():
			enemy_flicks_per_turn = config.enemy_flicks_per_combat[combat_index]
	_pick_arena()


## Random layout from the pool, not the same as last time, and only ones a creeping boss can use
## when there is one.
func _pick_arena() -> void:
	var has_creeper := false
	for enemy in enemies:
		if enemy.creep_distance > 0.0:
			has_creeper = true
	var candidates: Array[ArenaData] = []
	for candidate in config.arenas:
		if candidate != arena and (candidate.creeper_safe or not has_creeper):
			candidates.append(candidate)
	if candidates.is_empty():
		candidates = config.arenas
	arena = candidates.pick_random() if not candidates.is_empty() else null
