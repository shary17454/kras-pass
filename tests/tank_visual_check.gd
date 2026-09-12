extends Node


func _ready() -> void:
	Loc.set_locale("ar")
	UserSettings._values["touch_controls"] = "on"
	var maps := Registry.minigame("tank_arena").arena_ids
	if OS.get_cmdline_user_args().has("--first-map"):
		maps = maps.slice(0, 1)
	for arena_id in maps:
		var cfg := MatchConfig.build("tank_arena", ["fanoos", "mowja", "ramla", "nabta"], 1, 1, 72)
		cfg.arena_id = arena_id
		var scene: Node = load("res://src/match/match_scene.gd").new()
		add_child(scene)
		scene.setup({"config": cfg, "on_finished": func(_r): pass})
		var deadline := Time.get_ticks_msec() + 15000
		while scene.phase != MatchPhase.P.INSTRUCTIONS and Time.get_ticks_msec() < deadline:
			await get_tree().physics_frame
		scene.hud.ready_requested.emit()
		while not MatchPhase.is_live(scene.phase) and Time.get_ticks_msec() < deadline:
			await get_tree().physics_frame
		if not MatchPhase.is_live(scene.phase):
			push_error("Tank map did not reach gameplay: " + arena_id)
			get_tree().quit(1)
			return
		for i in 60:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		var suffix := "portrait" if get_viewport().get_visible_rect().size.x < get_viewport().get_visible_rect().size.y else "landscape"
		get_viewport().get_texture().get_image().save_png("/tmp/kras-%s-%s.png" % [arena_id, suffix])
		scene.camera.set_process(false)
		var rider: Vector3 = scene.ctx.fighter(0).global_position
		scene.camera.fov = 72.0
		scene.camera.global_position = rider + Vector3(2.8, 1.8, 0.6)
		scene.camera.look_at(rider + Vector3.UP)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/kras-%s-atv-detail-%s.png" % [arena_id, suffix])
		scene.camera.fov = 58.0
		scene.camera.global_position = Vector3(0, 106, 58)
		scene.camera.look_at(Vector3.ZERO)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/kras-%s-overview-%s.png" % [arena_id, suffix])
		print("Rendered tank map: ", arena_id)
		scene.teardown()
		scene.queue_free()
		await get_tree().process_frame
	get_tree().quit()
