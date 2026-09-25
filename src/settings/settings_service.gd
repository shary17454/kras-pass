extends Node
## Player-facing options. Autoload name: `UserSettings`.
##
## Holds audio levels, controls, graphics and accessibility. Every setter
## persists through SaveSystem and fires `changed` so live systems (audio buses,
## camera, UI theme) react without a restart.

signal changed(key: String, value)

const DEFAULTS := {
	## Set once the unlock phrase has been entered on this device; see
	## `src/progression/owner_key.gd`. Deliberately named for what it is rather
	## than for who it belongs to.
	"access_token": "",
	"volume_master": 0.9,
	"volume_music": 0.7,
	"music_enabled": true,
	"volume_sfx": 1.0,
	"volume_ui": 0.8,
	"volume_announcer": 0.8,
	"announcer_enabled": true,
	"vibration": true,
	"camera_sensitivity": 1.0,
	## How far back the shared camera sits, as a multiplier. The spec wants the
	## view wide enough to see rivals and hazards rather than glued to one
	## body, and how wide that needs to be depends on the screen it is played
	## on — a phone held at arm's length is not a television across a room.
	"camera_distance": 1.0,
	"camera_shake": 1.0,
	"graphics_quality": 2,  # 0 low, 1 medium, 2 high, 3 ultra
	"fps_limit": 60,  # Preferred ceiling; presentation remains display-limited.
	"battery_saver": false,
	"language": "",  # "" = no explicit choice yet -> Arabic, the primary
	"text_scale": 1.0,
	"high_contrast": false,
	"reduce_flashes": false,
	"reduce_effects": false,
	"colorblind_mode": 0,  # 0 off, 1 protanopia, 2 deuteranopia, 3 tritanopia
	"show_control_hints": true,
	"tutorials_seen": {},
	"bindings": {},
	"replay_capture": true,
	"touch_controls": "auto",   # auto | on | off
	"touch_scale": 1.0,
	"touch_dead_zone": 0.14,
	"touch_positions": {},
	"touch_opacity": 0.5,
	"touch_left_handed": false,
	# Goal Guard has three independent touch zones. Keeping these separate lets
	# a player move one action without reversing the rest of the game controls.
	"touch_keeper_move_side": "left",
	"touch_keeper_dash_side": "right",
	"touch_keeper_return_side": "right",
}

var _values := {}


func _ready() -> void:
	_values = DEFAULTS.duplicate(true)
	var stored := SaveSystem.settings()
	for k in stored.keys():
		if DEFAULTS.has(k):
			_values[k] = stored[k]
	if String(_values["language"]) == "":
		_values["language"] = Loc.locale
	Loc.set_locale(String(_values["language"]))
	_apply_engine_settings()


func get_value(key: String):
	if bool(_values.get("battery_saver", false)):
		if key == "fps_limit":
			return 30
		if key == "graphics_quality":
			return 0
		if key == "reduce_effects":
			return true
	return _values.get(key, DEFAULTS.get(key))


func set_value(key: String, value) -> void:
	if not DEFAULTS.has(key):
		Log.w("unknown setting '%s'" % key, "Settings")
		return
	if _values.get(key) == value:
		return
	_values[key] = value
	_persist()
	if key == "language":
		Loc.set_locale(String(value))
	elif key in ["fps_limit", "graphics_quality", "battery_saver"]:
		_apply_engine_settings()
	changed.emit(key, value)


func toggle(key: String) -> void:
	set_value(key, not bool(get_value(key)))


func apply_touch_preset(id: String) -> void:
	if id not in ["normal", "small", "large", "left"]:
		return
	_values["touch_scale"] = 0.8 if id == "small" else 1.3 if id == "large" else 1.0
	_values["touch_left_handed"] = id == "left"
	_values["touch_positions"] = {}
	_values["touch_keeper_move_side"] = "right" if id == "left" else "left"
	_values["touch_keeper_dash_side"] = "left" if id == "left" else "right"
	_values["touch_keeper_return_side"] = "left" if id == "left" else "right"
	_persist()
	changed.emit("touch_positions", {})


func volume_linear(bus: String) -> float:
	var master := float(get_value("volume_master"))
	match bus:
		"music":
			return master * float(get_value("volume_music")) if bool(get_value("music_enabled")) else 0.0
		"sfx":
			return master * float(get_value("volume_sfx"))
		"ui":
			return master * float(get_value("volume_ui"))
		"announcer":
			return master * float(get_value("volume_announcer")) if bool(get_value("announcer_enabled")) else 0.0
	return master


## True the first time a given tutorial id is requested; afterwards false.
## This is what lets the control-hint card auto-skip once a player knows a game.
func should_show_tutorial(id: String) -> bool:
	if not bool(get_value("show_control_hints")):
		return false
	var seen: Dictionary = _values["tutorials_seen"]
	return not seen.has(id)


func mark_tutorial_seen(id: String) -> void:
	var seen: Dictionary = _values["tutorials_seen"]
	if seen.has(id):
		return
	seen[id] = true
	_persist()


func reset_to_defaults() -> void:
	_values = DEFAULTS.duplicate(true)
	_values["language"] = Loc.locale
	_persist()
	_apply_engine_settings()
	changed.emit("*", null)


func snapshot() -> Dictionary:
	return _values.duplicate(true)


func _persist() -> void:
	SaveSystem.set_settings(_values.duplicate(true))
	SaveSystem.flush()


func _apply_engine_settings() -> void:
	if DisplayServer.get_name() == "headless":
		Engine.max_fps = 0
		return
	Engine.max_fps = frame_limit_for_display(int(get_value("fps_limit")), DisplayServer.screen_get_refresh_rate())
	var quality := int(get_value("graphics_quality"))
	# Scale the 3D render resolution rather than dropping features, which keeps
	# gameplay readability identical across quality tiers.
	var scale: float = [0.7, 0.85, 1.0, 1.15][clampi(quality, 0, 3)]
	if OS.get_name() in ["iOS", "Android"]:
		scale = minf(scale, 1.0)
	get_tree().root.scaling_3d_scale = scale
	var rich := RenderingServer.get_current_rendering_method() == "forward_plus"
	# Multisampling is what keeps a bevelled edge from crawling as the camera
	# orbits, so it is the last thing to give up rather than the first.
	if quality >= 3 and rich:
		get_tree().root.msaa_3d = Viewport.MSAA_8X
	elif quality >= 2:
		get_tree().root.msaa_3d = Viewport.MSAA_4X if rich or quality >= 3 else Viewport.MSAA_2X
	elif quality == 1:
		get_tree().root.msaa_3d = Viewport.MSAA_2X
	else:
		get_tree().root.msaa_3d = Viewport.MSAA_DISABLED
	# Below full resolution, a cheap post-process pass costs less than the
	# aliasing it removes; at full resolution MSAA already covers it.
	get_tree().root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED \
		if quality >= 2 else Viewport.SCREEN_SPACE_AA_FXAA
	get_tree().root.use_taa = rich and quality >= 2


func frame_limit_for_display(requested: int, refresh: float) -> int:
	var limit := 120 if requested <= 0 else clampi(requested, 30, 144)
	return mini(limit, maxi(30, int(round(refresh)))) if refresh > 0.0 else limit
