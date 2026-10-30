class_name SafeArea
extends RefCounted
## The parts of the screen to keep clear (camera cutout, rounded corners, gesture bar), in the game's
## own 1080-wide units. Zero on desktop and in the editor.


## {top, bottom, left, right}: how far in from each screen edge usable UI should start.
static func insets() -> Dictionary:
	var result := {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
	if OS.has_feature("web"):
		return _web_insets(result)
	if not (OS.has_feature("android") or OS.has_feature("ios")):
		return result
	var window := DisplayServer.window_get_size()
	var screen := DisplayServer.screen_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if window.x <= 0 or screen.x <= 0 or safe.size.x <= 0:
		return result
	# canvas_items + keep_width: everything is scaled so the window is exactly 1080 units wide.
	var scale := float(window.x) / float(ProjectSettings.get_setting("display/window/size/viewport_width", 1080))
	result.top = clampf(safe.position.y / scale, 0.0, 220.0)
	result.left = clampf(safe.position.x / scale, 0.0, 120.0)
	result.bottom = clampf((screen.y - safe.end.y) / scale, 0.0, 220.0)
	result.right = clampf((screen.x - safe.end.x) / scale, 0.0, 120.0)
	return result


static var _web_cache := {}
static var _web_cache_ms := -10000


## In a browser (iPhone web app) the page measures the notch and home bar with CSS `env(safe-area-inset-*)`
## and hands them over in game units (web/shell.html: `window.flickSafeInsets`). Asked at most twice a second.
static func _web_insets(result: Dictionary) -> Dictionary:
	var now := Time.get_ticks_msec()
	if now - _web_cache_ms < 500 and not _web_cache.is_empty():
		return _web_cache
	_web_cache_ms = now
	_web_cache = result
	var raw = JavaScriptBridge.eval("window.flickSafeInsets ? window.flickSafeInsets() : ''")
	if raw is String and raw != "":
		var parsed = JSON.parse_string(raw)
		if parsed is Dictionary:
			result.top = clampf(float(parsed.get("top", 0.0)), 0.0, 220.0)
			result.left = clampf(float(parsed.get("left", 0.0)), 0.0, 120.0)
			result.bottom = clampf(float(parsed.get("bottom", 0.0)), 0.0, 220.0)
			result.right = clampf(float(parsed.get("right", 0.0)), 0.0, 120.0)
	_web_cache = result
	return result
