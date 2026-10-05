extends RefCounted


func run(t: TestHarness) -> void:
	t.suite("replay atomic storage and budgets")
	var replay := ReplayData.new()
	replay.id = "storage_test"
	replay.players = [{"slot": 0, "character": "nabta"}]
	replay.frames.append(InputFrame.new().encode())
	var before := Replays.count()
	t.ok(Replays.save(replay), "initial recording commits")
	var path := Replays._path(replay.id)
	var original := _read(path)
	t.ok(not Replays._write_atomic(replay.id, "replacement", 4), "over-budget replacement refused")
	t.equal(_read(path), original, "refusal retains exact previous file")
	var wide := String.chr(233).repeat(3)
	t.ok(not Replays._write_atomic(replay.id, wide, 4), "budget counts UTF8 bytes, not characters")
	t.equal(_read(path), original, "UTF8 budget refusal preserves previous file")
	var tmp := path + ".tmp"
	t.equal(DirAccess.make_dir_absolute(tmp), OK, "blocked temporary path fixture created")
	replay.seed_value = 77
	t.ok(not Replays.save(replay), "unwritable temporary path refuses replacement")
	t.equal(_read(path), original, "write-open failure preserves previous recording")
	t.equal(Replays.count(), before + 1, "failed save cannot append index entry")
	t.equal(DirAccess.remove_absolute(tmp), OK, "blocked path fixture removed")
	t.ok(Replays.save(replay), "successful retry replaces atomically")
	var loaded := Replays.load_replay(replay.id)
	t.ok(loaded != null and loaded.seed_value == 77, "replacement is a complete readable recording")
	t.ok(not FileAccess.file_exists(tmp), "successful rename leaves no temporary file")
	t.equal(Replays.index()[0]["bytes"], Replays._file_bytes(replay.id), "index measures actual serialized bytes")
	var stale: Array = Replays._index.duplicate(true)
	stale[-1]["bytes"] = {"invalid": "old metadata"}
	SaveSystem.set_shared_branch(Replays.INDEX_BRANCH, stale)
	Replays._load_index()
	t.equal(Replays.index()[0]["bytes"], Replays._file_bytes(replay.id), "startup repairs stale size metadata from disk")
	Replays.erase(replay.id)
	t.equal(Replays.count(), before, "atomic fixture cleans up its index")
	var blocked_id := "storage_blocked_destination"
	var blocked := Replays._path(blocked_id)
	t.equal(DirAccess.make_dir_absolute(blocked), OK, "rename failure fixture created")
	t.ok(not Replays._write_atomic(blocked_id, original), "failed rename does not report a committed file")
	t.ok(not FileAccess.file_exists(blocked + ".tmp"), "failed rename removes its staged file")
	t.equal(DirAccess.remove_absolute(blocked), OK, "rename failure fixture cleaned up")

	var oversized_id := "storage_oversized"
	var oversized_path := Replays._path(oversized_id)
	var file := FileAccess.open(oversized_path, FileAccess.WRITE)
	t.not_null(file, "oversized fixture opens")
	if file != null:
		file.seek(Replays.MAX_FILE_BYTES)
		file.store_8(0)
		file.close()
		t.equal(Replays._file_bytes(oversized_id), Replays.MAX_FILE_BYTES + 1, "fixture exceeds read bound")
		t.ok(Replays.load_replay(oversized_id) == null, "oversized file rejected before JSON read")
		t.ok(FileAccess.file_exists(oversized_path), "reader refusal does not delete data")
		DirAccess.remove_absolute(oversized_path)

	var original_index: Array = Replays._index.duplicate(true)
	var fixtures: Array = []
	for i in 3:
		replay.id = "storage_budget_%d" % i
		t.ok(Replays.save(replay), "budget fixture commits")
		fixtures.append(Replays.index()[0].duplicate(true))
	Replays._index = fixtures
	var each := Replays._file_bytes(replay.id)
	fixtures[0]["highlights"] = 1
	Replays._prune(each * 2)
	t.equal(Replays.count(), 2, "actual byte budget prunes even below count limit")
	t.ok(Replays.total_bytes() <= each * 2, "remaining index stays within byte budget")
	t.ok(FileAccess.file_exists(Replays._path("storage_budget_0")), "highlight retains existing retention preference")
	t.ok(not FileAccess.file_exists(Replays._path("storage_budget_1")), "oldest unhighlighted recording removed")
	for i in 3:
		DirAccess.remove_absolute(Replays._path("storage_budget_%d" % i))
	Replays._index = original_index
	Replays._commit()
	t.equal(Replays.count(), before, "budget test restores unrelated library entries")


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text
