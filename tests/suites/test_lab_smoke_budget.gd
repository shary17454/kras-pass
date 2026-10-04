extends RefCounted

const Config = preload("res://tests/network_smoke_config.gd")


func run(t: TestHarness) -> void:
	t.suite("natural lab network qualification")
	var config := MatchConfig.build("lab_crates", ["fanoos"], 1, 1, 1302046270)
	config.duration_override = 15.0
	Config.configure_lab(config)
	t.equal(config.duration_override, 0.0, "lab uses authored duration instead of a short fixture")
	var budget: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/lab_smoke_budget.json"))
	t.equal(int(config.definition().duration), int(budget.round_seconds), "deadline follows the authored 90 second round")
	t.equal(Config.lab_deadline(false), 240, "ordinary budget covers both natural rounds and setup")
	t.equal(Config.lab_deadline(true), 1140, "tournament budget covers all rounds and bounded finals")
	var other := MatchConfig.build("crate_smash", ["fanoos"], 1, 1, 11)
	other.duration_override = 15.0
	Config.configure_lab(other)
	t.equal(other.duration_override, 15.0, "other game fixtures are unchanged")
