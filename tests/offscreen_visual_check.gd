extends Node

var _errors: Array[String] = []


func _ready() -> void:
	if SaveSystem.storage_root == SaveSystem.DIR or DisplayServer.get_name() == "headless":
		push_error("Offscreen visual QA requires a renderer and isolated --test-data-dir")
		get_tree().quit(1)
		return
	UserSettings.set_value("replay_capture", false)
	UserSettings.set_value("touch_controls", "on")
	for resolution in [Vector2i(1280, 720), Vector2i(540, 960)]:
		get_window().size = resolution
		for humans in [1, 4]:
			var config := MatchConfig.build("ring_rumble", ["nabta", "sakhra", "fanoos", "ramla"], humans, 1, 742)
			for player in config.players:
				if player.is_human:
					player.device_type = 2
			SceneRouter.start_match(config)
			if not await _wait_screen("match"):
				get_tree().quit(1)
				return
			var scene: Node = SceneRouter.current_node
			scene.set_physics_process(false)
			scene.camera.set_process(false)
			scene.ctx.phase = MatchPhase.P.PLAYING
			scene.hud.show_rules(false)
			scene.hud.show_hints(false)
			scene.hud._centre_label.modulate.a = 0.0
			var view: Transform3D = scene.camera.global_transform
			var centre: Vector3 = scene.arena.global_position
			for slot in 4:
				var offset: Vector3 = [view.basis.x * 100.0, -view.basis.x * 100.0, view.basis.y * 100.0, -view.basis.y * 100.0][slot]
				scene.ctx.fighters[slot].global_position = centre + offset
			await _settle()
			scene.hud._refresh_offscreen_cues()
			await RenderingServer.frame_post_draw
			var label := ("portrait" if resolution.x < resolution.y else "landscape") + "-%s-touch" % humans
			for cue in scene.hud._offscreen_cues:
				if not cue.visible:
					_errors.append(label + ": missing offscreen cue")
				if not get_viewport().get_visible_rect().encloses(cue.get_global_rect()):
					_errors.append(label + ": cue outside viewport")
				for source in scene.touch_sources:
					for rect in source.control_rects():
						if cue.get_global_rect().intersects(rect):
							_errors.append(label + ": cue overlaps touch control")
				for chip in scene.hud._chips:
					if cue.get_global_rect().intersects(chip.root.get_global_rect()):
						_errors.append(label + ": cue overlaps score chip")
			var image := get_viewport().get_texture().get_image()
			if image.save_png("/tmp/kras-offscreen-" + label + ".png") != OK:
				_errors.append(label + ": screenshot failed")
			scene.ctx.fighters[0].hide()
			scene.hud._refresh_offscreen_cues()
			if scene.hud._offscreen_cues[0].visible:
				_errors.append(label + ": hidden actor disclosed")
			scene.ctx.phase = MatchPhase.P.RESULTS
			scene.hud._refresh_offscreen_cues()
			for cue in scene.hud._offscreen_cues:
				if cue.visible:
					_errors.append(label + ": result screen retains cue")
			await SceneRouter.go_to("main_menu", {}, false, 0)
			await _settle()
	if SceneRouter.current_node != null:
		SceneRouter.current_node.queue_free()
		SceneRouter.current_node = null
	await _settle()
	AudioManager.shutdown()
	await _settle()
	OS.delay_msec(100)
	for error in _errors:
		print("FAIL: " + error)
	print("OFFSCREEN VISUAL CHECK: %s failures" % _errors.size())
	get_tree().quit(0 if _errors.is_empty() else 1)


func _settle() -> void:
	for frame in 20:
		await get_tree().process_frame


func _wait_screen(id: String) -> bool:
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		if not SceneRouter._busy and SceneRouter.current_id == id and is_instance_valid(SceneRouter.current_node):
			await _settle()
			return true
		await get_tree().process_frame
	print("FAIL: timed out preparing ", id)
	return false
