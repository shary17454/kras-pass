extends Node

func _ready() -> void:
	var arena := Arena.new()
	add_child(arena)
	arena.build(Registry.arena("sky_causeway"))
	var life = arena.get_node("FantasyWorld/ForestLife")
	life.set_process(false)
	assert(life.groups.size() == 2)
	assert(life.water_materials.size() == 4)
	var count: int = life.get_child_count()
	for group in life.groups:
		assert(group.animals.size() == 4)
		for p in group.path:
			assert(life.world._nearest(p.x, p.z).x > arena.track_width * 0.5 + 4)
	var original: Vector3 = life.groups[0].animals[1].position
	life.advance(10)
	assert(original.distance_to(life.groups[0].animals[1].position) > 3)
	life.advance(6)
	assert(life.groups[0].animals[1].body.rotation.z > 1)
	assert(life.groups[0].animals[0].head.rotation.x > 0.4)
	for i in 100:
		life.advance(24)
	assert(life.get_child_count() == count)
	life.elapsed = 8
	life.advance(0)
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		add_child(camera)
		camera.current = true
		camera.position = life.sites[0] + Vector3(17, 10, 22)
		camera.look_at(life.sites[0] + Vector3.UP * 4)
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/kras-forest-waterfalls-wildlife.png")
	print("FOREST LIFE PASS: two waterfalls, two tigers, six deer; safe paths, chase, capture, bounded nodes")
	arena.queue_free()
	await get_tree().process_frame
	get_tree().quit()
