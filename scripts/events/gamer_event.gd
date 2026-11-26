class_name GamerEvent
extends EventScreen
## The Gamer: offers some of the four old minigames (Bocce, Curling, Bowling, Mini-Golf, `RunConfig.gamer_games`);
## pick one to play. A win pays money + an Upgrade + a finish; a loss makes the next fight harder; a tie gives nothing.


func start() -> void:
	var cfg := _config()
	var games: Array[EventData] = []
	games.assign(RunManager.config.gamer_games)
	games.shuffle()
	frame.title.text = "The Gamer"
	frame.subtitle.text = "Win: $%d, an Upgrade and a finish. Lose: the next fight is harder." % cfg.win_money
	for i in mini(cfg.gamer_choices, games.size()):
		add_card("%s\n%s" % [games[i].display_name, games[i].description], null, 170.0, _play.bind(games[i]))
	frame.add_action("Leave", leave)


func _play(game: EventData) -> void:
	get_tree().change_scene_to_packed(game.scene)


func _config() -> MinigameConfig:
	return RunManager.config.minigames if RunManager.config.minigames != null else MinigameConfig.new()
