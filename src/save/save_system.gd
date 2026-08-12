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
##
## **The MD5 envelope is corruption detection, not security.** It catches a
## truncated or half-written file; it does not and is not meant to stop anyone
## editing their own save. If tamper resistance is ever needed — for a
## leaderboard, say — that is an HMAC with a server-held key, not this.
##
## The document holds several *player profiles* so a household can share a
## device without sharing progress, plus a few shared branches (the replay
## library, saved party presets) that belong to the machine rather than to a
## person.

signal profile_loaded(data: Dictionary)
signal profile_saved()
signal recovered_from_backup(which: String)
signal active_profile_changed(id: String)
signal profiles_changed()

const DIR := "user://"
const PROFILE := "profile"
const SETTINGS := "settings"
const SCHEMA_VERSION := 2
const DEFAULT_PROFILE := "default"
## Branches stored per player rather than per device.
const PLAYER_BRANCHES := ["progress", "stats", "achievements", "rewards_claimed", "daily_done"]

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


## The whole document, including every player profile and the shared branches.
func profile() -> Dictionary:
	return _cache.get(PROFILE, {})


# --- player profiles -------------------------------------------------------

func _profiles() -> Dictionary:
	var doc := profile()
	if not doc.has("profiles"):
		doc["profiles"] = {}
	return doc["profiles"]


func active_profile_id() -> String:
	var doc := profile()
	var id := String(doc.get("active_profile", DEFAULT_PROFILE))
	if not _profiles().has(id):
		id = DEFAULT_PROFILE
		_ensure_profile(id, "player.you")
		doc["active_profile"] = id
	return id


func profile_ids() -> Array:
	return _profiles().keys()


func profile_meta(id: String) -> Dictionary:
	var p: Dictionary = _profiles().get(id, {})
	return {
		"id": id,
		"name": String(p.get("name", id)),
		"guest": bool(p.get("guest", false)),
		"created": int(p.get("created", 0)),
	}


func _ensure_profile(id: String, name: String, guest := false) -> Dictionary:
	var all := _profiles()
	if not all.has(id):
		all[id] = {
			"name": name,
			"guest": guest,
			"created": int(Time.get_unix_time_from_system()),
		}
		mark_dirty(PROFILE)
	return all[id]


## Guests exist so nobody has to make an account to join a party. Their progress
## is kept for the session and can be discarded without touching anyone else.
func create_profile(name: String, guest := false) -> String:
	var base := name.to_lower().replace(" ", "_")
	if base == "":
		base = "guest" if guest else "player"
	var id := base
	var n := 2
	while _profiles().has(id):
		id = "%s%d" % [base, n]
		n += 1
	_ensure_profile(id, name, guest)
	flush()
	profiles_changed.emit()
	return id


func switch_profile(id: String) -> void:
	if not _profiles().has(id) or id == active_profile_id():
		return
	var doc := profile()
	doc["active_profile"] = id
	mark_dirty(PROFILE)
	flush()
	active_profile_changed.emit(id)
	profile_loaded.emit(doc)


func rename_profile(id: String, name: String) -> void:
	var all := _profiles()
	if not all.has(id):
		return
	all[id]["name"] = name
	mark_dirty(PROFILE)
	flush()
	profiles_changed.emit()


func delete_profile(id: String) -> void:
	var all := _profiles()
	if all.size() <= 1 or not all.has(id):
		return
	all.erase(id)
	if String(profile().get("active_profile", "")) == id:
		profile()["active_profile"] = all.keys()[0]
		active_profile_changed.emit(String(all.keys()[0]))
	mark_dirty(PROFILE)
	flush()
	profiles_changed.emit()
	profile_loaded.emit(profile())


## Read one branch of the *active* player. This is what Progression, Stats and
## Achievements use, so switching profile switches all of them at once.
func player_branch(name: String) -> Dictionary:
	var p := _ensure_profile(active_profile_id(), "player.you")
	if not p.has(name):
		p[name] = {}
	return p[name]


func set_player_branch(name: String, data) -> void:
	var p := _ensure_profile(active_profile_id(), "player.you")
	p[name] = data
	mark_dirty(PROFILE)


## Shared across every profile on this device.
func shared_branch(name: String, fallback = {}):
	var doc := profile()
	if not doc.has(name):
		doc[name] = fallback
	return doc[name]


func set_shared_branch(name: String, data) -> void:
	var doc := profile()
	doc[name] = data
	mark_dirty(PROFILE)


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


## Each schema bump adds one clause, so an old save is upgraded rather than
## discarded. Migrations run oldest-first and are idempotent.
func _migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("schema", 0))
	if v < 1:
		v = 1
	if v < 2:
		# v1 kept a single player's branches at the top level. Move them into a
		# named profile and leave device-wide branches where they are.
		var moved := {}
		for branch in PLAYER_BRANCHES:
			if data.has(branch):
				moved[branch] = data[branch]
				data.erase(branch)
		moved["name"] = "player.you"
		moved["guest"] = false
		moved["created"] = int(Time.get_unix_time_from_system())
		data["profiles"] = {DEFAULT_PROFILE: moved}
		data["active_profile"] = DEFAULT_PROFILE
		Log.i("migrated save from schema 1 to 2", "Save")
		v = 2
	data["schema"] = SCHEMA_VERSION
	return data
