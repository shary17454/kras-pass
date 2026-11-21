extends "res://tools/balance_contact_probe.gd"
## Counterfactual development experiment, never natural release evidence.

const SAMPLE_MODE := "counterfactual_resistance"
const MatchRuntime := preload("res://src/match/match_scene.gd")


func _parse_args(arguments: PackedStringArray) -> bool:
	return super._parse_args(arguments) and only == "sweeper_storm" and natural_rounds


func _on_round_started(index: int) -> void:
	super._on_round_started(index)
	for child in get_children():
		if child is MatchRuntime and child.ctx != null:
			for fighter in child.ctx.fighters:
				_neutralize_resistance(fighter)


func _neutralize_resistance(fighter: Fighter) -> void:
	var neutral := Fighter.new()
	neutral.data = CharacterData.new()
	neutral._apply_character()
	fighter.knock_resist = neutral.knock_resist
	neutral.free()


func _write_reports() -> void:
	_source_end = Evidence.capture()
	var rows: Array = _report.duplicate(true)
	for row in rows:
		row["sample_mode"] = SAMPLE_MODE
	DirAccess.make_dir_recursive_absolute(out_dir)
	var file := FileAccess.open(out_dir.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write counterfactual experiment evidence")
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify({
		"simulation_source_start": _source_start, "simulation_source_end": _source_end,
		"engine_version": Engine.get_version_info().string,
		"generated": Time.get_datetime_string_from_system(),
		"seed_offset": seed_offset, "runs_per_game": runs,
		"sample_mode": SAMPLE_MODE, "experiment": "neutral fighter knock resistance",
		"games": rows, "mutator_smoke": _mutator_report,
	}, "  "))
	file.close()
	var html := FileAccess.open(out_dir.path_join("report.html"), FileAccess.WRITE)
	if html != null:
		html.store_string("<!doctype html><title>Counterfactual experiment</title><h1>Not natural release evidence</h1><p>See report.json for neutral-resistance results.</p>")
		html.close()
