extends Node
## Structural validation is necessary, but never sufficient for READY.


func _ready() -> void:
	var balance: Dictionary = {}
	var balance_path := "res://build/balance/report.json"
	if FileAccess.file_exists(balance_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(balance_path))
		if parsed is Dictionary:
			balance = parsed
	var measured := {}
	var sources := {}
	for row in balance.get("games", []):
		var id := String(row.get("id", row.get("game_id", "")))
		measured[id] = row
		sources[id] = balance_path
	var rechecks: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--recheck="):
			var path := arg.trim_prefix("--recheck=")
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if not parsed is Dictionary:
				push_error("Invalid balance recheck: " + path)
				get_tree().quit(1)
				return
			for row in parsed.get("games", []):
				measured[String(row.get("id", ""))] = row
				sources[String(row.get("id", ""))] = path
			rechecks.append(path)
	var original_locale := Loc.locale
	var rows: Array = []
	var counts := {"READY": 0, "NEEDS_POLISH": 0, "NEEDS_BALANCE": 0, "REWORK": 0, "BROKEN": 0}
	for game in Registry.all_minigames():
		var errors: Array[String] = []
		for locale in ["ar", "en"]:
			Loc.set_locale(locale)
			for problem in MiniGameValidator.validate(game):
				errors.append(locale + ": " + problem)
		var sample: Dictionary = measured.get(game.id, {})
		var flags: Array = sample.get("flags", [])
		var status := "NEEDS_BALANCE" if not flags.is_empty() else "NEEDS_POLISH"
		if int(sample.get("severity", 0)) >= 2:
			status = "REWORK"
		if not errors.is_empty():
			status = "BROKEN"
		counts[status] += 1
		var code := {}
		if errors.is_empty():
			var script: Script = load(game.controller_script)
			var controller: MiniGameController = script.new()
			code = {"controller": game.controller_script, "inheritance": _ancestry(script),
				"ai": controller.ai_script().resource_path,
				"camera_mode": controller.camera_mode(), "locomotion": controller.locomotion(),
				"round_clock": controller.uses_round_clock(), "scoring": game.scoring}
			controller.free()
		Loc.set_locale("ar")
		rows.append({"id": game.id, "name_ar": Loc.t(game.name_key), "name_key": game.name_key, "category": game.category_name(),
			"boss": game.is_boss, "arenas": Array(game.arena_ids),
			"players": [game.min_players, game.max_players], "duration": game.duration,
			"input": ControlProfile.NAMES.get(game.control_profile, "unknown"),
			"status": status, "validation_errors": errors, "balance_flags": flags,
			"code": code, "balance_source": sources.get(game.id, "not measured"),
			"balance_evidence": sample,
			"reason": "Structural validation failed" if status == "BROKEN" else
				"Balance simulation flagged this game; confirm on a representative sample" if not flags.is_empty() else
				"Automated structure valid; game-specific playability and device QA not signed off",
			"release_gate": "Real-device portrait/landscape playtest, fair-AI review, representative balance sample and sustained frame-time/thermal capture remain required."})
	Loc.set_locale(original_locale)
	var output := "res://build/party/content-audit.json"
	DirAccess.make_dir_recursive_absolute("res://build/party")
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write party content audit")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify({"generated": Time.get_datetime_string_from_system(),
		"balance_generated": balance.get("generated", "not measured"),
		"balance_runs_per_game": balance.get("runs_per_game", 0),
		"rechecks": rechecks,
		"counts": counts, "games": rows}, "  "))
	file.close()
	print("PARTY CONTENT AUDIT: %s -> %s" % [counts, output])
	get_tree().quit(1 if counts["REWORK"] > 0 or counts["BROKEN"] > 0 else 0)


func _ancestry(script: Script) -> Array[String]:
	var paths: Array[String] = []
	while script != null:
		paths.append(script.resource_path)
		script = script.get_base_script()
	return paths
