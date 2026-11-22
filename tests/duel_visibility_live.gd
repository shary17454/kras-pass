extends "res://tests/stage_zero_visual.gd"
## Observe the unchanged live smoke path; never suppress its foreground guards.

var _fade_rows: Array = []
var _seen_samples := {}


func _ready() -> void:
	var expected := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--expect-method="):
			expected = arg.trim_prefix("--expect-method=")
	var method := RenderingServer.get_current_rendering_method()
	var driver := RenderingServer.get_current_rendering_driver_name()
	var adapter := RenderingServer.get_video_adapter_name()
	if SaveSystem.storage_root == SaveSystem.DIR or DisplayServer.get_name() == "headless" \
			or expected not in ["mobile", "forward_plus"] or method != expected or driver != "metal" \
			or adapter.is_empty() or "software" in adapter.to_lower() or "swiftshader" in adapter.to_lower() \
			or "llvmpipe" in adapter.to_lower():
		push_error("Live visibility smoke requires the requested hardware Metal renderer and isolated storage")
		get_tree().quit(1)
		return
	await super._ready()
	# The parent has recorded its unchanged live/pause/background verdict and
	# requested quit. Persist the observer synchronously before returning.
	var report := {"scope": "Mac_live_smoke_CPU_samples_not_iPhone_or_GPU_benchmark",
		"method": method, "driver": driver, "adapter": adapter,
		"separate_physics_thread": ProjectSettings.get_setting_with_override("physics/3d/run_on_separate_thread"),
		"rows": _fade_rows, "physicalDeviceQualified": false, "releaseReady": false}
	var path := SaveSystem.storage_root.path_join("duel-live-fade.json")
	if FileAccess.file_exists(path):
		push_error("Live observer will not overwrite existing evidence")
		get_tree().quit(1)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write live fade observations")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()


func _process(_delta: float) -> void:
	var scene := SceneRouter.current_node
	if SceneRouter.current_id != "match" or not is_instance_valid(scene) or not is_instance_valid(scene.camera):
		return
	var diagnostics: Dictionary = scene.camera._occlusion_fader.diagnostics()
	var key := "%d:%d" % [scene.get_instance_id(), int(diagnostics.samples)]
	if _seen_samples.has(key) or not MatchPhase.is_live(scene.phase):
		return
	_seen_samples[key] = true
	_fade_rows.append({"scene": scene.get_instance_id(), "physics_tick": scene._tick_index,
		"window": [get_window().size.x, get_window().size.y], "fade": diagnostics,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"paused": scene._paused, "backgrounded": Platform.is_backgrounded})
