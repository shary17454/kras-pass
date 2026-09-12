extends Node


func _settle(frames: int = 45) -> void:
	for i in frames:
		await get_tree().process_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var orientation := "portrait" if get_window().size.x < get_window().size.y else "landscape"
	get_viewport().get_texture().get_image().save_png("/tmp/kras-%s-%s.png" % [orientation, label])


func _ready() -> void:
	Loc.set_locale("ar")
	SceneRouter.go_to("game_library", {}, false, 0.0)
	await _settle()
	await _shot("library")
	SceneRouter.go_to("quick_play", {"game_id": "ring_rumble"}, false, 0.0)
	await _settle()
	await _shot("setup")
	UserSettings._values["touch_controls"] = "on"
	var cfg := MatchConfig.build("ring_rumble", ["fanoos", "mowja", "ramla", "nabta"], 1, 0, 42)
	var script: Script = load("res://src/match/match_scene.gd")
	var scene: Node = script.new()
	add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	SceneRouter.current_node.hide()
	scene._set_phase(MatchPhase.P.INSTRUCTIONS)
	await _settle()
	await _shot("rules")
	scene.hud.ready_requested.emit()
	assert(scene.phase == MatchPhase.P.COUNTDOWN)
	await _settle(240)
	await _shot("playing")
	var phase_before: int = scene.phase
	var window_size := get_window().size
	get_window().size = Vector2i(window_size.y, window_size.x)
	await _settle(45)
	assert(scene.phase == phase_before)
	assert(scene.touch.size == get_viewport().get_visible_rect().size)
	await _shot("rotated-playing")
	scene.teardown()
	scene.queue_free()
	await _settle(2)
	print("Usability flow: library, setup, rules, countdown, playing verified")
	get_tree().quit()
