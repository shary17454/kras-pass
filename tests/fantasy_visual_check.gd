extends Node


func _ready() -> void:
	Loc.set_locale("ar")
	UserSettings._values["touch_controls"] = "on"
	for arena_id in ["sky_causeway", "frost_hairpin", "magma_ring"]:
		var cfg := MatchConfig.build("sabaq_sawarikh", ["fanoos", "mowja", "ramla", "nabta"], 1, 1, 72)
		cfg.arena_id = arena_id
		var scene: Node = load("res://src/match/match_scene.gd").new()
		add_child(scene)
		scene.setup({"config": cfg, "on_finished": func(_r): pass})
		var deadline := Time.get_ticks_msec() + 18000
		while scene.phase != MatchPhase.P.INSTRUCTIONS and Time.get_ticks_msec() < deadline:
			await get_tree().physics_frame
		scene.hud.ready_requested.emit()
		while not MatchPhase.is_live(scene.phase) and Time.get_ticks_msec() < deadline:
			await get_tree().physics_frame
		if not MatchPhase.is_live(scene.phase):
			push_error("Fantasy visual check timed out before gameplay: " + arena_id)
			scene.teardown()
			scene.queue_free()
			await get_tree().process_frame
			get_tree().quit(1)
			return
		for i in 90:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		var suffix := "portrait" if get_viewport().get_visible_rect().size.x < get_viewport().get_visible_rect().size.y else "landscape"
		get_viewport().get_texture().get_image().save_png("/tmp/kras-fantasy-%s-%s.png" % [arena_id, suffix])
		print("Rendered fantasy world: ", arena_id)
		scene.teardown()
		scene.queue_free()
		await get_tree().process_frame
	get_tree().quit()
