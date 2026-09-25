extends Node
## Read-only inventory of the runtime graph. Writes evidence, never saves or assets.

const ROOTS := ["res://src", "res://scenes", "res://data", "res://assets", "res://tests", "res://tools"]
const RESOURCE_TYPES := ["gd", "tscn", "scn", "tres", "res", "gdshader", "glb", "gltf"]
var _issues: Array[String] = []
var _files: Array[String] = []
var _ignored: Array[String] = []


func _ready() -> void:
	for root in ROOTS:
		_walk(root)
	_files.sort()
	var by_extension := {}
	var resources: Array = []
	var source_fingerprints := PackedStringArray()
	for path in _files:
		var ext := path.get_extension()
		by_extension[ext] = int(by_extension.get(ext, 0)) + 1
		if ext in ["gd", "json", "tscn", "tres", "gdshader"]:
			source_fingerprints.append(path + ":" + FileAccess.get_sha256(path))
		if ext == "json":
			var parser := JSON.new()
			if parser.parse(FileAccess.get_file_as_string(path)) != OK:
				_issues.append("Invalid JSON: " + path)
		if ext in RESOURCE_TYPES:
			var dependencies: Array[String] = []
			var import_valid := true
			if FileAccess.file_exists(path + ".import"):
				var mapping := ConfigFile.new()
				if mapping.load(path + ".import") != OK:
					_issues.append("Invalid import mapping: " + path)
					import_valid = false
				else:
					for destination in mapping.get_value("deps", "dest_files", []):
						if not FileAccess.file_exists(destination):
							_issues.append("Missing imported resource: " + String(destination))
							import_valid = false
			if not import_valid:
				continue
			for dependency in ResourceLoader.get_dependencies(path):
				var parts := dependency.split("::")
				var target := String(parts[parts.size() - 1])
				dependencies.append(target)
				if not ResourceLoader.exists(target):
					_issues.append("Missing dependency: %s -> %s" % [path, target])
			resources.append({"path": path, "dependencies": dependencies})
	source_fingerprints.append("project.godot:" + FileAccess.get_sha256("res://project.godot"))
	var autoloads: Array = []
	for property in ProjectSettings.get_property_list():
		var key := String(property.name)
		if not key.begins_with("autoload/"):
			continue
		var path := String(ProjectSettings.get_setting(key)).trim_prefix("*")
		var name := key.trim_prefix("autoload/")
		var node := get_node_or_null("/root/" + name)
		autoloads.append({"name": name, "path": path, "instantiated": node != null})
		if node == null or not ResourceLoader.exists(path):
			_issues.append("Missing autoload: " + name)
	var actions: Array = []
	for action in InputMap.get_actions():
		if action.begins_with("ui_") and action != "ui_back":
			continue
		var events: Array[String] = []
		for event in InputMap.action_get_events(action):
			events.append(event.as_text())
		actions.append({"action": action, "deadzone": InputMap.action_get_deadzone(action), "events": events})
		if events.is_empty():
			_issues.append("Unbound project action: " + action)
	var routes: Array = []
	for id in SceneRouter.SCREENS:
		var path: String = SceneRouter.SCREENS[id]
		routes.append({"id": id, "path": path})
		if not ResourceLoader.exists(path):
			_issues.append("Missing screen: " + id)
	var main_scene := String(ProjectSettings.get_setting("application/run/main_scene"))
	var boot: PackedScene = load(main_scene)
	if boot == null or not boot.can_instantiate():
		_issues.append("Boot scene cannot instantiate")
	var characters: Array = []
	for character in Registry.characters():
		characters.append({"id": character.id, "stats": {
			"speed": character.speed, "accel": character.accel, "power": character.power,
			"weight": character.weight, "jump": character.jump, "control": character.control},
			"total": character.stat_total(), "archetype": character.archetype,
			"perk": character.perk, "perk_scale": character.perk_scale, "starter": character.starter})
		if not is_equal_approx(character.stat_total(), 3.0):
			_issues.append("Character budget: " + character.id)
	var original_locale := Loc.locale
	for locale in ["ar", "en"]:
		Loc.set_locale(locale)
		for issue in Registry.validate():
			_issues.append(locale + ": " + issue)
	Loc.set_locale(original_locale)
	if Registry.all_minigames().size() != 39 or characters.size() != 8:
		_issues.append("Unexpected catalogue size")
	var report := {
		"generated_utc": Time.get_datetime_string_from_system(true),
		"engine": Engine.get_version_info().string,
		"source_fingerprint": "\n".join(source_fingerprints).sha256_text(),
		"scope": ROOTS, "ignored_by_godot": _ignored, "files_by_extension": by_extension, "resources": resources,
		"autoloads": autoloads, "input_actions": actions, "routes": routes,
		"main_scene": main_scene, "characters": characters,
		"save_schema_version": SaveSystem.SCHEMA_VERSION, "replay_version": ReplayData.VERSION,
		"minigames": Registry.all_minigames().size(), "arenas": Registry.arenas().size(),
		"issues": _issues,
		"limitations": ["Source/import dependency graph, not iOS archive validation.",
			"InputRouter polls per-slot gameplay actions outside InputMap.",
			"Runtime navigation and match completion are tested separately by check_party.sh.",
			"No dead-code deletion is justified by an unused static dependency alone."]}
	DirAccess.make_dir_recursive_absolute("res://build/stage0")
	var file := FileAccess.open("res://build/stage0/inventory.json", FileAccess.WRITE)
	if file == null:
		push_error("Cannot write stage-zero inventory")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("STAGE ZERO: %d resources, %d autoloads, %d routes, %d characters, %d issues" % [
		resources.size(), autoloads.size(), routes.size(), characters.size(), _issues.size()])
	for issue in _issues:
		print("FAIL: " + issue)
	get_tree().quit(0 if _issues.is_empty() else 1)


func _walk(root: String) -> void:
	if FileAccess.file_exists(root.path_join(".gdignore")):
		_ignored.append(root)
		return
	var directory := DirAccess.open(root)
	if directory == null:
		_issues.append("Missing inventory root: " + root)
		return
	for name in directory.get_files():
		if not name.ends_with(".import") and not name.ends_with(".uid"):
			_files.append(root.path_join(name))
	for name in directory.get_directories():
		if not name.begins_with("."):
			_walk(root.path_join(name))
