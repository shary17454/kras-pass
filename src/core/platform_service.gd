extends Node
## Device and application lifecycle. Autoload name: `Platform`.
##
## Everything the game needs to know about *where* it is running, in one place:
## the safe area to keep the HUD out of the notch, whether this is a phone or a
## tablet, and what to do when iOS takes the app away mid-match.
##
## The three lifecycle events that matter on a handheld and are trivial to get
## wrong:
##   - going to background must pause a live match and flush the save, because
##     the OS may never give the process back;
##   - coming back must not silently resume a match the player is not looking at;
##   - a memory warning must free something before the OS kills us.

signal safe_area_changed(rect: Rect2i)
signal app_backgrounded()
signal app_foregrounded()
signal memory_warning()

enum Form { DESKTOP, PHONE, TABLET, TV }

var form: Form = Form.DESKTOP
var safe_area := Rect2i()
var is_mobile := false
var is_backgrounded := false

var _last_safe := Rect2i()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_detect_form()
	_refresh_safe_area()
	if not Engine.is_editor_hint():
		get_tree().root.size_changed.connect(_refresh_safe_area)
	Log.i("platform: %s, mobile=%s, safe=%s" % [_form_name(), is_mobile, safe_area], "Platform")


func _detect_form() -> void:
	var os_name := OS.get_name()
	is_mobile = os_name in ["iOS", "Android"]
	if os_name == "tvOS":
		form = Form.TV
		return
	if not is_mobile:
		form = Form.DESKTOP
		return
	# The split that actually matters for layout is physical size, not model
	# name: a tablet gets larger touch targets and can host four players.
	var model := OS.get_model_name().to_lower()
	form = Form.TABLET if model.contains("ipad") or _screen_is_large() else Form.PHONE


func _screen_is_large() -> bool:
	var dpi := DisplayServer.screen_get_dpi()
	if dpi <= 0:
		return false
	var px := DisplayServer.screen_get_size()
	var inches := Vector2(px).length() / float(dpi)
	return inches >= 7.0


func _form_name() -> String:
	return ["desktop", "phone", "tablet", "tv"][int(form)]


# --- safe area -------------------------------------------------------------

## The usable rectangle in pixels, excluding notch, Dynamic Island and the home
## indicator. On desktop this is the whole window.
func _refresh_safe_area() -> void:
	var full := Rect2i(Vector2i.ZERO, DisplayServer.window_get_size())
	if is_mobile:
		var reported := DisplayServer.get_display_safe_area()
		safe_area = reported if reported.size.x > 0 and reported.size.y > 0 else full
	else:
		safe_area = full
	if safe_area != _last_safe:
		_last_safe = safe_area
		safe_area_changed.emit(safe_area)


## Safe-area insets in *stretched* UI units, which is what a Control needs.
## Returns left, top, right, bottom.
func safe_insets() -> Vector4:
	var window := Vector2(DisplayServer.window_get_size())
	if window.x <= 0.0 or window.y <= 0.0 or not is_mobile:
		return Vector4.ZERO
	var ui := Vector2(get_viewport().get_visible_rect().size)
	var k := ui / window
	var a := safe_area
	return Vector4(
		float(a.position.x) * k.x,
		float(a.position.y) * k.y,
		float(window.x - (a.position.x + a.size.x)) * k.x,
		float(window.y - (a.position.y + a.size.y)) * k.y
	)


## Extra margin a full-screen UI should add so nothing lands under a notch.
## Landscape phones put the notch on one side, so this is deliberately not
## symmetric.
func ui_margin(base: int = 56) -> Dictionary:
	var i := safe_insets()
	return {
		"left": base + int(ceil(i.x)),
		"top": base + int(ceil(i.y)),
		"right": base + int(ceil(i.z)),
		"bottom": base + int(ceil(i.w)),
	}


# --- lifecycle -------------------------------------------------------------

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_on_background()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_on_foreground()
		NOTIFICATION_OS_MEMORY_WARNING:
			_on_memory_warning()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_on_background()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_on_foreground()


func _on_background() -> void:
	if is_backgrounded:
		return
	is_backgrounded = true
	# Persist first: on iOS the process may be terminated without another
	# callback, so anything not written now is lost.
	SaveSystem.flush()
	AudioManager.set_suspended(true)
	app_backgrounded.emit()
	Log.d("app backgrounded", "Platform")


func _on_foreground() -> void:
	if not is_backgrounded:
		return
	is_backgrounded = false
	AudioManager.set_suspended(false)
	_refresh_safe_area()
	app_foregrounded.emit()
	Log.d("app foregrounded", "Platform")


func _on_memory_warning() -> void:
	Log.w("OS memory warning — draining caches", "Platform")
	Pool.drain()
	MeshFactory.clear_cache()
	memory_warning.emit()


## True when the app should refuse to run a live match — used by MatchScene to
## auto-pause rather than simulating a game nobody can see.
func should_halt_gameplay() -> bool:
	return is_backgrounded
