extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("replay combat simulation revision")
	var cfg := MatchConfig.build("duel_pit", ["nabta", "nabta"], 2, 2, 117)
	var recorded := ReplayData.from_match(cfg, [], {}, {}, null)
	var packet := PackedByteArray()
	for player in cfg.players:
		packet.append_array(InputFrame.new().encode())
	recorded.frames.append(packet)
	var current := recorded.to_dict()
	t.equal(current.get("combat_revision", -1), 1, "new recordings identify simultaneous combat")
	var decoded := ReplayData.from_dict(current)
	t.not_null(decoded, "current combat recording loads")
	if decoded != null:
		t.equal(decoded.to_dict().get("combat_revision", -1), 1, "current revision survives serialization")
	var json := JSON.new()
	t.equal(json.parse(JSON.stringify(current)), OK, "combat revision crosses real JSON encoding")
	t.not_null(ReplayData.from_dict(json.data), "integer-valued JSON number is supported")
	for version in range(1, 6):
		var legacy := current.duplicate(true)
		legacy["version"] = version
		legacy.erase("combat_revision")
		var restored := ReplayData.from_dict(legacy)
		t.not_null(restored, "historical format %d remains readable" % version)
		if restored == null:
			continue
		t.equal(restored.to_dict().get("combat_revision", -1), 0,
			"historical combat is not upgraded by format migration")
		var again := ReplayData.from_dict(restored.to_dict())
		t.not_null(again, "legacy recording can be saved again")
		if again != null:
			t.equal(again.to_dict().get("combat_revision", -1), 0,
				"re-saving historical combat preserves its simulation path")
	var explicit_legacy := current.duplicate(true)
	explicit_legacy["combat_revision"] = 0
	var restored_legacy := ReplayData.from_dict(explicit_legacy)
	t.not_null(restored_legacy, "explicit legacy combat remains supported")
	if restored_legacy != null:
		t.equal(restored_legacy.to_dict().get("combat_revision", -1), 0, "explicit legacy revision is retained")
	var missing_current := current.duplicate(true)
	missing_current.erase("combat_revision")
	t.ok(ReplayData.from_dict(missing_current) == null, "new format cannot silently guess a missing combat revision")
	t.equal(current["version"], 6, "older apps reject the new simulation format instead of silently misplaying it")
	for invalid in [-1, 2, 0.5, "1", null, true, [], {}, INF, NAN]:
		var malformed := current.duplicate(true)
		malformed["combat_revision"] = invalid
		t.ok(ReplayData.from_dict(malformed) == null, "invalid or unsupported combat revision is refused")
	await _disk_roundtrip(t, host, recorded, current, restored_legacy)


func _disk_roundtrip(t: TestHarness, host: Node, recorded: ReplayData,
		current: Dictionary, legacy: ReplayData) -> void:
	while Replays._recovery_running:
		await host.get_tree().process_frame
	var root: String = SaveSystem.storage_root
	var cache: Dictionary = SaveSystem._cache.duplicate(true)
	var dirty: Dictionary = SaveSystem._dirty.duplicate(true)
	var protected_paths: Dictionary = SaveSystem._read_only_paths.duplicate(true)
	var index: Array = Replays._index.duplicate(true)
	var fixture_root := root.path_join("replay_combat_" + Crypto.new().generate_random_bytes(16).hex_encode())
	var folder := fixture_root.path_join("replays")
	var directory_error := DirAccess.make_dir_recursive_absolute(folder)
	t.equal(directory_error, OK, "unique combat fixture directory can be created")
	if directory_error != OK:
		return
	SaveSystem.storage_root = fixture_root
	SaveSystem._cache = {SaveSystem.PROFILE: {"schema": SaveSystem.SCHEMA_VERSION}}
	SaveSystem._dirty = {}
	SaveSystem._read_only_paths = {}
	Replays._index = []
	recorded.id = "combat_revision_current_fixture"
	t.ok(Replays.save(recorded), "current recording saves to isolated library")
	var stored := Replays.load_replay(recorded.id)
	t.not_null(stored, "current recording loads from isolated disk")
	if stored != null:
		t.equal(stored.to_dict().get("combat_revision", -1), 1, "disk retains current combat revision")
	Replays.erase(recorded.id)
	if legacy != null:
		legacy.id = "combat_revision_legacy_fixture"
		t.ok(Replays.save(legacy), "legacy recording can be re-saved to isolated disk")
		stored = Replays.load_replay(legacy.id)
		t.not_null(stored, "legacy recording survives disk round trip")
		if stored != null:
			t.equal(stored.to_dict().get("combat_revision", -1), 0, "disk does not silently upgrade legacy combat")
		Replays.erase(legacy.id)
	var historical := current.duplicate(true)
	historical["version"] = 5
	historical["id"] = "combat_revision_v5_fixture"
	historical.erase("combat_revision")
	var file := FileAccess.open(Replays._path(historical.id), FileAccess.WRITE)
	t.not_null(file, "raw historical file can be written outside the active replay library")
	if file != null:
		file.store_string(JSON.stringify(historical))
		file.close()
		var migrated := Replays.load_replay(historical.id)
		t.not_null(migrated, "actual v5 file without combat metadata loads from disk")
		if migrated != null:
			t.equal(migrated.to_dict().get("combat_revision", -1), 0, "historical disk file selects legacy combat")
			t.equal(migrated.tick_count(), recorded.tick_count(), "historical input frames survive migration")
			t.ok(Replays.save(migrated), "migrated historical file can be saved again")
			var migrated_again := Replays.load_replay(migrated.id)
			t.not_null(migrated_again, "migrated file reloads after real disk save")
			if migrated_again != null:
				t.equal(migrated_again.to_dict()["version"], 6, "resaved historical file uses current container schema")
				t.equal(migrated_again.to_dict().get("combat_revision", -1), 0, "resaving cannot silently upgrade combat")
				t.equal(migrated_again.frames.flatten(), recorded.frames.flatten(), "disk round trip retains historical input bytes")
	SaveSystem.storage_root = root
	SaveSystem._cache = cache
	SaveSystem._dirty = dirty
	SaveSystem._read_only_paths = protected_paths
	Replays._index = index
	t.equal(Replays._index, index, "outer replay index is restored without pruning its recordings")
	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name))
	DirAccess.remove_absolute(folder)
	for name in DirAccess.get_files_at(fixture_root):
		DirAccess.remove_absolute(fixture_root.path_join(name))
	DirAccess.remove_absolute(fixture_root)
	t.ok(not DirAccess.dir_exists_absolute(fixture_root), "only the unique temporary fixture directory is removed")
