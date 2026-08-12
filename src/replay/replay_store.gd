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

var _index: Array = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_load_index()


func _load_index() -> void:
	_index = SaveSystem.shared_branch(INDEX_BRANCH, [])
	# Drop entries whose file has gone: a user deleting files by hand should not
	# leave the library full of ghosts.
	var alive: Array = []
	for entry in _index:
		if FileAccess.file_exists(_path(String(entry.get("id", "")))):
			alive.append(entry)
	if alive.size() != _index.size():
		_index = alive
		_commit()


func _commit() -> void:
	SaveSystem.set_shared_branch(INDEX_BRANCH, _index)
	SaveSystem.flush()


func _path(id: String) -> String:
	return "%s/%s.json" % [DIR, id]


## Newest first.
func index() -> Array:
	var out := _index.duplicate()
	out.reverse()
	return out


func count() -> int:
	return _index.size()


func save(replay: ReplayData) -> bool:
	if replay == null or replay.frames.is_empty():
		return false
	var f := FileAccess.open(_path(replay.id), FileAccess.WRITE)
	if f == null:
		Log.e("cannot write replay %s" % replay.id, "Replay")
		return false
	f.store_string(JSON.stringify(replay.to_dict()))
	f.close()
	_index.append({
		"id": replay.id,
		"game": replay.minigame_id,
		"arena": replay.arena_id,
		"created_at": replay.created_at,
		"seconds": replay.length_seconds(),
		"winner": replay.winner_name(),
		"players": replay.player_count(),
		"bytes": replay.approx_bytes(),
		"highlights": replay.highlights.size(),
	})
	_prune()
	_commit()
	library_changed.emit()
	Log.i("saved replay %s (%.1fs, %.1f KB)" % [replay.id, replay.length_seconds(), replay.approx_bytes() / 1024.0], "Replay")
	return true


## Keep the library bounded. Oldest go first, but anything the highlight
## detector flagged survives longer — those are the ones worth keeping.
func _prune() -> void:
	while _index.size() > MAX_KEPT:
		var victim := 0
		for i in _index.size():
			if int(_index[i].get("highlights", 0)) == 0:
				victim = i
				break
		var entry: Dictionary = _index[victim]
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path(String(entry["id"]))))
		_index.remove_at(victim)


func load_replay(id: String) -> ReplayData:
	var path := _path(id)
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var raw := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(raw) != OK:
		Log.e("replay %s is unreadable: %s" % [id, json.get_error_message()], "Replay")
		return null
	if not (json.data is Dictionary):
		return null
	return ReplayData.from_dict(json.data)


func erase(id: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_path(id)))
	for i in _index.size():
		if String(_index[i].get("id", "")) == id:
			_index.remove_at(i)
			break
	_commit()
	library_changed.emit()


func erase_all() -> void:
	for entry in _index:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path(String(entry["id"]))))
	_index.clear()
	_commit()
	library_changed.emit()


func total_bytes() -> int:
	var n := 0
	for e in _index:
		n += int(e.get("bytes", 0))
	return n
