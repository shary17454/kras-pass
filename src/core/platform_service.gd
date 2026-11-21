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
var _safe_poll_elapsed := 0.0
var _metrics_bridge: Object
var _metrics_pending := false
var _metrics_discard := false
var _metrics_age := 0.0
var _metrics_size := Vector2i.ZERO
var _observed_size := Vector2i.ZERO
var _native_pane := Rect2()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_detect_form()
	if is_mobile:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)
	_update_content_size()
	_init_metrics_bridge()
	_refresh_safe_area()
	if not Engine.is_editor_hint():
		get_tree().root.size_changed.connect(_update_content_size)
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


func _update_content_size() -> void:
	var window := get_tree().root
	var base := Vector2i(720, 1280) if window.size.x < window.size.y else Vector2i(1920, 1080)
	if window.content_scale_size != base:
		window.content_scale_size = base


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

func _process(delta: float) -> void:
	if not is_mobile or is_backgrounded:
		return
	if _metrics_pending:
		_metrics_age += delta
		if _metrics_age >= 1.0:
			# Without request IDs, never overlap a timed-out request with a new one.
			_metrics_bridge.disconnect("viewport_metrics_received", _on_viewport_metrics)
			_metrics_bridge = null
			_metrics_pending = false
			_native_pane = Rect2()
	# Insets can change without a window resize (for example, system chrome).
	_safe_poll_elapsed += delta
	if _safe_poll_elapsed >= 0.25:
		_safe_poll_elapsed = 0.0
		_refresh_safe_area()


## The usable rectangle in pixels, excluding notch, Dynamic Island and the home
## indicator. On desktop this is the whole window.
func _refresh_safe_area() -> void:
	var full := Rect2i(Vector2i.ZERO, get_tree().root.size)
	if _observed_size != full.size:
		_observed_size = full.size
		if _metrics_pending:
			_metrics_discard = true
	if is_mobile:
		var reported := DisplayServer.get_display_safe_area()
		var clipped := Rect2i()
		if reported.has_area() and full.has_area():
			clipped = reported.intersection(full)
		safe_area = clipped if clipped.has_area() else full
		if _native_pane.has_area():
			var pane := normalized_pane_pixels(_native_pane, full.size)
			if pane.has_area():
				safe_area = pane
	else:
		safe_area = full
	if safe_area != _last_safe:
		_last_safe = safe_area
		safe_area_changed.emit(safe_area)
	_request_viewport_metrics()


func _init_metrics_bridge() -> void:
	if OS.get_name() != "iOS" or not ClassDB.class_exists("KrasAppleBridge"):
		return
	var bridge: Object = ClassDB.instantiate("KrasAppleBridge")
	if bridge == null or not bridge.has_method("request_viewport_metrics") or not bridge.has_signal("viewport_metrics_received"):
		return
	_metrics_bridge = bridge
	_metrics_bridge.connect("viewport_metrics_received", _on_viewport_metrics)


func _request_viewport_metrics() -> void:
	if _metrics_bridge == null or _metrics_pending or is_backgrounded:
		return
	_metrics_pending = true
	_metrics_discard = false
	_metrics_age = 0.0
	_metrics_size = get_tree().root.size
	_metrics_bridge.call("request_viewport_metrics")


func _on_viewport_metrics(metrics: Dictionary) -> void:
	if not _metrics_pending:
		return
	_metrics_pending = false
	if _metrics_discard or _metrics_size != get_tree().root.size or is_backgrounded:
		return
	if metrics.get("valid", false) != true:
		return # A temporarily missing view must not erase the last safe pane.
	var ui := get_viewport().get_visible_rect().size
	var gap := Vector2(8, 8) / ui.max(Vector2.ONE)
	var pane := pane_for_metrics(metrics, _native_pane, gap)
	if not pane.has_area():
		return
	_native_pane = pane
	# Apply immediately, but leave subsequent requests to the 250 ms poll.
	var pixels := normalized_pane_pixels(pane, get_tree().root.size)
	if pixels.has_area() and pixels != _last_safe:
		safe_area = pixels
		_last_safe = pixels
		safe_area_changed.emit(pixels)


static func valid_metrics_rect(rect: Rect2) -> bool:
	return rect.position.is_finite() and rect.size.is_finite() and rect.end.is_finite() and rect.has_area()


static func normalized_pane_pixels(pane: Rect2, window: Vector2i) -> Rect2i:
	if not valid_metrics_rect(pane) or window.x <= 0 or window.y <= 0:
		return Rect2i()
	# Round inward so fractional native edges cannot put controls in a reserved strip.
	var start := Vector2i((pane.position * Vector2(window)).ceil())
	var finish := Vector2i((pane.end * Vector2(window)).floor())
	return Rect2i(start, (finish - start).max(Vector2i.ZERO))


## Pure normalized geometry. Enumerate obstacle x edges and free y intervals;
## unlike greedy splitting, this retains the largest pane across overlapping cuts.
static func pane_for_metrics(metrics: Dictionary, previous := Rect2(), minimum_gap := Vector2(0.00001, 0.00001)) -> Rect2:
	if metrics.get("valid", false) != true or not metrics.get("safe_rect") is Rect2:
		return Rect2()
	var safe: Rect2 = metrics["safe_rect"]
	if not valid_metrics_rect(safe):
		return Rect2()
	safe = safe.intersection(Rect2(0, 0, 1, 1))
	if not safe.has_area():
		return Rect2()
	var blockers: Array[Rect2] = []
	var xs: Array[float] = [safe.position.x, safe.end.x]
	for key in ["occlusions", "divisions"]:
		if not metrics.get(key, []) is Array:
			return Rect2()
		if metrics.get(key, []).size() > 32:
			return Rect2()
		for item in metrics.get(key, []):
			if not item is Rect2:
				return Rect2()
			var reserved: Rect2 = item
			if key == "divisions" and reserved.position.is_finite() and reserved.size.is_finite() and reserved.size.x >= 0 and reserved.size.y >= 0:
				# UIKit may report a separating line rather than a positive-area strip.
				if reserved.size == Vector2.ZERO:
					continue
				var gap := minimum_gap if minimum_gap.is_finite() else Vector2(0.00001, 0.00001)
				gap = gap.max(Vector2(0.00001, 0.00001))
				if reserved.size.x == 0:
					reserved.position.x -= gap.x * 0.5
					reserved.size.x = gap.x
				if reserved.size.y == 0:
					reserved.position.y -= gap.y * 0.5
					reserved.size.y = gap.y
			if not valid_metrics_rect(reserved):
				return Rect2()
			var cut: Rect2 = reserved.intersection(safe)
			if cut.has_area():
				blockers.append(cut)
				xs.append(cut.position.x)
				xs.append(cut.end.x)
	# A malformed report must not stall the game thread.
	if blockers.size() > 32:
		return Rect2()
	xs.sort()
	blockers.sort_custom(func(a: Rect2, b: Rect2): return a.position.y < b.position.y)
	var best := Rect2()
	for left in xs.size():
		for right in range(left + 1, xs.size()):
			if xs[right] <= xs[left]:
				continue
			var top := safe.position.y
			for cut in blockers:
				if cut.position.x >= xs[right] or cut.end.x <= xs[left]:
					continue
				var candidate := Rect2(xs[left], top, xs[right] - xs[left], maxf(0.0, cut.position.y - top))
				best = _prefer_pane(best, candidate, previous)
				top = maxf(top, cut.end.y)
			var tail := Rect2(xs[left], top, xs[right] - xs[left], maxf(0.0, safe.end.y - top))
			best = _prefer_pane(best, tail, previous)
	return best


static func _prefer_pane(best: Rect2, candidate: Rect2, previous: Rect2) -> Rect2:
	if not candidate.has_area():
		return best
	var delta := candidate.get_area() - best.get_area()
	if delta > 0.0000001:
		return candidate
	if absf(delta) <= 0.0000001 and previous.has_area():
		if candidate.intersection(previous).get_area() > best.intersection(previous).get_area():
			return candidate
	return best


## Safe-area insets in *stretched* UI units, which is what a Control needs.
## Returns left, top, right, bottom.
func safe_insets() -> Vector4:
	if not is_mobile:
		return Vector4.ZERO
	return safe_insets_for_rect(safe_area, Vector2(get_tree().root.size), get_viewport().get_visible_rect().size)


## canvas_items/expand uses the full window; preserve each edge independently.
func safe_insets_for_rect(rect: Rect2i, window: Vector2, ui: Vector2) -> Vector4:
	if not window.is_finite() or not ui.is_finite() or window.x <= 0.0 or window.y <= 0.0 or ui.x <= 0.0 or ui.y <= 0.0 or not rect.has_area():
		return Vector4.ZERO
	var full := Rect2(Vector2.ZERO, window)
	var a := Rect2(rect).intersection(full)
	if not a.has_area():
		return Vector4.ZERO
	var k := ui / window
	return Vector4(
		a.position.x * k.x,
		a.position.y * k.y,
		(window.x - a.end.x) * k.x,
		(window.y - a.end.y) * k.y
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
	if _metrics_pending:
		_metrics_discard = true
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
	Pool.trim_idle()
	MeshFactory.clear_cache()
	memory_warning.emit()


## True when the app should refuse to run a live match — used by MatchScene to
## auto-pause rather than simulating a game nobody can see.
func should_halt_gameplay() -> bool:
	return is_backgrounded
