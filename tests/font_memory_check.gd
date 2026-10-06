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
	var prime_default_font := false
	var use_ui_theme := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--font-sample="):
			sample = argument.trim_prefix("--font-sample=")
		elif argument == "--clear-system-font-cache":
			clear_system_fonts = true
		elif argument == "--prime-default-font":
			prime_default_font = true
		elif argument == "--use-ui-theme":
			use_ui_theme = true
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
	var server := TextServerManager.get_primary_interface()
	var font_details: Array = []
	for font in [UIKit.font(), UIKit.font_bold()]:
		for rid in font.get_rids():
			font_details.append({"name": server.font_get_name(rid), "system_fallback": server.font_is_allow_system_fallback(rid)})
	snapshots.append(_snapshot("fonts_loaded"))
	var line := TextLine.new()
	line.add_string(text, UIKit.font(), 32)
	line.get_line_width()
	var glyph_fonts: Array[String] = []
	for glyph in server.shaped_text_get_glyphs(line.get_rid()):
		if glyph.font_rid.is_valid():
			var name := server.font_get_name(glyph.font_rid)
			if not glyph_fonts.has(name):
				glyph_fonts.append(name)
	line = null
	snapshots.append(_snapshot("direct_line_shaped"))
	var labels := Control.new()
	if use_ui_theme:
		labels.theme = UIKit.theme()
	add_child(labels)
	for size in [20, 22, 25, 28, 32, 48, 86]:
		for bold in [false, true]:
			var label := Label.new()
			if prime_default_font:
				label.text = text
			label.add_theme_font_override("font", UIKit.font_bold() if bold else UIKit.font())
			label.add_theme_font_size_override("font_size", size)
			label.text = text
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
		"prime_default_before_font_override": prime_default_font,
		"parent_ui_theme": use_ui_theme,
		"font_faces": font_details, "sample_glyph_font_names": glyph_fonts,
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
