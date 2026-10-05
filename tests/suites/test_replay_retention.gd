extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("replay newest recording retention")
	while Replays._recovery_running:
		await host.get_tree().process_frame
	var root: String = SaveSystem.storage_root
	var cache: Dictionary = SaveSystem._cache.duplicate(true)
	var dirty: Dictionary = SaveSystem._dirty.duplicate(true)
	var protected_paths: Dictionary = SaveSystem._read_only_paths.duplicate(true)
	var index: Array = Replays._index.duplicate(true)
	SaveSystem.storage_root = root.path_join("replay_retention_fixture")
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
	replay.highlights = [{"tick": 0, "kind": "narrow_win", "slot": 0, "detail": "1"}]
	for i in Replays.MAX_KEPT:
		replay.id = "retained_highlight_%02d" % i
		replay.created_at = 1000 + i
		t.ok(Replays.save(replay), "existing highlighted recording commits")
	t.equal(Replays.count(), Replays.MAX_KEPT, "fixture fills library with highlighted recordings")
	var orphan := ReplayData.from_match(cfg, [packet], {}, {}, null)
	orphan.id = "newest_committed_orphan"
	orphan.created_at = 3000
	t.ok(Replays._write_atomic(orphan.id, JSON.stringify(orphan.to_dict())), "new ordinary replay commits before interrupted index update")
	var recovered: Dictionary = await Replays.recover_library()
	t.equal(recovered.recovered, 1, "recovery reports the retained committed recording")
	t.ok(FileAccess.file_exists(Replays._path(orphan.id)), "recovery cannot immediately prune the newest committed file")
	t.equal(Replays.index()[0].id, orphan.id, "recovered new recording becomes available in the full library")
	t.not_null(Replays.load_replay(orphan.id), "recovered recording remains readable after retention")
	var older := ReplayData.from_match(cfg, [packet], {}, {}, null)
	older.id = "older_orphan_discarded"
	older.created_at = 500
	t.ok(Replays._write_atomic(older.id, JSON.stringify(older.to_dict())), "older orphan fixture commits")
	var older_recovery: Dictionary = await Replays.recover_library()
	t.equal(older_recovery.recovered, 0, "recovery does not count an older candidate that retention removed")
	t.ok(not FileAccess.file_exists(Replays._path(older.id)), "older ordinary candidate remains subject to retention preference")
	t.ok(FileAccess.file_exists(Replays._path(orphan.id)), "recovering older data cannot remove the newest recording")
	replay.id = "newest_plain_recording"
	replay.created_at = 4000
	replay.highlights = []
	t.ok(Replays.save(replay), "new ordinary recording saves into a full highlighted library")
	t.ok(FileAccess.file_exists(Replays._path(replay.id)), "successful save leaves its actual replay file present")
	t.ok(Replays._file_bytes(replay.id) > 0, "successful save has nonzero serialized bytes")
	t.equal(Replays.index()[0].id, replay.id, "newly saved recording is offered in the library")
	t.not_null(Replays.load_replay(replay.id), "new recording remains readable after pruning")
	t.equal(Replays.count(), Replays.MAX_KEPT, "new retention cannot exceed the count budget")
	t.ok(not FileAccess.file_exists(Replays._path("retained_highlight_00")), "oldest prior highlight makes room when all previous entries are highlighted")
	t.ok(not FileAccess.file_exists(Replays._path(orphan.id)), "prior ordinary recording is eligible again rather than permanently protected")
	if FileAccess.file_exists(Replays._path(replay.id)):
		var budget: int = Replays._file_bytes(replay.id) * 2
		Replays.call("_prune", budget, replay.id)
		t.ok(Replays.total_bytes() <= budget, "protecting the current recording still enforces the byte budget")
		t.ok(FileAccess.file_exists(Replays._path(replay.id)), "byte pruning preserves the just-saved replay when it fits")
		Replays.call("_prune", 0, replay.id)
		t.equal(Replays.count(), 0, "an impossible budget cannot retain even a protected recording")
		t.equal(Replays.total_bytes(), 0, "impossible budget remains bounded without an infinite prune loop")
	for file in DirAccess.get_files_at(SaveSystem.storage_root.path_join("replays")):
		DirAccess.remove_absolute(SaveSystem.storage_root.path_join("replays").path_join(file))
	SaveSystem.storage_root = root
	SaveSystem._cache = cache
	SaveSystem._dirty = dirty
	SaveSystem._read_only_paths = protected_paths
	Replays._index = index
	await host.get_tree().process_frame
