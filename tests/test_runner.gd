extends Node
## Headless test entry point.
##
##   godot --headless --fixed-fps 60 --path . tests/test_runner.tscn
##
## Backs up the real profile before running, restores it afterwards, and exits
## with a non-zero status on failure so CI can gate on it.

const SUITES := [
	"res://tests/suites/test_scoring.gd",
	"res://tests/suites/test_content.gd",
	"res://tests/suites/test_save.gd",
	"res://tests/suites/test_systems.gd",
	"res://tests/suites/test_input_sources.gd",
	"res://tests/suites/test_replay.gd",
	"res://tests/suites/test_playlist.gd",
	"res://tests/suites/test_mutators.gd",
	"res://tests/suites/test_matches.gd",
]

var _t: TestHarness
var _profile_backup := {}
var _settings_backup := {}


func _ready() -> void:
	await get_tree().process_frame
	_t = TestHarness.new()
	print("\nKRAS PASS test suite — Godot %s, %s" % [
		Engine.get_version_info().string, OS.get_name()])
	_backup()
	var started := Time.get_ticks_msec()
	for path in SUITES:
		var script: Script = load(path)
		if script == null:
			_t.suite(path)
			_t.ok(false, "suite failed to load")
			continue
		var suite = script.new()
		# Suites that need the tree take a host node; pure ones do not.
		if suite.run.get_argument_count() >= 2:
			await suite.run(_t, self)
		else:
			suite.run(_t)
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	print("\nfinished in %.1fs" % elapsed)
	_restore()
	var code := _t.report()
	get_tree().quit(code)


## Tests write to the same `user://` directory as the game. Snapshot the two
## real slots first so running the suite never costs a developer their progress.
func _backup() -> void:
	_profile_backup = SaveSystem.profile().duplicate(true)
	_settings_backup = SaveSystem.settings().duplicate(true)


func _restore() -> void:
	SaveSystem.erase("test_profile")
	SaveSystem.set_profile(_profile_backup)
	SaveSystem.set_settings(_settings_backup)
	SaveSystem.flush()
