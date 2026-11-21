extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("bounded static menu portraits")
	for character in Registry.characters():
		var path := Widgets.portrait_path(character)
		t.ok(ResourceLoader.exists(path), "original character has a baked portrait: " + character.id)
		var portrait := Widgets.character_portrait(character) as TextureRect
		t.ok(portrait.texture != null, "menu portrait is not blank: " + character.id)
		t.equal(portrait.get_child_count(), 0, "ordinary menu portrait creates no 3D world or viewport")
		if portrait.texture != null:
			t.equal(portrait.texture.get_size(), Vector2(512, 512), "portrait retains high-resolution art")
			var image := portrait.texture.get_image()
			var visible := 0
			for x in range(0, image.get_width(), 16):
				for y in range(0, image.get_height(), 16):
					if image.get_pixel(x, y).a > 0.1:
						visible += 1
			t.greater(visible, 25, "portrait contains actual rendered character pixels")
		var customized := character.duplicate() as CharacterData
		customized.color = Color(0.123, 0.456, 0.789)
		t.ok(Widgets.portrait_path(customized) != path, "cosmetic recipe cannot reuse stale base art")
		t.ok(not ResourceLoader.exists(Widgets.portrait_path(customized)), "new cosmetics retain live fallback")
		if DisplayServer.get_name() != "headless":
			var live := Widgets.character_portrait(customized)
			t.equal(live.get_child_count(), 1, "customized character still receives a live portrait")
			host.add_child(live)
			live.queue_free()
		portrait.free()
	await host.get_tree().process_frame
