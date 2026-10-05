extends Node
## The replay library on disk. Autoload name: `Replays`.
##
## Files live in `user://replays/<id>.json`. A lightweight index is kept in the
## profile so the library screen can list dozens of recordings without parsing
## every one of them — parsing a 90-second four-player replay is cheap, but
## doing it forty times while a menu opens is not.

signal library_changed()

const DIR := "user://replays"
const INDEX_BRANCH := "replays"
const MAX_KEPT := 40
const MAX_FILE_BYTES := 64 * 1024 * 1024
const MAX_TOTAL_BYTES := 256 * 1024 * 1024

var _index: Array = []
var _recovery_running := false
var _recovery_generation := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SaveSystem.storage_root.path_join("replays"))
	_load_index()
	call_deferred("recover_library")


func _load_index() -> void:
	var stored = SaveSystem.shared_branch(INDEX_BRANCH, [])
	_index = stored.duplicate(true) if stored is Array else []
	if not _can_mutate():
		return
	# Drop entries whose file has gone: a user deleting files by hand should not
	# leave the library full of ghosts.
	var alive: Array = []
	var seen := {}
	var changed := false
	for entry in _index:
		if not entry is Dictionary:
			continue
		var id := String(entry.get("id", ""))
		if _valid_id(id) and not seen.has(id) and FileAccess.file_exists(_path(id)):
			var bytes := _file_bytes(id)
			var stored_bytes = entry.get("bytes")
			changed = changed or not (stored_bytes is int or stored_bytes is float) or stored_bytes != bytes
			entry["bytes"] = bytes
			alive.append(entry)
			seen[id] = true
	if changed or alive.size() != _index.size():
		_index = alive
		_commit()


func _commit() -> void:
	if not _can_mutate():
		return
	SaveSystem.set_shared_branch(INDEX_BRANCH, _index)
	SaveSystem.flush()


func _path(id: String) -> String:
	return SaveSystem.storage_root.path_join("replays").path_join(id + ".json")


func _valid_id(id: String) -> bool:
	if id.is_empty() or id.length() > 128:
		return false
	for c in id:
		if not c in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-":
			return false
	return true


## Newest first.
func index() -> Array:
	var out := _index.duplicate()
	out.reverse()
	return out


func count() -> int:
	return _index.size()


## Recover committed files left behind by an interrupted profile-index write.
## Stage metadata locally and yield between files; never promote .tmp files.
func recover_library(read_byte_limit: int = MAX_TOTAL_BYTES) -> Dictionary:
	var report := {"recovered": 0, "read_bytes": 0, "deferred": 0}
	if _recovery_running or not _can_mutate():
		return report
	_recovery_running = true
	var root: String = SaveSystem.storage_root
	var generation := _recovery_generation
	var folder := root.path_join("replays")
	var files := DirAccess.get_files_at(folder)
	files.sort()
	files.reverse()
	var known := {}
	for entry in _index:
		known[String(entry.get("id", ""))] = true
	var recovered: Array = []
	var directory := DirAccess.open(folder)
	for filename in files:
		if SaveSystem.storage_root != root or generation != _recovery_generation or not _can_mutate():
			break
		if not filename.ends_with(".json") or directory == null or directory.is_link(filename):
			continue
		var id := filename.trim_suffix(".json")
		if not _valid_id(id) or known.has(id):
			continue
		var bytes := _file_bytes(id)
		if bytes <= 0 or bytes > MAX_FILE_BYTES:
			continue
		if recovered.size() >= MAX_KEPT or bytes + int(report.read_bytes) > maxi(0, read_byte_limit):
			report.deferred += 1
			continue
		report.read_bytes += bytes
		var replay := load_replay(id, true)
		if replay != null and replay.id == id and not replay.frames.is_empty() and Registry.minigame(replay.minigame_id) != null:
			recovered.append(_entry_for(replay))
		await get_tree().process_frame
	# A save or profile switch while yielding must not receive stale metadata.
	if SaveSystem.storage_root == root and generation == _recovery_generation and _can_mutate() and not recovered.is_empty():
		known.clear()
		for entry in _index:
			known[String(entry.get("id", ""))] = true
		for entry in recovered:
			if not known.has(entry.id) and FileAccess.file_exists(_path(entry.id)) and _file_bytes(entry.id) == entry.bytes:
				_index.append(entry)
				known[entry.id] = true
				report.recovered += 1
		_index.sort_custom(func(a, b): return _entry_time(a) < _entry_time(b))
		_prune()
		_commit()
		library_changed.emit()
	_recovery_running = false
	return report


func _entry_time(entry: Dictionary) -> int:
	var value = entry.get("created_at", 0)
	return int(value) if value is int or value is float else 0


func _entry_for(replay: ReplayData) -> Dictionary:
	return {
		"id": replay.id, "game": replay.minigame_id, "arena": replay.arena_id,
		"created_at": replay.created_at, "seconds": replay.length_seconds(),
		"winner": replay.winner_name(), "players": replay.player_count(),
		"bytes": _file_bytes(replay.id), "highlights": replay.highlights.size(),
	}


func save(replay: ReplayData) -> bool:
	if not _can_mutate():
		return false
	if replay == null or replay.frames.is_empty() or not _valid_id(replay.id):
		return false
	if not _write_atomic(replay.id, JSON.stringify(replay.to_dict())):
		return false
	# A retry replaces its entry instead of leaving dangling index duplicates.
	for i in range(_index.size() - 1, -1, -1):
		if String(_index[i].get("id", "")) == replay.id:
			_index.remove_at(i)
	_index.append(_entry_for(replay))
	_prune()
	_commit()
	library_changed.emit()
	Log.i("saved replay %s (%.1fs, %.1f KB)" % [replay.id, replay.length_seconds(), _file_bytes(replay.id) / 1024.0], "Replay")
	return true


func _write_atomic(id: String, payload: String, byte_limit: int = MAX_FILE_BYTES) -> bool:
	if not _can_mutate():
		return false
	if not _valid_id(id) or payload.length() > byte_limit:
		return false
	var bytes := payload.to_utf8_buffer()
	if bytes.size() > byte_limit:
		return false
	var path := _path(id)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		Log.w("cannot prepare replay %s for write" % id, "Replay")
		return false
	f.store_buffer(bytes)
	f.flush()
	var write_error := f.get_error()
	f.close()
	if write_error == OK:
		var directory := DirAccess.open(path.get_base_dir())
		if directory != null and directory.rename(tmp.get_file(), path.get_file()) == OK:
			return true
	DirAccess.remove_absolute(tmp)
	Log.w("cannot commit replay %s; previous recording retained" % id, "Replay")
	return false


func _file_bytes(id: String) -> int:
	var file := FileAccess.open(_path(id), FileAccess.READ)
	if file == null:
		return 0
	var bytes := file.get_length()
	file.close()
	return bytes


## Keep the library bounded. Oldest go first, but anything the highlight
## detector flagged survives longer — those are the ones worth keeping.
func _prune(byte_limit: int = MAX_TOTAL_BYTES) -> void:
	if not _can_mutate():
		return
	for entry in _index:
		entry["bytes"] = _file_bytes(String(entry["id"]))
	while not _index.is_empty() and (_index.size() > MAX_KEPT or total_bytes() > byte_limit):
		var victim := 0
		for i in _index.size():
			if int(_index[i].get("highlights", 0)) == 0:
				victim = i
				break
		var entry: Dictionary = _index[victim]
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path(String(entry["id"]))))
		_index.remove_at(victim)


func load_replay(id: String, recovery := false) -> ReplayData:
	if not _valid_id(id):
		return null
	var path := _path(id)
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	if f.get_length() > MAX_FILE_BYTES:
		f.close()
		Log.w("replay %s exceeds the file read budget" % id, "Replay")
		return null
	var raw := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(raw) != OK:
		if not recovery:
			Log.e("replay %s is unreadable: %s" % [id, json.get_error_message()], "Replay")
		return null
	if not (json.data is Dictionary):
		return null
	return ReplayData.from_dict(json.data)


func erase(id: String) -> void:
	if not _can_mutate():
		return
	if not _valid_id(id):
		return
	_recovery_generation += 1
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_path(id)))
	for i in _index.size():
		if String(_index[i].get("id", "")) == id:
			_index.remove_at(i)
			break
	_commit()
	library_changed.emit()


func erase_all() -> void:
	if not _can_mutate():
		return
	_recovery_generation += 1
	for entry in _index:
		var id := String(entry["id"])
		if _valid_id(id):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_path(id)))
	_index.clear()
	_commit()
	library_changed.emit()


func total_bytes() -> int:
	var n := 0
	for e in _index:
		n += int(e.get("bytes", 0))
	return n


func _can_mutate() -> bool:
	return SaveSystem.can_write(SaveSystem.PROFILE)
