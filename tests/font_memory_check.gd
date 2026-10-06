extends Node
## Isolate font allocation from arena geometry; never use the player's save.

func _ready() -> void:
	if not OS.has_feature("editor") or SaveSystem.storage_root == SaveSystem.DIR:
		push_error("Font memory QA requires isolated --test-data-dir")
		get_tree().quit(1)
		return
	SaveSystem.enabled = false
	var sample := "arabic"
	var clear_system_fonts := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--font-sample="):
			sample = argument.trim_prefix("--font-sample=")
		elif argument == "--clear-system-font-cache":
			clear_system_fonts = true
	if sample not in ["arabic", "symbols", "emoji"]:
		push_error("Font sample must be arabic, symbols or emoji")
		get_tree().quit(1)
		return
	var text := "كراس باس بطولة الجولة الأخيرة اللاعب الفائز KRAS PASS 0123456789"
	if sample == "symbols":
		text = "● ▲ ■ ★ ♥ ◇ ✦ → ← 0123456789"
	elif sample == "emoji":
		text = "🏆 🎲 🔥 ⚡ 👑"
	var snapshots: Array = []
	await _settle()
	snapshots.append(_snapshot("baseline"))
	var labels := Control.new()
	add_child(labels)
	for size in [20, 22, 25, 28, 32, 48, 86]:
		for bold in [false, true]:
			var label := Label.new()
			label.text = text
			label.add_theme_font_override("font", UIKit.font_bold() if bold else UIKit.font())
			label.add_theme_font_size_override("font_size", size)
			labels.add_child(label)
			label.get_minimum_size()
	await _settle()
	snapshots.append(_snapshot("labels_alive"))
	labels.queue_free()
	await _settle()
	snapshots.append(_snapshot("labels_freed_shared_fonts_retained"))
	UIKit.invalidate_theme()
	UIKit._font = null
	UIKit._font_bold = null
	await _settle()
	snapshots.append(_snapshot("shared_fonts_released"))
	if clear_system_fonts:
		# Diagnostic only: labels and shared UI fonts have already been released.
		TextServerManager.get_primary_interface().font_clear_system_fallback_cache()
		await _settle()
		snapshots.append(_snapshot("system_fallback_cache_released"))
	var report := {"engine": Engine.get_version_info().string, "os": OS.get_name(),
		"display": DisplayServer.get_name(), "pid": OS.get_process_id(),
		"sample": sample, "system_cache_release_requested": clear_system_fonts,
		"snapshots": snapshots}
	var file := FileAccess.open(SaveSystem.storage_root.path_join("font-memory.json"), FileAccess.WRITE)
	if file == null:
		push_error("Could not write font memory report")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	get_tree().quit(0)


func _settle() -> void:
	var until := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _snapshot(stage: String) -> Dictionary:
	var result := {"stage": stage, "static_bytes": OS.get_static_memory_usage(),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)}
	print("FONT_MEMORY: ", JSON.stringify(result))
	return result
