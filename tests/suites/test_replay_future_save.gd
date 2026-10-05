extends RefCounted


func run(t: TestHarness) -> void:
	t.suite("replay future-save protection")
	var root: String = SaveSystem.storage_root
	var cache: Dictionary = SaveSystem._cache.duplicate(true)
	var dirty: Dictionary = SaveSystem._dirty.duplicate(true)
	var protected_paths: Dictionary = SaveSystem._read_only_paths.duplicate(true)
	var index: Array = Replays._index.duplicate(true)
	for scenario in ["loaded_main", "late_main", "late_backup"]:
		SaveSystem.storage_root = root.path_join("replay_future_" + scenario)
		DirAccess.make_dir_recursive_absolute(SaveSystem.storage_root.path_join("replays"))
		SaveSystem._cache = {SaveSystem.PROFILE: {"schema": SaveSystem.SCHEMA_VERSION}}
		SaveSystem._dirty = {}
		SaveSystem._read_only_paths = {}
		Replays._index = []
		var replay := ReplayData.new()
		replay.id = "protected_recording"
		replay.players = [{"slot": 0, "character": "nabta"}]
		replay.frames.append(InputFrame.new().encode())
		t.ok(Replays.save(replay), scenario + ": supported initial save succeeds")
		var recording_path: String = Replays._path(replay.id)
		var original := _text(recording_path)
		var original_entry: Array = Replays._index.duplicate(true)
		var future_path: String = SaveSystem._path(SaveSystem.PROFILE)
		if scenario == "late_backup":
			future_path += ".bak"
		var body := JSON.stringify({"schema": SaveSystem.SCHEMA_VERSION + 1, "future_cups": 93})
		var future := JSON.stringify({"body": body, "checksum": body.md5_text()})
		_write(future_path, future)
		if scenario == "loaded_main":
			SaveSystem.load_slot(SaveSystem.PROFILE)
		for operation in ["save", "direct_write", "erase", "erase_all", "prune"]:
			_write(recording_path, original)
			Replays._index = original_entry.duplicate(true)
			replay.seed_value = 99
			match operation:
				"save":
					t.ok(not Replays.save(replay), scenario + ": save refused")
				"direct_write":
					t.ok(not Replays._write_atomic(replay.id, "replacement"), scenario + ": direct write refused")
				"erase":
					Replays.erase(replay.id)
				"erase_all":
					Replays.erase_all()
				"prune":
					Replays._prune(0)
			t.equal(_text(recording_path), original, scenario + ": " + operation + " preserves recording bytes")
			t.equal(Replays.count(), 1, scenario + ": " + operation + " preserves in-memory index")
			t.equal(_text(future_path), future, scenario + ": " + operation + " preserves future profile bytes")
		Replays._load_index()
		t.equal(_text(recording_path), original, scenario + ": loading protected index does not prune disk")
		t.equal(_text(future_path), future, scenario + ": index cleanup cannot overwrite future profile")
		_write(recording_path, original)
		t.not_null(Replays.load_replay(replay.id), scenario + ": protected recordings remain readable")
		DirAccess.remove_absolute(recording_path)
		DirAccess.remove_absolute(future_path)
		DirAccess.remove_absolute(recording_path + ".tmp")
	SaveSystem.storage_root = root
	SaveSystem._cache = cache
	SaveSystem._dirty = dirty
	SaveSystem._read_only_paths = protected_paths
	Replays._index = index


func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(value)
		file.close()


func _text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var value := file.get_as_text()
	file.close()
	return value
