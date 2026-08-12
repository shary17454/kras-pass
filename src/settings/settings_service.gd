extends Node
## Player-facing options. Autoload name: `UserSettings`.
##
## Holds audio levels, controls, graphics and accessibility. Every setter
## persists through SaveSystem and fires `changed` so live systems (audio buses,
## camera, UI theme) react without a restart.

signal changed(key: String, value)

const DEFAULTS := {
	"volume_master": 0.9,
	"volume_music": 0.7,
	"volume_sfx": 1.0,
	"volume_ui": 0.8,
	"vibration": true,
	"camera_sensitivity": 1.0,
	"camera_shake": 1.0,
	"graphics_quality": 2,  # 0 low, 1 medium, 2 high
	"fps_limit": 0,  # 0 = display refresh
	"language": "",  # "" = follow system on first launch
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
	"touch_opacity": 0.5,
	"touch_left_handed": false,
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
	elif key in ["fps_limit", "graphics_quality"]:
		_apply_engine_settings()
	changed.emit(key, value)


func toggle(key: String) -> void:
	set_value(key, not bool(get_value(key)))


func volume_linear(bus: String) -> float:
	var master := float(get_value("volume_master"))
	match bus:
		"music":
			return master * float(get_value("volume_music"))
		"sfx":
			return master * float(get_value("volume_sfx"))
		"ui":
			return master * float(get_value("volume_ui"))
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
	Engine.max_fps = int(get_value("fps_limit"))
	if DisplayServer.get_name() == "headless":
		return
	var quality := int(get_value("graphics_quality"))
	# Scale the 3D render resolution rather than dropping features, which keeps
	# gameplay readability identical across quality tiers.
	var scale: float = [0.7, 0.85, 1.0][clampi(quality, 0, 2)]
	get_tree().root.scaling_3d_scale = scale
	get_tree().root.msaa_3d = Viewport.MSAA_2X if quality >= 2 else Viewport.MSAA_DISABLED
