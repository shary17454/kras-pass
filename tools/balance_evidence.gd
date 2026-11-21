extends RefCounted
## Simulation-source identity, not an archive/signature or device-QA claim.

const ROOTS := ["res://src", "res://scenes", "res://data", "res://tools"]
const EXTENSIONS := ["gd", "tscn", "scn", "tres", "res", "json", "gdshader"]


static func capture() -> String:
	var entries := {}
	for root in ROOTS:
		if not _walk(root, entries):
			return ""
	entries["res://project.godot"] = FileAccess.get_sha256("res://project.godot")
	return fingerprint(entries)


static func fingerprint(entries: Dictionary) -> String:
	var paths := entries.keys()
	paths.sort()
	var lines := PackedStringArray()
	for path in paths:
		var digest: Variant = entries[path]
		if not path is String or not digest is String or digest.length() != 64 or not digest.is_valid_hex_number(false):
			return ""
		lines.append(path + ":" + digest)
	return "\n".join(lines).sha256_text() if not lines.is_empty() else ""


static func _walk(path: String, entries: Dictionary) -> bool:
	var directory := DirAccess.open(path)
	if directory == null:
		return false
	for name in directory.get_files():
		if name.get_extension() in EXTENSIONS:
			var file := path.path_join(name)
			entries[file] = FileAccess.get_sha256(file)
	for name in directory.get_directories():
		if not name.begins_with(".") and not _walk(path.path_join(name), entries):
			return false
	return true


static func problems(report: Dictionary, sample: Dictionary, current: String) -> Array[String]:
	var issues: Array[String] = []
	if current.is_empty() or report.get("simulation_source_start") != current or report.get("simulation_source_end") != current:
		issues.append("missing, changed or stale simulation source")
	if report.get("engine_version") != Engine.get_version_info().string:
		issues.append("unverified engine version")
	if report.get("sample_mode") != "natural" or sample.get("sample_mode") != "natural":
		issues.append("natural round evidence required")
	for key in ["attempted_runs", "runs"]:
		if not _count(sample.get(key), 24):
			issues.append("incomplete baseline: " + key)
	if _count(sample.get("attempted_runs"), 24) and _count(sample.get("runs"), 24) \
		and sample.attempted_runs != sample.runs:
		issues.append("baseline attempts did not all complete")
	for key in ["difficulty_attempted", "difficulty_completed"]:
		if not _count(sample.get(key), 16):
			issues.append("incomplete paired difficulty: " + key)
	if _count(sample.get("difficulty_attempted"), 16) and _count(sample.get("difficulty_completed"), 16) \
		and sample.difficulty_attempted != sample.difficulty_completed:
		issues.append("difficulty attempts did not all complete")
	if sample.get("difficulty_pairing") != "matched_seed_character":
		issues.append("matched difficulty policy required")
	if not sample.get("flags") is Array:
		issues.append("invalid balance flags")
	return issues


static func _count(value: Variant, minimum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and value == floor(float(value)) and value >= minimum
