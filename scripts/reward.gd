extends Control
## Reward screens after a won combat, a treasure node or a boss. RunManager.reward_steps lists what
## is on offer; each drop is shown ONE AT A TIME, and every step has a skip option. Chance drops get a
## little "Lucky!" flourish. Kinds: "figures" (pick 1 of N, then which figure it replaces), "relic"
## (a random relic), "relics" (pick 1 of N), "power", "equipment", "finish" (pick which figure gets
## it), "upgrade" (pick a figure, then the next tier on one of its two upgrade paths) and "treasure" (the chest: always a relic).
## All chances and amounts are in RewardConfig. The choices are in the middle of the screen; Take/Skip/Back are pinned at the bottom (see ScreenFrame).

const MAP_SCENE := "res://scenes/map.tscn"
const OFFER_CARD_HEIGHT := 240.0
const REPLACE_CARD_HEIGHT := 150.0
const ITEM_CARD_HEIGHT := 190.0

var _steps: Array[Dictionary] = []
var _offers: Array[FigureData] = []
var _chosen: FigureData
var _lucky := false  # the current step was a chance drop

var frame := ScreenFrame.new()
var column: VBoxContainer  # the cards (frame.content); the buttons go to frame.actions at the bottom
var title: Label
var earned_label: Label


func _ready() -> void:
	add_child(frame)
	column = frame.content
	title = frame.title
	earned_label = frame.subtitle
	_steps = RunManager.reward_steps.duplicate()
	earned_label.text = _earned_text()
	if RunManager.harder_note != "" and RunManager.node != null and RunManager.node.type != MapNode.Type.EVENT:
		earned_label.text += "\n" + RunManager.harder_note  # the harder fight's bonus
	_next_step()


func _earned_text() -> String:
	if RunManager.node == null:
		return ""
	match RunManager.node.type:
		MapNode.Type.COMBAT, MapNode.Type.ELITE:
			return RunManager.income_text()
		MapNode.Type.BOSS:
			return "Boss defeated! " + RunManager.income_text()
		MapNode.Type.EVENT:
			return RunManager.event_reward_text
	return ""


var _relic_step := {}  # the current step (the relic choices read its fields)


func _next_step() -> void:
	if _steps.is_empty():
		RunManager.finish_rewards()
		get_tree().change_scene_to_file(MAP_SCENE)
		return
	var step: Dictionary = _steps.pop_front()
	_relic_step = step
	_lucky = step.get("lucky", false)
	AudioManager.play_reveal()  # a new reward is shown
	match step.kind:
		"figures":
			_offers = RunManager.offer_rewards(step.get("boss", false))
			_show_offers()
		"relics":
			_show_relic_choices()
		"relic":
			_show_found_relic("You found a relic!")
		"power":
			_show_power()
		"equipment":
			_show_equipment("You found equipment!")
		"finish":
			_show_finish()
		"upgrade":
			_relic_step = step
			_show_upgrade()
		"treasure":
			_show_treasure()
		_:
			_next_step()


# --- Figures: pick 1 of N (or skip), then which figure it replaces --------------

func _show_offers() -> void:
	_clear_cards()
	title.text = "Pick a figure"
	# With more than 3 choices (Trophy Case) the cards shrink so they all fit.
	var card_height := minf(OFFER_CARD_HEIGHT, 900.0 / maxi(_offers.size(), 1))
	for offer in _offers:
		var card := _add_card(offer, card_height)
		card.pressed.connect(_on_offer_chosen.bind(offer))
	_add_button("Skip", _next_step)


func _on_offer_chosen(offer: FigureData) -> void:
	_chosen = offer
	_show_replacements()


func _show_replacements() -> void:
	_clear_cards()
	title.text = "Replace which figure with %s?" % _chosen.display_name
	# Your deck as it sits on the table: tap the slot to replace, then confirm.
	var strip := DeckStrip.new()
	column.add_child(strip)
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 34)
	info.text = "Tap the figure to replace."
	column.add_child(info)
	var confirm := frame.add_action("Replace", func(): _on_replace_chosen(strip.selected))
	confirm.disabled = true
	strip.slot_pressed.connect(func(slot: int):
		info.text = DeckStrip.describe_slot(slot)
		confirm.disabled = false)
	_add_button("Back", _show_offers)


func _on_replace_chosen(slot: int) -> void:
	RunManager.replace_figure(slot, _chosen)
	_next_step()


# --- Relics --------------------------------------------------------------------

## Boss: pick 1 of N relics you don't have yet.
func _show_relic_choices() -> void:
	var choices: Array[RelicData] = []
	if _relic_step.get("elite", false):  # act 3 elites: N random new relics (never Boss ones)
		choices = RunManager.random_new_relics(int(_relic_step.get("count", 3)))
	else:
		choices = RunManager.random_boss_relics(RunManager.config.rewards.boss_relic_choices)
	if choices.is_empty():
		_next_step()
		return
	_clear_cards()
	title.text = "Pick a relic"
	for relic in choices:
		var card := _add_card(null, ITEM_CARD_HEIGHT * 0.8, "%s (%s)\n%s" % [relic.display_name, relic.rarity_name(), relic.description])
		card.pressed.connect(_take_relic.bind(relic))
	_add_button("Skip", _next_step)


func _show_found_relic(heading: String, rare := false) -> void:
	var found: Array[RelicData] = []
	if rare:
		var rare_relic := RunManager.random_rare_relic()
		if rare_relic != null:
			found.append(rare_relic)
	else:
		found = RunManager.random_new_relics(1)
	if found.is_empty():
		_next_step()
		return
	_show_item(heading, "%s (%s)\n%s" % [found[0].display_name, found[0].rarity_name(), found[0].description], _take_relic.bind(found[0]))


func _take_relic(relic: RelicData) -> void:
	RunManager.add_relic(relic)
	_next_step()


# --- Powers, equipment, finishes ----------------------------------------------------

func _show_power() -> void:
	var power := RunManager.random_power()
	if power == null:
		_next_step()
		return
	var text := "%s\n%s" % [power.display_name, power.description]
	if RunManager.has_free_power_slot():
		_show_item("You found a power!", text, _take_power.bind(power))
	else:
		_show_power_swap(power, text)


func _take_power(power: PowerData) -> void:
	RunManager.add_power(power)
	_next_step()


## Slots are full: replace one of the held powers, or discard the new one.
func _show_power_swap(power: PowerData, text: String) -> void:
	_clear_cards()
	title.text = "Your power slots are full. Replace one?"
	_add_lucky_flourish()
	_add_card(null, ITEM_CARD_HEIGHT * 0.7, "NEW: " + text)
	for slot in RunManager.powers.size():
		var held: PowerData = RunManager.powers[slot]
		if held == null:
			continue
		var card := _add_card(null, 90.0, "Replace %s" % held.display_name)
		card.pressed.connect(_replace_power.bind(slot, power))
	_add_button("Discard the new power", _next_step)


func _replace_power(slot: int, power: PowerData) -> void:
	RunManager.powers[slot] = power
	_next_step()


func _show_equipment(heading: String) -> void:
	var item := RunManager.random_equipment()
	if item == null:
		_next_step()
		return
	_show_item(heading, "%s (%s)\n%s" % [item.display_name, item.rarity_name(), item.description], _take_equipment.bind(item))


func _take_equipment(item: EquipmentData) -> void:
	RunManager.add_equipment(item)
	_next_step()


## A random finish; taking it means choosing which figure gets it.
func _show_finish() -> void:
	var finish := RunManager.random_finish()
	if finish == null:
		_next_step()
		return
	_show_item("You found a finish!", "%s\n%s" % [finish.display_name, finish.description], _pick_figure_for.bind(finish))


## An Upgrade: pick one of your figures (the step can name one: `slot`), then its next tier on an open path.
func _show_upgrade() -> void:
	_clear_cards()
	var slot: int = _relic_step.get("slot", -1)
	if slot >= 0 and slot < RunManager.deck.size() and RunManager.can_upgrade(slot):
		_show_upgrade_tree(slot)
		return
	var slots := RunManager.upgradable_slots()
	if slots.is_empty():
		_show_message("None of your figures can take an upgrade.")
		return
	title.text = "Upgrade which figure?"
	var card_height := minf(REPLACE_CARD_HEIGHT, 900.0 / maxi(slots.size(), 1))
	for s in slots:
		var summary := RunManager.upgrade_summary(s)
		var card := _add_card(RunManager.deck[s], card_height, RunManager.deck[s].display_name + ("\n" + summary if summary != "" else ""))
		card.pressed.connect(_show_upgrade_tree.bind(s))
	_add_button("Skip", _next_step)


## Both paths as a tree: tap an available box, then Take it.
func _show_upgrade_tree(slot: int) -> void:
	_clear_cards()
	title.text = "%s: choose an upgrade" % RunManager.deck[slot].display_name
	var view := UpgradeTreeView.new()
	column.add_child(view)
	view.setup(RunManager.deck[slot], RunManager.deck_upgrade[slot])
	var take := func() -> void:
		if view.selected_state() != "available":
			title.text = "Pick a gold (available) box first"
			return
		RunManager.take_upgrade(slot, view.selected.x)
		_show_message("%s upgraded!" % RunManager.deck[slot].display_name)
	_add_button("Take it", take)
	_add_button("Skip", _next_step)


## Pick which figure gets a finish.
func _pick_figure_for(item: Resource) -> void:
	_clear_cards()
	title.text = "Give %s to which figure?" % item.display_name
	var card_height := minf(REPLACE_CARD_HEIGHT, 900.0 / maxi(RunManager.deck.size(), 1))
	for slot in RunManager.deck.size():
		var held: FinishData = RunManager.deck_finish[slot]
		var note := "\nreplaces %s" % held.display_name if held != null else ""
		var card := _add_card(RunManager.deck[slot], card_height, RunManager.deck[slot].display_name + note)
		card.pressed.connect(_apply_to_figure.bind(item, slot))
	_add_button("Skip", _next_step)


func _apply_to_figure(item: Resource, slot: int) -> void:
	RunManager.set_finish(slot, item)
	_show_message("%s got %s!" % [RunManager.deck[slot].display_name, item.display_name])


## Treasure chest: always a relic (if every relic is already held, equipment instead).
func _show_treasure() -> void:
	# The act 1 chest always holds a Rare relic.
	var rare := RunManager.act == 0
	if not RunManager.random_new_relics(1).is_empty():
		_show_found_relic("Treasure chest: a Rare relic!" if rare else "Treasure chest: a relic!", rare)
	elif RunManager.random_equipment() != null:
		_show_equipment("Treasure chest: equipment!")
	else:
		_next_step()


# --- Small building blocks ---------------------------------------------------------

## One drop with Take and Skip buttons (chance drops get the Lucky flourish).
func _show_item(heading: String, text: String, on_take: Callable) -> void:
	_clear_cards()
	title.text = heading
	_add_lucky_flourish()
	var card := _add_card(null, ITEM_CARD_HEIGHT, text)
	card.pressed.connect(on_take)
	_add_button("Take it", on_take)
	_add_button("Skip", _next_step)


## A small gold "Lucky!" that pops in above a chance drop.
func _add_lucky_flourish() -> void:
	if not _lucky:
		return
	var label := Label.new()
	label.text = "* Lucky! *"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 44)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	label.add_theme_color_override("font_outline_color", Color(0.3, 0.2, 0.0))
	label.add_theme_constant_override("outline_size", 8)
	label.custom_minimum_size = Vector2(0.0, 56.0)
	column.add_child(label)
	label.pivot_offset = Vector2(column.size.x / 2.0, 28.0)
	label.scale = Vector2(0.3, 0.3)
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2(1.25, 1.25), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.15)
	# After the pop it gently glows.
	var breathe := create_tween().set_loops()
	breathe.tween_interval(0.4)
	breathe.tween_property(label, "modulate", Color(1.0, 1.0, 0.7), 0.5)
	breathe.tween_property(label, "modulate", Color.WHITE, 0.5)


func _show_message(text: String) -> void:
	_clear_cards()
	title.text = text
	_add_button("Continue", _next_step)


func _add_card(data: FigureData, card_height: float, text := "") -> FigureCard:
	var card := FigureCard.new()
	card.setup(data, card_height, text)
	column.add_child(card)
	return card


func _add_button(text: String, action: Callable) -> void:
	frame.add_action(text, action)


func _clear_cards() -> void:
	frame.clear()
