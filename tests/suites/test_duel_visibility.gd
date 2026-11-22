extends RefCounted

const Fader = preload("res://src/camera/arena_occlusion_fader.gd")
const PhysicsHost = preload("res://tests/duel_visibility_physics_host.gd")


func _sample(host: Node, fader: RefCounted, fixture: Dictionary, targets: Array, delta: float) -> void:
	await host.run_in_physics(func(): fader.update(fixture.camera, fixture.arena, targets, delta))

class FloodFader extends "res://src/camera/arena_occlusion_fader.gd":
	var obstacle: StaticBody3D
	var masks: Array[int] = []
	func _intersect_ray(_camera: Camera3D, query: PhysicsRayQueryParameters3D) -> Dictionary:
		masks.append(query.collision_mask)
		assert(not query.collide_with_areas and query.collide_with_bodies)
		return {"collider": obstacle}


func run(t: TestHarness, host: Node) -> void:
	var physics_host := host
	var adapter: Node
	if not host.has_method("run_in_physics"):
		adapter = PhysicsHost.new()
		adapter.set_physics_process(false)
		host.add_child(adapter)
		physics_host = adapter
	await _run_cases(t, physics_host)
	if adapter != null:
		adapter.queue_free()
		await host.get_tree().process_frame


func _run_cases(t: TestHarness, host: Node) -> void:
	t.suite("duel camera occluder material isolation")
	await _pit_contract(t, host)
	await _real_rays_and_ai(t, host)
	await _bounded_queries(t, host)
	await _bounded_cache(t, host)
	await _camera_cleanup(t, host)
	var capture: Script = load("res://tests/duel_visibility_capture.gd")
	t.ok(capture != null and capture.can_instantiate(), "capture fixture compiles without starting a native window")
	var live: Script = load("res://tests/duel_visibility_live.gd")
	t.ok(live != null and live.can_instantiate(), "live observer compiles without changing or starting the live smoke")


func _pit(host: Node, enabled: bool) -> Arena:
	var arena := Arena.new()
	host.add_child(arena)
	arena.position = Vector3(0, 1000, 0)
	arena.def = Registry.arena("duel_pit").duplicate(true)
	if not enabled:
		arena.def.params["camera_occluder_alpha"] = 0.0
	arena.current_radius = arena.def.radius
	arena._static_root = Node3D.new()
	arena.add_child(arena._static_root)
	arena._build_pit()
	return arena


func _geometry(arena: Arena) -> Array:
	var out: Array = []
	for body in arena._static_root.get_children():
		if not body is StaticBody3D:
			continue
		var mesh: MeshInstance3D = body.get_child(0)
		var shape: CollisionShape3D = body.get_child(1)
		var dimensions: Variant = shape.shape.size if shape.shape is BoxShape3D else Vector2(shape.shape.radius, shape.shape.height)
		var surfaces: Array = []
		for surface in mesh.mesh.get_surface_count():
			surfaces.append(mesh.mesh.surface_get_arrays(surface))
		out.append({"transform": body.transform, "layer": body.collision_layer,
			"mask": body.collision_mask, "shape_transform": shape.transform,
			"disabled": shape.disabled, "dimensions": dimensions, "mesh_transform": mesh.transform,
			"vertices": surfaces, "material": mesh.material_override})
	return out


func _pit_contract(t: TestHarness, host: Node) -> void:
	t.test("tagging is opt-in, elevated-only and does not rebuild gameplay")
	var before := _pit(host, false)
	var after := _pit(host, true)
	t.equal(_geometry(after), _geometry(before), "bodies, shapes, vertex arrays, transforms and originals are identical")
	t.equal(after.def.spawns_for(4), before.def.spawns_for(4), "authored spawns are unchanged")
	var tagged := 0
	for body in after._static_root.get_children():
		if body.has_meta(Fader.TAG):
			t.greater(body.position.y, 0.0, "only elevated supports carry the tag")
			t.not_null(body.get_node_or_null(NodePath(body.get_meta(Fader.TAG))), "tag points at its own real mesh")
			tagged += 1
	t.equal(tagged, 25, "three original tiers and summit are tagged, never floor or rim")
	t.near(after._static_root.get_node("Summit").position.y, 9.1, 0.0001, "summit remains at its authored height")
	t.near(Fader.alpha_for(Registry.arena("duel_pit")), 0.12, 0.0001, "duel alone defaults to runtime opt-in")
	for definition in Registry.arenas():
		if definition.id != "duel_pit":
			t.equal(Fader.alpha_for(definition), 0.0, "other venue defaults to zero: " + definition.id)
	before.queue_free()
	after.queue_free()
	await host.get_tree().process_frame


func _block(arena: Arena, z: float, material: Material, tagged := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(0, 1, z)
	arena.add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4, 4, 0.5)
	mesh.mesh = box
	mesh.material_override = material
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var collision := BoxShape3D.new()
	collision.size = box.size
	shape.shape = collision
	body.add_child(shape)
	if tagged:
		arena._tag_camera_occluder(body)
	return body


func _ray_fixture(host: Node) -> Dictionary:
	var arena := Arena.new()
	host.add_child(arena)
	arena.position = Vector3(0, 1000, 0)
	arena.def = Registry.arena("duel_pit").duplicate(true)
	var camera := Camera3D.new()
	arena.add_child(camera)
	camera.position = Vector3(0, 1, 10)
	camera.look_at(arena.global_position + Vector3.UP)
	var target := Fighter.new()
	arena.add_child(target)
	target.position = Vector3.ZERO
	target.set_physics_process(false)
	target.reset_physics_interpolation()
	return {"arena": arena, "camera": camera, "target": target}


func _real_rays_and_ai(t: TestHarness, host: Node) -> void:
	t.test("stacked actual physics rays, original materials, AI and restoration")
	var f := _ray_fixture(host)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.4, 0.2, 0.3, 1.0)
	var blocks: Array[StaticBody3D] = []
	var snapshots: Array = []
	for z in [6.0, 4.0, 2.0]:
		var body := _block(f.arena, z, material)
		blocks.append(body)
		snapshots.append([body.transform, body.collision_layer, body.collision_mask,
			body.get_child(1).shape.size, body.get_child(1).transform, body.get_child(1).disabled,
			body.get_child(0).mesh, body.get_child(0).transform])
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	var probe := Node3D.new()
	f.arena.add_child(probe)
	probe.position = Vector3.UP
	var context := MatchContext.new()
	context.config = MatchConfig.build("duel_pit", ["nabta"], 0, 1, 119)
	context.observation_camera = f.camera
	var brain := AIBrain.new()
	brain.configure(0, context, 3, 119)
	var clear_probe := Node3D.new()
	f.arena.add_child(clear_probe)
	clear_probe.position = Vector3(6, 1, 0)
	var snapshot_before: Dictionary = await host.run_in_physics(func(): return _snapshot(f, blocks, brain, [probe, f.target, clear_probe]))
	var ai_before: Array = snapshot_before.observations
	t.equal(ai_before, [false, false, true], "AI baseline includes both blocked and clear actual-world observations")
	var fader := Fader.new()
	await _sample(host, fader, f, [f.target], 0.0)
	t.equal(fader.diagnostics().active, 3, "both samples can traverse and fade stacked tagged bodies")
	var snapshot_after: Dictionary = await host.run_in_physics(func(): return _snapshot(f, blocks, brain, [probe, f.target, clear_probe]))
	t.equal(snapshot_after, snapshot_before, "AI observations, ray collider, transforms and collision snapshots are identical after fade")
	var path := SaveSystem.storage_root.path_join("duel-visibility-snapshot.json")
	t.ok(not FileAccess.file_exists(path), "snapshot evidence is not overwritten")
	if not FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.WRITE)
		t.not_null(file, "AI/collision before-after evidence is writable in isolated test storage")
		if file != null:
			file.store_string(JSON.stringify({"before": snapshot_before, "after": snapshot_after,
				"unchanged": snapshot_before == snapshot_after, "host": OS.get_name(),
				"scope": "physics_callback_CPU_fixture_not_iPhone"}, "\t"))
			file.close()
	t.equal(material.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED, "cached shared source is never changed")
	t.equal(material.albedo_color.a, 1.0, "source material retains its original alpha")
	var copies: Array[int] = []
	for i in blocks.size():
		var body := blocks[i]
		var mesh: MeshInstance3D = body.get_child(0)
		copies.append(mesh.material_override.get_instance_id())
		t.ok(mesh.material_override != material, "override is a private copy")
		t.equal(mesh.material_override.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "Mobile uses material alpha blending, not geometry transparency")
		t.near(mesh.material_override.albedo_color.a, 0.12, 0.0001, "terrain remains faint but nonzero for AI classification")
		t.equal([body.transform, body.collision_layer, body.collision_mask, body.get_child(1).shape.size,
			body.get_child(1).transform, body.get_child(1).disabled, body.get_child(0).mesh,
			body.get_child(0).transform], snapshots[i], "visual treatment never changes a collider, mesh or transform")
	var count: int = fader.samples
	await _sample(host, fader, f, [f.target], 0.01)
	t.equal(fader.samples, count, "sub-interval frames do not issue another query batch")
	for cycle in 30:
		await _sample(host, fader, f, [], 0.1)
		for body in blocks:
			t.equal(body.get_child(0).material_override, material, "unoccluded mesh restores exact original reference")
		await _sample(host, fader, f, [f.target], 0.1)
		for i in blocks.size():
			t.equal(blocks[i].get_child(0).material_override.get_instance_id(), copies[i], "repeat occlusion reuses the same copy")
	t.equal(fader.diagnostics().cached, 3, "repeated restoration does not grow the cache")
	t.equal(fader.copies_created, 3, "copies are created on cache misses, never each frame or reappearance")
	print("DUEL_FADE_HOTPATH=" + JSON.stringify(fader.diagnostics()))
	var faded_weak := weakref(blocks[0].get_child(0).material_override)
	f.target.alive = false
	await _sample(host, fader, f, [f.target], 0.1)
	t.equal(fader.diagnostics().active, 0, "eliminated players do not keep terrain faded")
	f.target.alive = true
	var barrier := _block(f.arena, 8.0, material, false)
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	await _sample(host, fader, f, [f.target], 0.1)
	t.equal(fader.diagnostics().active, 0, "untagged wall stops traversal and never fades")
	t.equal(barrier.get_child(0).material_override, material, "untagged floor/wall material is untouched")
	barrier.collision_layer = 2
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	await _sample(host, fader, f, [f.target], 0.1)
	t.equal(fader.diagnostics().active, 3, "player collision layers are ignored by the world-only query")
	fader.clear()
	t.equal(fader.diagnostics().cached, 0, "cleanup releases all material cache entries")
	t.ok(faded_weak.get_ref() == null, "private material has no retained reference after cleanup")
	for body in blocks:
		t.equal(body.get_child(0).material_override, material, "cleanup restores exact originals")
	f.arena.queue_free()
	await host.get_tree().process_frame


func _bounded_queries(t: TestHarness, host: Node) -> void:
	t.test("adversarial hits and targets cannot exceed the fixed budget")
	var f := _ray_fixture(host)
	var material := StandardMaterial3D.new()
	var body := _block(f.arena, 5.0, material)
	var fader := FloodFader.new()
	fader.obstacle = body
	var targets: Array = []
	for i in 20:
		targets.append(f.target)
	await host.get_tree().process_frame
	fader.update(f.camera, f.arena, targets, 0.0)
	t.equal(fader.samples, 0, "idle/render context cannot access direct physics space")
	t.equal(fader.skipped_non_physics, 1, "idle access is explicitly rejected before querying")
	await _sample(host, fader, f, targets, 0.0)
	t.equal(fader.queries_last_sample, 48, "four targets times two samples times six hits is a hard cap")
	t.equal(fader.targets_last_sample, 4, "target scanning is capped before inspecting an oversized list")
	print("DUEL_FADE_WORST_QUERY_BOUND=" + JSON.stringify(fader.diagnostics()))
	t.ok(fader.masks.all(func(mask): return mask == 1), "every ray uses world mask 1 only")
	var count: int = fader.samples
	await _sample(host, fader, f, targets, 100.0)
	t.equal(fader.samples, count + 1, "a large delta creates no catch-up query storm")
	f.arena.def.params["camera_occluder_alpha"] = 0.0
	await _sample(host, fader, f, targets, 0.0)
	t.equal(fader.diagnostics().cached, 0, "disabling the option immediately releases cache")
	t.equal(body.get_child(0).material_override, material, "disabling restores exact original")
	f.arena.queue_free()
	await host.get_tree().process_frame


func _camera_cleanup(t: TestHarness, host: Node) -> void:
	t.test("camera reconfiguration and removal restore originals")
	var f := _ray_fixture(host)
	var material := StandardMaterial3D.new()
	var body := _block(f.arena, 5.0, material)
	var mesh: MeshInstance3D = body.get_child(0)
	var camera := ArenaCamera.new()
	f.arena.add_child(camera)
	camera.set_process(false)
	camera._occlusion_fader._apply({mesh.get_instance_id(): mesh}, 0.12)
	camera.configure(ArenaCamera.Mode.ARENA, f.arena)
	t.equal(mesh.material_override, material, "configure retires prior visual state")
	camera._occlusion_fader._apply({mesh.get_instance_id(): mesh}, 0.12)
	camera.queue_free()
	await host.get_tree().process_frame
	t.equal(mesh.material_override, material, "exit_tree restores material while arena still exists")
	var fader := Fader.new()
	mesh.material_override = null
	mesh.mesh.surface_set_material(0, material)
	fader._apply({mesh.get_instance_id(): mesh}, 0.12)
	t.not_null(mesh.material_override, "single-surface art without override can fade")
	fader.clear()
	t.ok(mesh.material_override == null, "restoration preserves an originally null override")
	t.equal(mesh.mesh.surface_get_material(0), material, "shared mesh surface material remains unchanged")
	mesh.mesh.surface_set_material(0, null)
	var shader := ShaderMaterial.new()
	mesh.material_override = shader
	fader._apply({mesh.get_instance_id(): mesh}, 0.12)
	t.equal(mesh.material_override, shader, "unknown custom shader is not replaced")
	t.equal(fader.diagnostics().cached, 0, "unsupported art cannot create retained cache entries")
	f.arena.queue_free()
	await host.get_tree().process_frame


func _bounded_cache(t: TestHarness, host: Node) -> void:
	t.test("cache capacity, freed meshes and clone release")
	var f := _ray_fixture(host)
	var material := StandardMaterial3D.new()
	var entries := {}
	var first: StaticBody3D
	for index in 70:
		var body := _block(f.arena, 20.0 + float(index), material)
		if index == 0:
			first = body
		var mesh: MeshInstance3D = body.get_child(0)
		entries[mesh.get_instance_id()] = mesh
	var fader := Fader.new()
	fader._apply(entries, 0.12)
	t.equal(fader.diagnostics().cached, 64, "even an oversized candidate set cannot grow the cache above 64")
	t.equal(fader.copies_created, 64, "objects beyond the cap do not allocate materials")
	var removed_id := first.get_child(0).get_instance_id()
	entries.erase(removed_id)
	first.queue_free()
	await host.get_tree().process_frame
	fader._apply({}, 0.12)
	t.equal(fader.diagnostics().cached, 63, "freed geometry is pruned without retaining a stale node")
	t.equal(fader.diagnostics().active, 0, "all surviving meshes restore when no target is occluded")
	var refs := _material_refs(fader)
	fader.clear()
	t.equal(fader.diagnostics().cached, 0, "clear releases a full cache")
	for ref in refs:
		t.ok(ref.get_ref() == null, "private clone is not retained after a full-cache clear")
	f.arena.queue_free()
	await host.get_tree().process_frame


func _material_refs(fader: RefCounted) -> Array[WeakRef]:
	var refs: Array[WeakRef] = []
	for entry in fader._cache.values():
		refs.append(weakref(entry.faded))
	return refs


func _transform_values(value: Transform3D) -> Array:
	var values: Array = []
	for vector in [value.basis.x, value.basis.y, value.basis.z, value.origin]:
		values.append_array([vector.x, vector.y, vector.z])
	return values


func _snapshot(fixture: Dictionary, blocks: Array[StaticBody3D], brain: AIBrain, probes: Array) -> Dictionary:
	var observations: Array = []
	for probe in probes:
		observations.append(brain.can_observe(probe))
	var bodies: Array = []
	for body in blocks:
		var shape: CollisionShape3D = body.get_child(1)
		var mesh: MeshInstance3D = body.get_child(0)
		var size: Vector3 = shape.shape.size
		bodies.append({"rid": str(body.get_rid()), "transform": _transform_values(body.global_transform),
			"collision_layer": body.collision_layer, "collision_mask": body.collision_mask,
			"shape_transform": _transform_values(shape.transform), "shape_size": [size.x, size.y, size.z],
			"shape_disabled": shape.disabled, "shape_resource": shape.shape.get_instance_id(),
			"mesh_resource": mesh.mesh.get_instance_id(), "mesh_transform": _transform_values(mesh.global_transform)})
	var ray := PhysicsRayQueryParameters3D.create(fixture.camera.global_position, probes[0].global_position, 1)
	var hit: Dictionary = fixture.camera.get_world_3d().direct_space_state.intersect_ray(ray)
	return {"observations": observations, "bodies": bodies, "ray_collider": str(hit.get("rid", RID())),
		"target_transform": _transform_values(fixture.target.global_transform), "alive": fixture.target.alive,
		"camera_transform": _transform_values(fixture.camera.global_transform),
		"separate_physics_thread": ProjectSettings.get_setting_with_override("physics/3d/run_on_separate_thread"),
		"in_physics_callback": Engine.is_in_physics_frame()}
