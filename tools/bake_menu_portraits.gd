extends Node
## Bake original recipe models using the same camera as the live menu fallback.


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Portrait baking requires a renderer")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://assets/ui/portraits")
	var failed := false
	for character in Registry.characters():
		var portrait := Widgets.character_portrait(character, true)
		add_child(portrait)
		var viewport := portrait.get_child(0) as SubViewport
		viewport.size = Vector2i(512, 512)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		for frame in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var opaque := 0
		for x in range(0, image.get_width(), 8):
			for y in range(0, image.get_height(), 8):
				if image.get_pixel(x, y).a > 0.1:
					opaque += 1
		var path := Widgets.portrait_path(character)
		if opaque < 100 or image.save_png(path) != OK:
			push_error("Could not bake a nonblank portrait: " + character.id)
			failed = true
		print("MENU_PORTRAIT=%s path=%s nonblank_samples=%d" % [character.id, path, opaque])
		portrait.queue_free()
		await get_tree().process_frame
	AudioManager.shutdown()
	get_tree().quit(1 if failed else 0)
