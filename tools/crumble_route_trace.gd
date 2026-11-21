extends Node
## Development-only trace of natural tile survival; never changes match rules.


func _ready() -> void:
	if not _storage_is_isolated(SaveSystem.storage_root):
		push_error("Crumble trace requires an isolated --test-data-dir")
		get_tree().quit(2)
		return
	UserSettings.set_value("replay_capture", false)
	UserSettings.set_value("show_control_hints", false)
	var seed_value := 609001
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			seed_value = int(argument.trim_prefix("--seed="))
	var cfg := MatchConfig.build("crumble_court", ["nabta", "sakhra", "fanoos", "ramla"], 0, PlayerConfig.Difficulty.MEDIUM, seed_value)
	cfg.rounds = 1
	var scene = load("res://src/match/match_scene.gd").new()
	add_child(scene)
	var results := []
	scene.setup({"config": cfg, "on_finished": func(result): results.append(result)})
	for tick in 60 * 120:
		if not results.is_empty():
			break
		await get_tree().physics_frame
		if tick % 30 != 0:
			continue
		print("CRUMBLE_TRACE tick=", tick, " phase=", scene.phase)
		for slot in scene._brains.size():
			var brain = scene._brains[slot]
			var fighter: Fighter = scene.ctx.fighter(slot)
			var tile: ArenaTile = scene.arena.tile_at(fighter.global_position)
			var target: ArenaTile = brain._target_tile
			print("CRUMBLE_TRACE slot=", slot, " alive=", scene.ctx.is_alive(slot),
				" position=", fighter.global_position, " velocity=", fighter.velocity,
				" move=", brain.move, " floor=", fighter.is_on_floor(),
				" tile=", Vector2i(tile.grid_x, tile.grid_z) if tile != null else Vector2i(999, 999),
				" tile_state=", tile.state if tile != null else -1,
				" target=", Vector2i(target.grid_x, target.grid_z) if target != null else Vector2i(999, 999))
	if not results.is_empty():
		print("CRUMBLE_RESULT seed=", cfg.seed, " duration=", results[0].duration, " scores=", results[0].scores)
	scene.teardown()
	scene.queue_free()
	await get_tree().process_frame
	AudioManager.shutdown()
	await get_tree().process_frame
	get_tree().quit(0 if not results.is_empty() else 1)


func _storage_is_isolated(root: String) -> bool:
	if not root.is_absolute_path() or root.begins_with("user://") or root.begins_with("res://"):
		return false
	var directory := root.simplify_path().trim_suffix("/")
	var player_directory := OS.get_user_data_dir().simplify_path().trim_suffix("/")
	return not directory.is_empty() and not directory.ends_with(":") and directory != player_directory \
		and not directory.begins_with(player_directory + "/")
