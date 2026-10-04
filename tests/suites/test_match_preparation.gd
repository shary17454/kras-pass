extends RefCounted

const Preparation = preload("res://src/match/match_resource_preparation.gd")

class DelayedPreparation extends "res://src/match/match_resource_preparation.gd":
	var state := ResourceLoader.THREAD_LOAD_IN_PROGRESS
	var retrieved := 0
	func _request(_path: String) -> Error:
		return OK
	func _status(_path: String) -> int:
		return state
	func _take(_path: String) -> Resource:
		retrieved += 1
		return Resource.new()
	func _wait_limit() -> int:
		return 0

class RefusingRouter extends "res://src/core/scene_router.gd":
	var saw_disabled := false
	func _prepare_match(_preparation: Node, _config: MatchConfig) -> bool:
		saw_disabled = current_node.process_mode == Node.PROCESS_MODE_DISABLED
		await get_tree().process_frame
		return false

class SuccessfulRouter extends "res://src/core/scene_router.gd":
	var retained_at_swap := false
	var progress_at_swap := false
	func _swap(id: String, args: Dictionary) -> bool:
		if id == "match":
			progress_at_swap = loading_progress.visible
			for child in get_children():
				if child.has_method("prepare") and child.has_method("release"):
					retained_at_swap = not child.resources.is_empty()
		return super._swap(id, args)


func run(t: TestHarness, host: Node) -> void:
	t.suite("match resource preparation")
	var root := host.get_tree()
	var simple := MatchConfig.build("ring_rumble", ["nabta", "sakhra", "barq", "turs"], 1, 1, 11)
	var simple_paths := Preparation.paths_for(simple)
	t.equal(simple_paths.size(), 2, "simple arena does not load unrelated natural worlds")
	t.ok(simple_paths.has(simple.definition().controller_script), "selected controller is planned")
	t.ok(Preparation.paths_for(null).is_empty(), "missing configuration has no plan")
	var extra := "res://src/arenas/valley_water.gdshader"
	var custom := MiniGameDef.from_dict({"id": "custom", "preload_resources": [extra]})
	var venue := ArenaDef.from_dict({"id": "custom", "preload_resources": [extra]})
	var custom_paths := Preparation.paths_for_definitions(custom, venue)
	t.ok(custom_paths.has(extra), "new games can declare resources without editing the router")
	t.equal(custom_paths.count(extra), 1, "game and arena resources share one retained reference")
	t.ok(MiniGameValidator.validate_preload_resources(custom.preload_resources, "custom").is_empty(), "valid declared resources pass content validation")
	t.equal(MiniGameValidator.validate_preload_resources(PackedStringArray(["user://external.tres", "res://missing.tres"]), "custom").size(), 2, "external and missing resource declarations fail validation")
	for definition in Registry.minigames():
		for arena_id in definition.arena_ids:
			var config := MatchConfig.build(definition.id, ["nabta"], 0, 1, 11)
			config.arena_id = arena_id
			var paths := Preparation.paths_for(config)
			t.ok(not paths.is_empty(), "resource plan exists: %s/%s" % [definition.id, arena_id])
			var seen := {}
			for path in paths:
				t.ok(ResourceLoader.exists(path), "planned resource exists: " + path)
				t.ok(not seen.has(path), "resource plan has no duplicate: " + path)
				seen[path] = true
	var config := MatchConfig.build("sabaq_sawarikh", ["nabta"], 0, 1, 11)
	config.arena_id = "alula_rain"
	var alula := Preparation.paths_for(config)
	t.ok(alula.has("res://src/arenas/alula_world.gd"), "AlUla uses actual selected scenery")
	t.ok(alula.has("res://src/arenas/alula_clouds.gdshader"), "AlUla cloud resource is prepared")
	t.ok(not alula.has("res://src/arenas/tank_world.gd"), "race does not retain the tank world")
	config.arena_id = "pharaoh_valley"
	t.ok(Preparation.paths_for(config).has("res://src/arenas/voyage_world.gd"), "Pharaoh world uses shared runtime routing")
	config.arena_id = "missing"
	t.equal(Preparation.paths_for(config), Preparation.paths_for(MatchConfig.build("sabaq_sawarikh", ["nabta"], 0, 1, 11)), "arena fallback matches the scene builder")
	var job := Preparation.new()
	host.add_child(job)
	var progress: Array[float] = []
	t.ok(await job.prepare(simple_paths, func(value: float): progress.append(value)), "real threaded script preparation succeeds")
	t.equal(job.resources.size(), 2, "resource references survive until scene setup")
	t.equal(progress, [0.5, 1.0], "progress advances once per retained resource")
	job.release()
	await root.process_frame
	t.ok(not is_instance_valid(job), "successful bank is released after transition")
	job = Preparation.new()
	host.add_child(job)
	t.ok(not await job.prepare(PackedStringArray(["res://missing-match-resource.gd"])), "missing resource rejects preparation")
	job.release()
	await root.process_frame
	t.ok(not is_instance_valid(job), "missing resource does not retain a job node")
	var delayed := DelayedPreparation.new()
	host.add_child(delayed)
	t.ok(not await delayed.prepare(simple_paths), "deadline returns failure without waiting for an unfinished worker")
	t.equal(delayed.retrieved, 0, "in-progress retrieval never blocks the UI")
	delayed.release()
	delayed._process(0.0)
	t.equal(delayed.retrieved, 0, "rollback does not retrieve an active worker")
	delayed.state = ResourceLoader.THREAD_LOAD_LOADED
	delayed._process(0.0)
	t.equal(delayed.retrieved, 1, "completed worker is drained after rollback")
	await root.process_frame
	t.ok(not is_instance_valid(delayed), "drained worker releases its node")
	var router := RefusingRouter.new()
	host.add_child(router)
	var previous := Control.new()
	previous.process_mode = Node.PROCESS_MODE_ALWAYS
	router.holder.add_child(previous)
	router.current_node = previous
	router.current_id = "settings"
	t.ok(not await router.go_to("match", {"config": simple}, true, 0.0), "preparation failure rejects transition")
	t.ok(router.saw_disabled, "previous screen does not keep simulating during preparation")
	t.ok(router.current_node == previous and not previous.is_queued_for_deletion(), "failure preserves previous screen")
	t.equal(previous.process_mode, Node.PROCESS_MODE_ALWAYS, "rollback restores the original process mode")
	t.equal(router.stack_depth(), 0, "failed preparation leaves navigation history unchanged")
	t.ok(not router._busy and not router.loading_progress.visible, "failed preparation unlocks and hides progress")
	t.equal(router.overlay.color.a, 0.0, "failed preparation restores visible screen")
	router.queue_free()
	await root.process_frame
	var successful := SuccessfulRouter.new()
	host.add_child(successful)
	t.ok(await successful.go_to("main_menu", {}, false, 0.0), "normal navigation still succeeds")
	t.ok(await successful.go_to("match", {"config": simple}, true, 0.0), "prepared route starts an actual match")
	t.ok(successful.retained_at_swap, "resources are retained while the scene is built")
	t.ok(successful.progress_at_swap, "loading progress remains visible until synchronous scene construction completes")
	t.ok(successful.current_node.ctx != null, "real match context is constructed")
	t.equal(successful.stack_depth(), 1, "successful match transition records history once")
	t.ok(not successful.loading_progress.visible, "successful route hides loading progress")
	await root.process_frame
	for child in successful.get_children():
		t.ok(not child.has_method("prepare"), "completed preparation job is removed")
	t.ok(await successful.go_to("main_menu", {}, false, 0.0), "prepared match cleans up when leaving")
	successful.queue_free()
	await root.process_frame
