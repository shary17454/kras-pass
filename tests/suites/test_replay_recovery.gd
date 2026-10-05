extends RefCounted

func run(t: TestHarness, host: Node) -> void:
	t.suite("replay committed-file index recovery")
	while Replays._recovery_running:
		await host.get_tree().process_frame
	var root: String = SaveSystem.storage_root
	var cache: Dictionary = SaveSystem._cache.duplicate(true)
	var dirty: Dictionary = SaveSystem._dirty.duplicate(true)
	var protected_paths: Dictionary = SaveSystem._read_only_paths.duplicate(true)
	var index: Array = Replays._index.duplicate(true)
	SaveSystem.storage_root = root.path_join("replay_recovery_fixture")
	DirAccess.make_dir_recursive_absolute(SaveSystem.storage_root.path_join("replays"))
	SaveSystem._cache = {SaveSystem.PROFILE: {"schema": SaveSystem.SCHEMA_VERSION}}
	SaveSystem._dirty = {}
	SaveSystem._read_only_paths = {}
	Replays._index = []
	var cfg := MatchConfig.build("ring_rumble", ["nabta", "sakhra", "fanoos", "ramla"], 0, 2, 91)
	var packet := PackedByteArray()
	for slot in 4:
		packet.append_array(InputFrame.new().encode())
	var replay := ReplayData.from_match(cfg, [packet], {}, {}, null)
	replay.id = "recovered_match"
	var payload := JSON.stringify(replay.to_dict())
	t.ok(Replays._write_atomic(replay.id, payload), "committed replay exists before index update")
	t.equal(Replays.count(), 0, "interrupted-write fixture has no index entry")
	_write(Replays._path("incomplete") + ".tmp", payload)
	_write(Replays._path("malformed"), "{interrupted")
	_write(Replays._path("wrong_identity"), payload)
	var empty := replay.to_dict()
	empty["id"] = "empty_capture"
	empty["frames_b64"] = ""
	empty["tick_count"] = 0
	_write(Replays._path("empty_capture"), JSON.stringify(empty))
	var skipped: Dictionary = await Replays.recover_library(0)
	t.equal(skipped.recovered, 0, "zero read budget cannot load candidates")
	t.equal(skipped.read_bytes, 0, "zero budget performs no payload reads")
	t.ok(skipped.deferred > 0, "bounded recovery reports deferred candidates")
	var recovered: Dictionary = await Replays.recover_library()
	t.equal(recovered.recovered, 1, "only complete matching-identity replay is recovered")
	t.equal(Replays.count(), 1, "recovered replay appears in library")
	t.equal(Replays.index()[0].id, replay.id, "library points to actual committed file")
	t.equal(Replays.index()[0].bytes, payload.to_utf8_buffer().size(), "recovered metadata counts actual file bytes")
	t.not_null(Replays.load_replay(replay.id), "recovered replay remains playable")
	t.ok(FileAccess.file_exists(Replays._path("incomplete") + ".tmp"), "temporary data is preserved, not promoted or deleted")
	t.ok(FileAccess.file_exists(Replays._path("malformed")), "malformed candidate is not destructively removed")
	t.equal((await Replays.recover_library()).recovered, 0, "recovery is idempotent")
	Replays._load_index()
	t.equal(Replays.count(), 1, "recovered index survives reload")
	SaveSystem.set_shared_branch(Replays.INDEX_BRANCH, [])
	var restarted: Node = load("res://src/replay/replay_store.gd").new()
	var published := {"changed": false}
	restarted.library_changed.connect(func(): published.changed = true)
	host.add_child(restarted)
	var guard := 0
	while not published.changed and guard < 120:
		await host.get_tree().process_frame
		guard += 1
	t.ok(published.changed, "fresh store startup automatically publishes recovered library")
	t.equal(restarted.count(), 1, "startup restores committed recording without manual recovery call")
	restarted.queue_free()
	await host.get_tree().process_frame
	Replays._index = []
	replay.id = "zz_cancelled"
	t.ok(Replays._write_atomic(replay.id, JSON.stringify(replay.to_dict())), "deletion-race fixture is committed")
	host.get_tree().process_frame.connect(func(): Replays.erase("zz_cancelled"), CONNECT_ONE_SHOT)
	t.equal((await Replays.recover_library()).recovered, 0, "deletion while yielding cancels staged recovery")
	t.ok(not FileAccess.file_exists(Replays._path(replay.id)), "recovery cannot resurrect a deleted recording")
	# A newer schema arriving before recovery must protect every file and index.
	Replays._index = []
	var body := JSON.stringify({"schema": SaveSystem.SCHEMA_VERSION + 1, "future_progress": 41})
	var future := JSON.stringify({"body": body, "checksum": body.md5_text()})
	var future_path: String = SaveSystem._path(SaveSystem.PROFILE)
	replay.id = "zz_inflight"
	t.ok(Replays._write_atomic(replay.id, JSON.stringify(replay.to_dict())), "in-flight recovery fixture is committed")
	host.get_tree().process_frame.connect(func(): _write(future_path, future), CONNECT_ONE_SHOT)
	var interrupted: Dictionary = await Replays.recover_library()
	t.equal(interrupted.recovered, 0, "future schema arriving during yield cancels staged metadata")
	t.equal(Replays.count(), 0, "interrupted recovery cannot publish stale index")
	t.equal((await Replays.recover_library()).recovered, 0, "future profile forbids index recovery")
	t.equal(Replays.count(), 0, "future profile recovery cannot mutate in-memory index")
	t.equal(_read(future_path), future, "future profile bytes remain untouched")
	t.equal(_read(Replays._path("recovered_match")), payload, "protected committed replay bytes remain untouched")
	for id in ["recovered_match", replay.id, "malformed", "wrong_identity", "empty_capture"]:
		DirAccess.remove_absolute(Replays._path(id))
	DirAccess.remove_absolute(Replays._path("incomplete") + ".tmp")
	DirAccess.remove_absolute(future_path)
	DirAccess.remove_absolute(future_path + ".bak")
	SaveSystem.storage_root = root
	SaveSystem._cache = cache
	SaveSystem._dirty = dirty
	SaveSystem._read_only_paths = protected_paths
	Replays._index = index


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text
