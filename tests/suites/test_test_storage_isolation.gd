extends RefCounted


func run(t: TestHarness) -> void:
	t.suite("test launch storage isolation")
	var script := load("res://src/save/save_system.gd")
	t.ok(script.has_method("storage_root_for_launch"), "storage selected before autoload reads profiles")
	if not script.has_method("storage_root_for_launch"):
		return
	var runner := PackedStringArray(["--headless", "--path", ".", "tests/test_runner.tscn"])
	var empty := PackedStringArray()
	var choose := func(editor, args, user_args, id): return script.call("storage_root_for_launch", editor, args, user_args, id)
	t.equal(choose.call(true, runner, empty, "run-a"), "user://test-runs/run-a", "bare runner is isolated")
	t.equal(choose.call(true, runner, empty, "run-b"), "user://test-runs/run-b", "separate runs cannot share replay libraries")
	for entry in ["res://tests/test_runner.tscn", "tests/network_peer.tscn", "tests/compile_check.tscn",
			ProjectSettings.globalize_path("res://tests/test_runner.tscn")]:
		t.equal(choose.call(true, PackedStringArray([entry]), empty, "probe"), "user://test-runs/probe", "test entry isolated: " + entry)
	t.equal(choose.call(true, runner, PackedStringArray(["--test-data-dir=/tmp/kras-explicit"]), "run-a"),
		"/tmp/kras-explicit/", "explicit isolated directory is retained")
	for real_root in ["user://", ProjectSettings.globalize_path("user://")]:
		t.equal(choose.call(true, runner, PackedStringArray(["--test-data-dir=" + real_root]), "run-a"),
			"user://test-runs/run-a", "explicit player root is not a test override")
	t.equal(choose.call(true, runner, PackedStringArray(["--test-data-dir=relative"]), "run-a"),
		"user://test-runs/run-a", "invalid relative override cannot select real saves")
	t.equal(choose.call(true, PackedStringArray(["res://scenes/boot.tscn"]), empty, "run-a"),
		"user://", "normal editor gameplay retains real saves")
	t.equal(choose.call(false, runner, PackedStringArray(["--test-data-dir=/tmp/kras-explicit"]), "run-a"),
		"user://", "exported game ignores development-only arguments")
	t.ok(SaveSystem.storage_root != SaveSystem.DIR, "this test process never uses the player's save root")
