extends Node
## ABBA collision experiment; not a frame-rate or device qualification.

var failed := false
var geometry_equal := true


func _ready() -> void:
	var cfg := MatchConfig.build("tank_arena", ["fanoos", "mowja", "ramla", "nabta"], 0, 1, 72)
	cfg.arena_id = "tank_foundry"
	var scene: Node = load("res://src/match/match_scene.gd").new()
	add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var cover: StaticBody3D = scene.controller.world.buildings[3]
	var collider: CollisionShape3D = cover.get_child(1)
	var original: ConvexPolygonShape3D = collider.shape
	var original_scale := collider.scale
	var baked := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for point in original.points:
		points.append(point * original_scale)
	baked.points = points
	var original_transform := collider.global_transform
	var baked_transform := Transform3D(cover.global_basis, collider.global_position)
	for index in points.size():
		if not (original_transform * original.points[index]).is_equal_approx(baked_transform * points[index]):
			geometry_equal = false
	failed = not geometry_equal
	var fighter: Fighter = scene.ctx.fighter(2)
	var rows: Array[Dictionary] = []
	for mode in ["scaled", "baked", "baked", "scaled"]:
		collider.shape = baked if mode == "baked" else original
		collider.scale = Vector3.ONE if mode == "baked" else original_scale
		await get_tree().physics_frame
		await get_tree().physics_frame
		var times: Array[int] = []
		var contacts := 0
		for step in 120:
			await get_tree().physics_frame
			fighter.global_position = Vector3(-28.23, 0.193, 25.5)
			var direction := cover.global_position - fighter.global_position
			direction.y = 0.0
			fighter.velocity = direction.normalized() * 14.0 + Vector3.DOWN * 1.0
			var started := Time.get_ticks_usec()
			fighter.move_and_slide()
			times.append(Time.get_ticks_usec() - started)
			for hit in fighter.get_slide_collision_count():
				if fighter.get_slide_collision(hit).get_collider() == cover:
					contacts += 1
					break
		times.sort()
		var total := 0
		for elapsed in times:
			total += elapsed
		rows.append({"mode": mode, "samples": times.size(), "cover_contacts": contacts,
			"mean_usec": float(total) / times.size(), "p95_usec": times[113], "max_usec": times.back()})
		failed = failed or contacts != times.size()
	print("COVER_SCALE_PROBE ", JSON.stringify({"geometry_equal": geometry_equal, "rows": rows,
		"scope": "repeated-fixed-pose-body-motion-not-gameplay-fps"}))
	scene.teardown()
	scene.queue_free()
	AudioManager.shutdown()
	await get_tree().process_frame
	await get_tree().process_frame
	OS.delay_msec(100)
	get_tree().quit(1 if failed else 0)
