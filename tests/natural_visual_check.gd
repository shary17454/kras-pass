extends Node


func _ready() -> void:
	Loc.set_locale("ar")
	UserSettings._values["touch_controls"] = "on"
	var cfg := MatchConfig.build("sabaq_sawarikh", ["fanoos", "mowja", "ramla", "nabta"], 1, 1, 72)
	cfg.arena_id = "sky_causeway"
	var scene: Node = load("res://src/match/match_scene.gd").new()
	add_child(scene)
	var begin := Time.get_ticks_msec()
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	print("Natural world setup ms: ", Time.get_ticks_msec() - begin)
	var deadline := Time.get_ticks_msec() + 20000
	while scene.phase != MatchPhase.P.INSTRUCTIONS and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	scene.hud.ready_requested.emit()
	while not MatchPhase.is_live(scene.phase) and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	if not MatchPhase.is_live(scene.phase):
		push_error("Natural world did not reach gameplay")
		scene.teardown()
		scene.queue_free()
		get_tree().quit(1)
		return
	var suffix := "portrait" if get_viewport().get_visible_rect().size.x < get_viewport().get_visible_rect().size.y else "landscape"
	suffix += "-" + RenderingServer.get_current_rendering_method()
	for index in [0, 18, 60]:
		var fighter: Fighter = scene.ctx.fighter(0)
		var p: Vector3 = scene.arena.circuit_line[index]
		fighter.respawn_at(p + Vector3.UP * 1.3)
		fighter.facing = (scene.arena.circuit_line[(index + 1) % 120] - p).normalized()
		for i in 120:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		var shot := get_viewport().get_texture().get_image()
		var reference := shot.get_pixel(shot.get_width() / 2, shot.get_height() / 2)
		var variation := 0.0
		for x in range(1, 8):
			var color := shot.get_pixel(x * shot.get_width() / 8, shot.get_height() / 2)
			variation += absf(color.r - reference.r) + absf(color.g - reference.g) + absf(color.b - reference.b)
		if variation < 0.05:
			push_error("Natural world rendered blank")
			get_tree().quit(1)
			return
		shot.save_png("/tmp/kras-natural-%s-%d.png" % [suffix, index])
		print("Natural view ", index, " fps=", Performance.get_monitor(Performance.TIME_FPS), " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	scene.teardown()
	scene.queue_free()
	await get_tree().process_frame
	get_tree().quit()
