extends Node
## Compiles every script in the project and reports failures.
##
##   godot --headless --path . tests/compile_check.tscn
##
## The editor's import pass does not surface every runtime compile error (it
## applies a different warning policy), so this walks the tree explicitly. It is
## the first thing to run after a large refactor.
##
## Walks src/, tests/ **and tools/**: a tool script that fails to compile does
## not error loudly, it just runs a scene with no script attached and spins
## forever, which is a far more expensive way to find out.


func _ready() -> void:
	var failures: Array[String] = []
	var checked := 0
	for path in _scripts("res://src") + _scripts("res://tests") + _scripts("res://tools"):
		checked += 1
		var script: Script = ResourceLoader.load(path, "Script")
		if script == null:
			failures.append(path + " — failed to load")
			continue
		if not script.can_instantiate() and not script.is_abstract():
			failures.append(path + " — compiled but cannot instantiate")
	print("\ncompile check: %d scripts" % checked)
	if failures.is_empty():
		print("OK — every script compiles")
	else:
		for f in failures:
			print("  ✗ %s" % f)
		print("FAILED — %d script(s) with problems" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _scripts(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := root + "/" + name
		if dir.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_scripts(full))
		elif name.ends_with(".gd"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return out
