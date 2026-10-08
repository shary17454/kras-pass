extends RefCounted

const Config = preload("res://tests/network_smoke_config.gd")


func run(t: TestHarness) -> void:
	t.suite("natural crate network qualification")
	var config := MatchConfig.build("crate_smash", ["fanoos"], 1, 1, 11)
	config.duration_override = 15.0
	Config.configure_crate(config)
	t.equal(config.duration_override, 0.0, "crate uses authored duration")
	var budget: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/crate_smoke_budget.json"))
	t.equal(int(config.definition().duration), int(budget.round_seconds), "budget follows authored duration")
	t.equal(Config.crate_deadline(false), 210, "match covers both rounds and setup")
	t.equal(Config.crate_deadline(true), 960, "tournament includes bounded finals")
	var other := MatchConfig.build("lab_crates", ["fanoos"], 1, 1, 11)
	other.duration_override = 15.0
	Config.configure_crate(other)
	t.equal(other.duration_override, 15.0, "unrelated fixture remains unchanged")
