extends Node
## Render the terminal version error without contacting any network endpoint.

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Network version visual QA requires a renderer")
		get_tree().quit(1)
		return
	var output := SaveSystem.storage_root.path_join("screenshots")
	DirAccess.make_dir_recursive_absolute(output)
	var failures := 0
	for locale in ["ar", "en"]:
		Loc.set_locale(locale)
		for resolution in [Vector2i(540, 960), Vector2i(1280, 720)]:
			get_window().size = resolution
			Net.reset()
			Net.online_available = true
			await SceneRouter.go_to("online", {}, false, 0)
			Net._token = "test-only-version-recovery"
			Net._transport_lost("protocol_mismatch")
			for frame in 8:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var screen = SceneRouter.current_node
			var label: Label = screen._status
			var image := get_viewport().get_texture().get_image()
			var orientation := "portrait" if resolution.x < resolution.y else "landscape"
			var file := output.path_join("network-version-%s-%s.png" % [locale, orientation])
			var bounds := get_viewport().get_visible_rect()
			var passed: bool = image.save_png(file) == OK \
				and label.text == Loc.t("online.version_mismatch") \
				and bounds.encloses(label.get_global_rect()) \
				and Net.state == Net.State.OFFLINE and Net._retry_until == 0 \
				and Net._token.is_empty()
			if not passed:
				failures += 1
			print("NETWORK VERSION VISUAL %s/%s: %s" % [locale, orientation, "PASS" if passed else "FAIL"])
	Net.reset()
	await SceneRouter.go_to("main_menu", {}, false, 0)
	AudioManager.shutdown()
	await get_tree().process_frame
	await get_tree().process_frame
	OS.delay_msec(100)
	get_tree().quit(0 if failures == 0 else 1)
