extends Node
## Presentation fixture only. Network behavior is tested by network-smoke.js.


func _ready() -> void:
	if SaveSystem.storage_root == SaveSystem.DIR or DisplayServer.get_name() == "headless":
		push_error("Online UI check requires a renderer and isolated --test-data-dir")
		get_tree().quit(1)
		return
	Loc.set_locale("ar")
	Net.online_available = true
	Net.room_code = "ABC234"
	Net.room_state = "lobby"
	Net.state = Net.State.LOBBY
	Net.mode = Net.Mode.ONLINE_HOST
	Net.lobby_config = {"game": "ring_rumble", "arena": "vortex_ring", "rounds": 3, "bots": true, "difficulty": 1}
	for i in 4:
		Net.peers[i + 1] = {"id": i + 1, "slot": i, "name": "P%d" % (i + 1), "ready": true, "connected": true, "character": i}
	for dimensions in [Vector2i(1920, 1080), Vector2i(1080, 1920)]:
		get_window().size = dimensions
		get_window().content_scale_size = dimensions
		var screen := load("res://src/ui/screens/online_screen.gd").new() as Screen
		add_child(screen)
		screen.setup({})
		await get_tree().create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		var path := "/tmp/kras-online-ui-%dx%d.png" % [dimensions.x, dimensions.y]
		get_viewport().get_texture().get_image().save_png(path)
		print("ONLINE_UI_SCREENSHOT=" + path)
		screen.queue_free()
		await get_tree().process_frame
	Net.leave()
	get_tree().quit()
