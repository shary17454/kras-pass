extends Node
## Persistence with corruption recovery. Autoload name: `SaveSystem`.
##
## Two independent slots are stored under `user://`:
##   profile.json  — progression, unlocks, achievements, stats, records
##   settings.json — audio, controls, accessibility, language
##
## Writes are atomic: serialize to `<name>.tmp`, fsync, then rotate the previous
## good file to `<name>.bak` and rename the tmp into place. A load walks
## main -> backup -> empty, so a power cut mid-write costs at most one session
## rather than the whole profile.

signal profile_loaded(data: Dictionary)
signal profile_saved()
signal recovered_from_backup(which: String)

const DIR := "user://"
const PROFILE := "profile"
const SETTINGS := "settings"
const SCHEMA_VERSION := 1

var _cache := {}
var _dirty := {}
var _autosave_accum := 0.0
var autosave_interval := 5.0
## Disabled by the test harness so unit tests never touch the real profile.
var enabled := true


func _ready() -> void:
	_cache[PROFILE] = load_slot(PROFILE)
	_cache[SETTINGS] = load_slot(SETTINGS)
	profile_loaded.emit(_cache[PROFILE])


func _process(delta: float) -> void:
	if _dirty.is_empty():
		return
	_autosave_accum += delta
	if _autosave_accum >= autosave_interval:
		_autosave_accum = 0.0
		flush()


func profile() -> Dictionary:
	return _cache.get(PROFILE, {})


func settings() -> Dictionary:
	return _cache.get(SETTINGS, {})


func mark_dirty(slot: String) -> void:
	_dirty[slot] = true


## Persist every dirty slot immediately. Called on pause, on quit, and after
## any progression milestone so a crash cannot swallow a trophy.
func flush() -> void:
	if not enabled:
		_dirty.clear()
		return
	for slot in _dirty.keys():
		_write_slot(slot, _cache.get(slot, {}))
	_dirty.clear()
	profile_saved.emit()


func set_profile(data: Dictionary) -> void:
	_cache[PROFILE] = data
	mark_dirty(PROFILE)


func set_settings(data: Dictionary) -> void:
	_cache[SETTINGS] = data
	mark_dirty(SETTINGS)


func load_slot(slot: String) -> Dictionary:
	var main = _read(_path(slot))
	if main != null:
		return _migrate(main)
	var backup = _read(_path(slot) + ".bak")
	if backup != null:
		Log.w("slot '%s' corrupt — recovered from backup" % slot, "Save")
		recovered_from_backup.emit(slot)
		return _migrate(backup)
	return {"schema": SCHEMA_VERSION}


## Wipe a slot. Used by the "reset progress" settings action and by tests.
func erase(slot: String) -> void:
	_cache[slot] = {"schema": SCHEMA_VERSION}
	if enabled:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path(slot)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path(slot) + ".bak"))
	_dirty.erase(slot)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		flush()


func _path(slot: String) -> String:
	return DIR + slot + ".json"


func _write_slot(slot: String, data: Dictionary) -> void:
	data["schema"] = SCHEMA_VERSION
	var payload := JSON.stringify(data)
	var envelope := JSON.stringify({"checksum": payload.md5_text(), "body": payload})
	var tmp := _path(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		Log.e("cannot open %s for write" % tmp, "Save")
		return
	f.store_string(envelope)
	f.flush()
	f.close()
	# Rotate: current good file becomes the backup, tmp becomes current.
	if FileAccess.file_exists(_path(slot)):
		var prev := FileAccess.open(_path(slot), FileAccess.READ)
		if prev != null:
			var prev_text := prev.get_as_text()
			prev.close()
			var bf := FileAccess.open(_path(slot) + ".bak", FileAccess.WRITE)
			if bf != null:
				bf.store_string(prev_text)
				bf.close()
	var da := DirAccess.open(DIR)
	if da != null:
		da.rename(tmp.get_file(), _path(slot).get_file())


func _read(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var raw := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(raw) != OK:
		return null
	var env = json.data
	if not (env is Dictionary) or not env.has("body") or not env.has("checksum"):
		return null
	var body: String = env["body"]
	if body.md5_text() != env["checksum"]:
		Log.w("checksum mismatch in %s" % path, "Save")
		return null
	var inner := JSON.new()
	if inner.parse(body) != OK:
		return null
	return inner.data if inner.data is Dictionary else null


## Forward-compatibility hook. Each future schema bump adds one clause here so
## an old profile is upgraded rather than discarded.
func _migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("schema", 0))
	if v < 1:
		data["schema"] = 1
	return data
