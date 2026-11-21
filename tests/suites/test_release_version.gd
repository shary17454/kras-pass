extends RefCounted


func run(t: TestHarness) -> void:
	t.suite("release version consistency")
	var config := ConfigFile.new()
	t.equal(config.load("res://export_presets.cfg"), OK, "iOS export settings exist")
	var options := "preset.0.options"
	t.equal(config.get_value(options, "application/short_version"),
		ProjectSettings.get_setting("application/config/version"),
		"in-game version matches the iOS marketing version")
	var build := str(config.get_value(options, "application/version", ""))
	t.ok(build.is_valid_int() and build.to_int() > 0, "iOS build is a positive integer")
	t.equal(config.get_value(options, "application/bundle_identifier"), "com.shary.kraspass", "approved iOS bundle identity remains unchanged")
	t.equal(config.get_value(options, "application/app_store_team_id"), "4HM66AD594", "approved Apple team remains unchanged")
