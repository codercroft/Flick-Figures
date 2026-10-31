extends Node
## Plays every sound in the game. It is an autoload (`AudioManager`), so any script can call
## `AudioManager.play_clack(speed)` and so on. All sounds are plain files you can replace:
##   audio/sfx/*.wav  game sounds (clack_plastic, clack_wall, boom, implosion, fall_pop, flick)
##   audio/ui/*.wav   menu sounds (tap, confirm, back, purchase, reveal, fanfare)
## Drop in a new file with the same name (wav or ogg of the same base name is not searched: keep the .wav
## name, or change the file names in SFX_FILES / UI_FILES below). A missing file just plays nothing.
## The placeholders were made by tools/generate_sounds.py.
## Game sounds go through the "SFX" bus and menu sounds through the "UI" bus, each with its own volume;
## `muted` silences both. The settings are saved in user://audio.cfg.

signal settings_changed

const SFX_DIR := "res://audio/sfx/"
const UI_DIR := "res://audio/ui/"
const SETTINGS_PATH := "user://audio.cfg"
const SFX_BUS := "SFX"
const UI_BUS := "UI"
const VOICES := 10  # how many sounds can play at once on each bus

const SFX_FILES := ["clack_plastic", "clack_wall", "boom", "implosion", "fall_pop", "flick"]
const UI_FILES := ["tap", "confirm", "back", "purchase", "reveal", "fanfare"]

## Button texts (lowercase, start of text) that get the "back" or "confirm" sound instead of the plain tap.
const BACK_WORDS := ["back", "leave", "close", "skip", "cancel", "discard", "no "]
const CONFIRM_WORDS := ["done", "confirm", "continue", "ok", "take", "start", "yes", "accept"]

## Volume of game sounds (0 to 1).
@export_range(0.0, 1.0) var sfx_volume := 0.8:
	set(value):
		sfx_volume = clampf(value, 0.0, 1.0)
		_apply_volumes()
## Volume of menu sounds (0 to 1).
@export_range(0.0, 1.0) var ui_volume := 0.8:
	set(value):
		ui_volume = clampf(value, 0.0, 1.0)
		_apply_volumes()
## Silences everything.
var muted := false:
	set(value):
		muted = value
		_apply_volumes()

@export_group("Figure clacks")
## Hits slower than this (px/s) make no sound.
@export var clack_min_speed := 120.0
## Hits at this speed or faster are full volume and highest pitch.
@export var clack_max_speed := 2000.0
@export var clack_quiet_db := -20.0
@export var clack_loud_db := -3.0
## Pitch range with impact speed (slow = low, fast = high), plus a random wobble of +/- this much.
@export var clack_pitch_low := 0.85
@export var clack_pitch_high := 1.25
@export var pitch_variation := 0.07
## Throttle: after a clack, the next one within this many ms is skipped unless it is clearly louder.
@export var clack_gap_ms := 40
@export var wall_gap_ms := 50

@export_group("Explosions")
## An explosion with this radius (px) or more is full size.
@export var boom_full_radius := 360.0
@export var boom_quiet_db := -12.0
@export var boom_loud_db := 0.0
@export var boom_gap_ms := 70

@export_group("Other game sounds")
@export var flick_db := -9.0
@export var fall_db := -8.0
@export var implosion_db := -4.0
@export var ui_db := -4.0

var _sfx_players: Array[AudioStreamPlayer] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _next_sfx := 0
var _next_ui := 0
var _streams := {}
var _last_ms := {}  # sound name -> when it last played
var _last_strength := {}  # sound name -> how loud that was (0 to 1)
var _pending_button := ""  # the button sound waiting for the end of the frame (an explicit sound cancels it)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_add_bus(SFX_BUS)
	_add_bus(UI_BUS)
	for i in VOICES:
		_sfx_players.append(_make_player(SFX_BUS))
		_ui_players.append(_make_player(UI_BUS))
	for file_name in SFX_FILES:
		_streams[file_name] = _load(SFX_DIR + file_name + ".wav")
	for file_name in UI_FILES:
		_streams[file_name] = _load(UI_DIR + file_name + ".wav")
	_load_settings()
	_apply_volumes()
	# Every Button anywhere gets a tap / back / confirm sound automatically.
	get_tree().node_added.connect(_on_node_added)


# --- Game sounds -------------------------------------------------------------------------

## Two figures hit: louder and higher with speed, a little random pitch so repeats differ.
func play_clack(speed: float) -> void:
	_play_hit("clack_plastic", speed, clack_gap_ms)


## A figure hit a wall or pin.
func play_wall(speed: float) -> void:
	_play_hit("clack_wall", speed, wall_gap_ms)


## An explosion of this radius: bigger = louder and deeper.
func play_boom(radius: float) -> void:
	var size := clampf(radius / boom_full_radius, 0.2, 1.0)
	if not _throttle("boom", boom_gap_ms, size):
		return
	_play(_sfx_players, "boom", lerpf(boom_quiet_db, boom_loud_db, size), lerpf(1.25, 0.85, size) * _wobble(), true)


func play_implosion() -> void:
	if _throttle("implosion", 150, 1.0):
		_play(_sfx_players, "implosion", implosion_db, _wobble(), true)


## A figure left the table.
func play_fall() -> void:
	if _throttle("fall_pop", 60, 1.0):
		_play(_sfx_players, "fall_pop", fall_db, _wobble(), true)


## A flick was released; `speed` is the launch speed in px/s.
func play_flick(speed: float) -> void:
	var strength := clampf(speed / clack_max_speed, 0.0, 1.0)
	if _throttle("flick", 40, strength):
		_play(_sfx_players, "flick", flick_db + 5.0 * strength, lerpf(0.9, 1.2, strength) * _wobble(), true)


# --- Menu sounds -------------------------------------------------------------------------

func play_tap() -> void:
	_play_ui("tap")


func play_confirm() -> void:
	_play_ui("confirm")


func play_back() -> void:
	_play_ui("back")


func play_purchase() -> void:
	_play_ui("purchase")


## A new reward is shown.
func play_reveal() -> void:
	_play_ui("reveal")


## A combat was won.
func play_fanfare() -> void:
	_play_ui("fanfare")


# --- Settings ----------------------------------------------------------------------------

func toggle_mute() -> void:
	muted = not muted
	_save_settings()
	settings_changed.emit()
	if not muted:
		play_tap()


func set_sfx_volume(value: float) -> void:
	sfx_volume = value
	_save_settings()
	settings_changed.emit()


func set_ui_volume(value: float) -> void:
	ui_volume = value
	_save_settings()
	settings_changed.emit()


func _load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(SETTINGS_PATH) != OK:
		return
	sfx_volume = file.get_value("audio", "sfx_volume", sfx_volume)
	ui_volume = file.get_value("audio", "ui_volume", ui_volume)
	muted = file.get_value("audio", "muted", muted)


func _save_settings() -> void:
	var file := ConfigFile.new()
	file.set_value("audio", "sfx_volume", sfx_volume)
	file.set_value("audio", "ui_volume", ui_volume)
	file.set_value("audio", "muted", muted)
	file.save(SETTINGS_PATH)


func _apply_volumes() -> void:
	for pair in [[SFX_BUS, sfx_volume], [UI_BUS, ui_volume]]:
		var index := AudioServer.get_bus_index(pair[0])
		if index < 0:
			continue  # (a setter ran before the buses exist)
		AudioServer.set_bus_mute(index, muted)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(pair[1], 0.0001)))


# --- Internals ---------------------------------------------------------------------------

func _add_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


func _make_player(bus_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus_name
	add_child(player)
	return player


func _load(path: String) -> AudioStream:
	return load(path) if ResourceLoader.exists(path) else null


func _wobble() -> float:
	return 1.0 + randf_range(-pitch_variation, pitch_variation)


func _play_hit(sound: String, speed: float, gap_ms: int) -> void:
	if speed < clack_min_speed:
		return
	var strength := clampf(inverse_lerp(clack_min_speed, clack_max_speed, speed), 0.0, 1.0)
	if not _throttle(sound, gap_ms, strength):
		return
	_play(_sfx_players, sound, lerpf(clack_quiet_db, clack_loud_db, pow(strength, 0.7)),
			lerpf(clack_pitch_low, clack_pitch_high, strength) * _wobble(), true)


## True if `sound` may play now: it has been quiet for `gap_ms`, or this one is clearly louder than the last.
func _throttle(sound: String, gap_ms: int, strength: float) -> bool:
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(sound, -100000)) < gap_ms and strength < float(_last_strength.get(sound, 0.0)) * 1.5:
		return false
	_last_ms[sound] = now
	_last_strength[sound] = strength
	return true


func _play_ui(sound: String) -> void:
	_pending_button = ""  # an explicit sound replaces the automatic button tap of this press
	_play(_ui_players, sound, ui_db, 1.0, false)


func _play(players: Array[AudioStreamPlayer], sound: String, volume_db: float, pitch: float, is_sfx: bool) -> void:
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		return
	var index := _next_sfx if is_sfx else _next_ui
	var player := players[index]
	if is_sfx:
		_next_sfx = (_next_sfx + 1) % VOICES
	else:
		_next_ui = (_next_ui + 1) % VOICES
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button != null and not button.is_in_group("no_ui_sound"):
		button.pressed.connect(_on_button_pressed.bind(button))


## Chooses back / confirm / tap from the button's text. Waits until the end of the frame so a screen that
## plays its own sound for the press (purchase, reveal) can replace it.
func _on_button_pressed(button: BaseButton) -> void:
	var text := ""
	if button is Button:
		text = (button as Button).text.strip_edges().to_lower()
	var kind := "tap"
	for word in BACK_WORDS:
		if text.begins_with(word):
			kind = "back"
	for word in CONFIRM_WORDS:
		if text.begins_with(word):
			kind = "confirm"
	_pending_button = kind
	_flush_button.call_deferred()


func _flush_button() -> void:
	if _pending_button == "":
		return
	var kind := _pending_button
	_pending_button = ""
	_play(_ui_players, kind, ui_db, 1.0, false)
