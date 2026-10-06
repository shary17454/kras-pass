extends Node
## Observe shaped-text ownership before considering live fallback-cache eviction.

func _ready() -> void:
	if not OS.has_feature("editor") or SaveSystem.storage_root == SaveSystem.DIR:
		push_error("Live font-cache QA requires isolated --test-data-dir")
		get_tree().quit(1)
		return
	SaveSystem.enabled = false
	var server := TextServerManager.get_primary_interface()
	var text := "كراس باس 🏆 123"
	var line := TextLine.new()
	if not line.add_string(text, UIKit.font(), 32):
		push_error("Could not shape live font-cache probe")
		get_tree().quit(1)
		return
	var width := line.get_line_width()
	var before: Array = server.shaped_text_get_glyphs(line.get_rid())
	var invalid_before := _invalid_fonts(before, server)
	server.font_clear_system_fallback_cache()
	var stale_saved := _invalid_fonts(before, server)
	var after: Array = server.shaped_text_get_glyphs(line.get_rid())
	var invalid_after := _invalid_fonts(after, server)
	var rebuilt := TextLine.new()
	rebuilt.add_string(text, UIKit.font(), 32)
	rebuilt.get_line_width()
	var reconstructed: Array = server.shaped_text_get_glyphs(rebuilt.get_rid())
	var report := {"engine": Engine.get_version_info().string, "os": OS.get_name(),
		"before_count": before.size(), "before_invalid": invalid_before,
		"saved_glyphs_invalid_after_clear": stale_saved,
		"cached_line_invalid_after_clear": invalid_after,
		"rebuilt_invalid": _invalid_fonts(reconstructed, server),
		"width_before": width, "width_after": line.get_line_width(),
		"width_rebuilt": rebuilt.get_line_width()}
	print("LIVE_FONT_CACHE: ", JSON.stringify(report))
	var file := FileAccess.open(SaveSystem.storage_root.path_join("live-font-cache.json"), FileAccess.WRITE)
	if file == null or before.is_empty() or invalid_before != 0 or reconstructed.is_empty() or report.rebuilt_invalid != 0:
		push_error("Invalid live font-cache diagnostic evidence")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	line = null
	rebuilt = null
	UIKit.invalidate_theme()
	UIKit._font = null
	UIKit._font_bold = null
	await get_tree().process_frame
	get_tree().quit(0)

func _invalid_fonts(glyphs: Array, server: TextServer) -> int:
	var invalid := 0
	for glyph in glyphs:
		if glyph.font_rid.is_valid() and not server.has(glyph.font_rid):
			invalid += 1
	return invalid
