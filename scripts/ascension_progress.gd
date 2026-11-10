class_name AscensionProgress
extends RefCounted
## Which Ascension levels the player has unlocked, saved in user://ascension.json between sessions.
## Level 0 is always open. Winning a run at your highest unlocked level unlocks the next (up to the config's max).

const PATH := "user://ascension.json"
## Version 2: a new level 5 ("Upgraded Enemies") was inserted, so an older save's level 5 or higher is shifted up by one.
const VERSION := 2
const FIRST_SHIFTED_LEVEL := 5

static var _unlocked := 0
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_unlocked = maxi(int(parsed.get("unlocked", 0)), 0)
		if int(parsed.get("version", 1)) < VERSION:  # migrate: players keep everything they had unlocked
			_unlocked = migrate_level(_unlocked)
			_save()


## A level number from before the level insertion (no version stored) -> the same level today.
static func migrate_level(level: int) -> int:
	return level + 1 if level >= FIRST_SHIFTED_LEVEL else level


static func _save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"unlocked": _unlocked, "version": VERSION}))


## The highest level the player may start a run at.
static func highest_unlocked() -> int:
	_load()
	return _unlocked


## Call when a run is won at `level`: unlocks the next level if this was the highest one (returns true if it did).
static func record_win(level: int, max_level: int) -> bool:
	_load()
	if level >= _unlocked and _unlocked < max_level:
		_unlocked = mini(level + 1, max_level)
		_save()
		return true
	return false
