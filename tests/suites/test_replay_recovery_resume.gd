extends RefCounted

func run(t: TestHarness, host: Node) -> void:
	t.suite("replay recovery persisted resume")
	while Replays._recovery_running:
		await host.get_tree().process_frame
	var root: String = SaveSystem.storage_root
	var cache: Dictionary = SaveSystem._cache.duplicate(true)
	var dirty: Dictionary = SaveSystem._dirty.duplicate(true)
	var protected_paths: Dictionary = SaveSystem._read_only_paths.duplicate(true)
	var index: Array = Replays._index.duplicate(true)
	SaveSystem.storage_root = root.path_join("replay_resume_fixture")
	DirAccess.make_dir_recursive_absolute(SaveSystem.storage_root.path_join("replays"))
	SaveSystem._cache = {SaveSystem.PROFILE: {"schema": SaveSystem.SCHEMA_VERSION}}
	SaveSystem._dirty = {}
	SaveSystem._read_only_paths = {}
	Replays._index = []
	var cfg := MatchConfig.build("ring_rumble", ["nabta", "sakhra", "fanoos", "ramla"], 0, 2, 19)
	var packet := PackedByteArray()
	for slot in 4:
		packet.append_array(InputFrame.new().encode())
	var replay := ReplayData.from_match(cfg, [packet], {}, {}, null)
	replay.id = "a_valid"
	var payload := JSON.stringify(replay.to_dict())
	var budget := payload.to_utf8_buffer().size()
	t.ok(Replays._write_atomic(replay.id, payload), "complete orphan fixture is committed")
	t.ok(Replays._write_atomic("zz_invalid", "!".repeat(budget)), "invalid candidate consumes exactly one pass budget")
	SaveSystem.set_shared_branch(Replays.RECOVERY_BRANCH, {"version": 1, "custom": "retain"})
	var first: Dictionary = await Replays.recover_library(budget)
	t.equal(first.recovered, 0, "first bounded pass only examines invalid candidate")
	t.equal(first.read_bytes, budget, "first pass respects exact read bound")
	t.ok(first.deferred > 0, "valid candidate is deferred, not discarded")
	var saved = SaveSystem._read(SaveSystem._path(SaveSystem.PROFILE))
	t.ok(saved is Dictionary and saved.get(Replays.RECOVERY_BRANCH, {}).get("cursor", "") == "zz_invalid.json", "resume position is actually persisted on disk")
	t.equal(SaveSystem.shared_branch(Replays.RECOVERY_BRANCH).custom, "retain", "additional marker metadata is preserved")
	SaveSystem._cache.erase(SaveSystem.PROFILE)
	SaveSystem._cache[SaveSystem.PROFILE] = SaveSystem.load_slot(SaveSystem.PROFILE)
	var second: Dictionary = await Replays.recover_library(budget)
	t.equal(second.recovered, 1, "disk-loaded cursor allows valid file past earlier invalid candidate")
	t.equal(second.read_bytes, budget, "resumed pass retains its read bound")
	t.ok(not Replays.index().is_empty() and Replays.index()[0].id == replay.id, "resumed recording appears in library")
	t.ok(FileAccess.file_exists(Replays._path("zz_invalid")), "invalid source file remains untouched")
	var future := {"version": 2, "future_metadata": [7, 9]}
	SaveSystem.set_shared_branch(Replays.RECOVERY_BRANCH, future.duplicate(true))
	SaveSystem.flush()
	await Replays.recover_library(budget)
	t.equal(SaveSystem.shared_branch(Replays.RECOVERY_BRANCH), future, "unknown future marker cannot be overwritten")
	Replays._index = []
	SaveSystem.set_shared_branch(Replays.RECOVERY_BRANCH, {"version": 1, "cursor": "zz_deleted.json"})
	t.equal((await Replays.recover_library(budget)).recovered, 1, "deleted cursor filename still provides lexical continuation")
	var marker_before = SaveSystem.shared_branch(Replays.RECOVERY_BRANCH).duplicate(true)
	await Replays.recover_library(0)
	t.equal(SaveSystem.shared_branch(Replays.RECOVERY_BRANCH), marker_before, "zero-budget call does not advance or destroy progress")
	Replays._index = []
	SaveSystem.set_shared_branch(Replays.RECOVERY_BRANCH, {"version": 1})
	host.get_tree().process_frame.connect(func(): SaveSystem.set_shared_branch(Replays.RECOVERY_BRANCH, future.duplicate(true)), CONNECT_ONE_SHOT)
	await Replays.recover_library(budget)
	t.equal(SaveSystem.shared_branch(Replays.RECOVERY_BRANCH), future, "future marker arriving during recovery is preserved")
	for id in [replay.id, "zz_invalid"]:
		DirAccess.remove_absolute(Replays._path(id))
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SaveSystem._path(SaveSystem.PROFILE) + suffix)
	SaveSystem.storage_root = root
	SaveSystem._cache = cache
	SaveSystem._dirty = dirty
	SaveSystem._read_only_paths = protected_paths
	Replays._index = index
