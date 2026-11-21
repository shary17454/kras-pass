extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("local vehicle views")
	var root := host.get_tree().root
	var original_size := root.size
	var original_disable := root.disable_3d
	var old_touch = UserSettings.get_value("touch_controls")
	UserSettings.set_value("touch_controls", "on")
	for count in [2, 3, 4]:
		for resolution in [Vector2(540, 960), Vector2(1280, 720)]:
			var cells := LocalVehicleViews.regions(resolution, 220, resolution.y * 0.58, count)
			t.equal(cells.size(), count, "exactly one view per local player")
			for first in count:
				t.ok(cells[first].size.x >= 260 and cells[first].size.y > 0, "bounded layout retains positive views")
				for second in range(first + 1, count):
					t.ok(not cells[first].intersects(cells[second]), "views do not overlap")
	t.ok(LocalVehicleViews.regions(Vector2(540, 960), 0, 960, 1).is_empty(), "single-player does not split")
	for game in ["tank_arena", "sabaq_sawarikh", "ring_rumble"]:
		for humans in [1, 2, 3, 4]:
			var cfg := MatchConfig.build(game, ["nabta", "sakhra", "fanoos", "ramla"], humans, 1, 188)
			for player in cfg.players:
				if player.is_human:
					player.device_type = 2
			var scene: Node = load("res://src/match/match_scene.gd").new()
			host.add_child(scene)
			scene.setup({"config": cfg})
			scene.set_physics_process(false)
			for fighter in scene.ctx.fighters:
				fighter.set_physics_process(false)
			var split: bool = game != "ring_rumble" and humans > 1
			t.equal(scene.vehicle_views != null, split, "only local world vehicles split")
			if split:
				t.equal(scene.vehicle_views.cameras.size(), humans, "bots do not allocate rendered views")
				t.ok(root.disable_3d, "unused root 3D view is disabled")
				t.equal(scene.ctx.observation_camera, scene.vehicle_views.cameras[0], "AI uses a real close-view projection")
				t.ok(not scene.ctx.observation_camera.shared_world, "bot perception retains its translated follow view")
				t.equal(scene.touch_sources.size(), humans, "input remains one source per human")
				for index in humans:
					var viewport: SubViewport = scene.vehicle_views.viewports[index]
					t.equal(viewport.find_world_3d(), scene.get_world_3d(), "one shared physics/render world")
					t.ok(not viewport.own_world_3d, "no duplicated simulation")
					t.ok(viewport.gui_disable_input and not viewport.physics_object_picking, "views cannot steal touch events")
					t.ok(not viewport.audio_listener_enable_3d, "no additional audio listeners")
					t.equal(scene.vehicle_views.cameras[index].local_target.slot, index, "camera follows its own player")
				scene._set_phase(MatchPhase.P.INSTRUCTIONS)
				scene._set_phase(MatchPhase.P.COUNTDOWN)
				scene._set_phase(MatchPhase.P.PLAYING)
				t.ok(not scene.hud._hint_label.visible, "persistent text does not cover driving views")
				if humans == 4:
					for slot in 4:
						var fighter: Fighter = scene.ctx.fighter(slot)
						if game == "sabaq_sawarikh":
							var point: Vector3 = scene.arena.track_point(float(slot) / 4.0)
							fighter.global_position = point + Vector3.UP
							fighter.facing = (scene.arena.track_point(float(slot) / 4.0 + 0.01) - point).normalized()
						else:
							var world = scene.arena.get_meta("tank_world")
							var ids: PackedInt64Array = world.roads.get_point_ids()
							fighter.global_position = world.roads.get_point_position(ids[int(slot * ids.size() / 4)]) + Vector3.UP
				for resolution in [Vector2i(540, 960), Vector2i(1280, 720)]:
					root.size = resolution
					for frame in 24:
						await host.get_tree().process_frame
					for index in humans:
						var panel: Control = scene.vehicle_views.panels[index]
						var camera: Camera3D = scene.vehicle_views.cameras[index]
						var bounds := visual_bounds(camera, scene.ctx.fighter(index))
						print("VEHICLE_VIEW game=%s humans=%d window=%s logical_view=%s slot=%d panel=%s actor=%s" % [game, humans, resolution, root.get_visible_rect().size, index, panel.size, bounds])
						t.ok(panel.position.y >= scene.hud.occupied_top(), "views clear HUD after rotation")
						t.ok(panel.get_global_rect().end.y < scene.touch_sources[0].position.y, "views clear touch regions")
						t.ok(Rect2(Vector2.ZERO, panel.size).encloses(bounds), "entire vehicle is inside its view")
						t.ok(bounds.size.x >= 24 and bounds.size.y >= 18, "vehicle is not a distant dot")
						if humans == 4:
							scene.camera._intro_left = 0.0
							scene.camera._frame_shared_world(1.0, root.get_visible_rect().size)
							var overview := visual_bounds(scene.camera, scene.ctx.fighter(index))
							t.ok(bounds.size.y >= overview.size.y * 2.0, "widely separated drivers remain larger than the old shared overview")
						t.ok(scene.vehicle_views.viewports[index].scaling_3d_scale <= 1.0, "split views do not supersample")
						if game == "tank_arena":
							var radar: Control = scene.vehicle_views.radars[index]
							t.ok(Rect2(Vector2.ZERO, panel.size).encloses(Rect2(radar.position, radar.size * radar.scale)), "close view retains its map")
						if DisplayServer.get_name() != "headless":
							await RenderingServer.frame_post_draw
							var image: Image = scene.vehicle_views.viewports[index].get_texture().get_image()
							var colors := {}
							for x in range(0, image.get_width(), 9):
								for y in range(0, image.get_height(), 9):
									colors[image.get_pixel(x, y).to_html()] = true
							t.ok(colors.size() >= 15, "actual personal view renders nonblank content")
					if DisplayServer.get_name() != "headless":
						var output := SaveSystem.storage_root.path_join("vehicle-views")
						DirAccess.make_dir_recursive_absolute(output)
						var filename := "%s-%d-%dx%d.png" % [game, humans, resolution.x, resolution.y]
						t.equal(root.get_texture().get_image().save_png(output.path_join(filename)), OK, "retain actual rendered layout")
					var paused_before: bool = scene._paused
					scene._toggle_pause()
					t.equal(scene._paused, not paused_before, "pause toggles from the actual state, including background auto-pause")
					scene._toggle_pause()
					t.equal(scene._paused, paused_before, "pause restores the preceding state")
					for index in humans:
						var label: Label = scene.vehicle_views._labels[index]
						print("VEHICLE_LABEL slot=%d rect=%s panel=%s" % [index, label.get_rect(), scene.vehicle_views.panels[index].size])
						t.ok(label.text.contains("P%d" % (index + 1)), "personal view identifies its input slot")
						t.ok(Rect2(Vector2.ZERO, scene.vehicle_views.panels[index].size).encloses(label.get_rect()), "personal view name stays inside its frame")
			else:
				t.equal(root.disable_3d, original_disable, "arenas and single-player keep root rendering")
			scene.teardown()
			t.equal(root.disable_3d, original_disable, "teardown restores the root before deferred deletion or the next scene")
			scene.queue_free()
			await host.get_tree().process_frame
			t.equal(root.disable_3d, original_disable, "exit restores viewport state")
	var mixed := MatchConfig.build("tank_arena", ["nabta", "sakhra", "fanoos", "ramla"], 2, 1, 191)
	for player in mixed.players:
		player.is_human = player.slot in [1, 3]
		player.device_type = 2
	var sparse: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(sparse)
	sparse.setup({"config": mixed})
	sparse.set_physics_process(false)
	t.equal(sparse.vehicle_views.slots, [1, 3], "noncontiguous human slots are preserved")
	for index in 2:
		t.equal(sparse.vehicle_views.cameras[index].local_target.slot, [1, 3][index], "view index is not mistaken for player identity")
		t.equal(sparse.touch_sources[index].slot, [1, 3][index], "touch and personal camera have the same owner")
	var old_quality = UserSettings.get_value("graphics_quality")
	var old_battery = UserSettings.get_value("battery_saver")
	for setting in [["graphics_quality", 0], ["graphics_quality", 3], ["battery_saver", true]]:
		UserSettings.set_value(setting[0], setting[1])
		for viewport in sparse.vehicle_views.viewports:
			t.near(viewport.scaling_3d_scale, minf(1.0, root.scaling_3d_scale), 0.001, "active view follows the effective quality profile")
			t.equal(viewport.msaa_3d, root.msaa_3d, "active view follows effective AA, including battery saver")
	UserSettings.set_value("graphics_quality", old_quality)
	UserSettings.set_value("battery_saver", old_battery)
	sparse._set_phase(MatchPhase.P.INSTRUCTIONS)
	sparse._set_phase(MatchPhase.P.COUNTDOWN)
	sparse._set_phase(MatchPhase.P.PLAYING)
	if sparse._paused:
		sparse._toggle_pause()
	var starts: Array[Vector3] = []
	for source in sparse.touch_sources:
		starts.append(sparse.ctx.fighter(source.slot).global_position)
		source._move = Vector2(0, -1)
		source._throttle = 1.0
	sparse.set_physics_process(true)
	var elapsed_before: float = sparse._round_elapsed
	for frame in 60:
		await host.get_tree().physics_frame
	t.near(sparse._round_elapsed - elapsed_before, 1.0, 0.04, "personal views share one real-time simulation clock")
	for index in sparse.touch_sources.size():
		var fighter: Fighter = sparse.ctx.fighter(sparse.touch_sources[index].slot)
		var travel := Vector2(fighter.global_position.x - starts[index].x, fighter.global_position.z - starts[index].z).length()
		t.ok(travel > 0.2, "each noncontiguous human moves through its own touch input")
		t.ok(fighter.global_position.is_finite(), "live vehicle position remains valid")
		t.equal(sparse.vehicle_views.cameras[index].local_target, fighter, "live personal camera retains the input owner")
	sparse.teardown()
	t.equal(root.disable_3d, original_disable, "teardown restores rendering immediately")
	sparse.queue_free()
	await host.get_tree().process_frame
	t.equal(host.get_tree().get_nodes_in_group("fighters").size(), 0, "no duplicate fighters survive local world switches")
	root.size = original_size
	UserSettings.set_value("touch_controls", old_touch)


static func visual_bounds(camera: Camera3D, fighter: Fighter) -> Rect2:
	var bounds := Rect2()
	var found := false
	var pending: Array[Node] = [fighter.get_node("Visual")]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is MeshInstance3D and node.is_visible_in_tree() and node.mesh != null:
			var aabb: AABB = node.get_aabb()
			for corner in 8:
				var pixel := camera.unproject_position(node.global_transform * aabb.get_endpoint(corner))
				bounds = bounds.expand(pixel) if found else Rect2(pixel, Vector2.ZERO)
				found = true
		pending.append_array(node.get_children())
	return bounds
