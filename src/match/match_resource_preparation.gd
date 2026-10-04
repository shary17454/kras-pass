extends Node
## One transition's retained resource bank, not a permanent cache of every map.
## Geometry construction and GPU pipeline compilation still run in the scene.

const NATURAL := "res://assets/natural/"
const ARENAS := "res://src/arenas/"
const MAX_WAIT_MSEC := 30000

var resources: Array[Resource] = []
var error_path := ""
var _pending_path := ""
var _preparing := false
var _released := false


static func paths_for(config: MatchConfig) -> PackedStringArray:
	if config == null or config.definition() == null:
		return []
	var definition := config.definition()
	var arena := Registry.arena(config.arena_id)
	if arena == null and not definition.arena_ids.is_empty():
		arena = Registry.arena(definition.arena_ids[0])
	if arena == null:
		return []
	return paths_for_definitions(definition, arena)


static func paths_for_definitions(definition: MiniGameDef, arena: ArenaDef) -> PackedStringArray:
	if definition == null or arena == null:
		return []
	var paths := PackedStringArray(["res://src/match/match_scene.gd", definition.controller_script])
	paths.append_array(definition.preload_resources)
	paths.append_array(arena.preload_resources)
	var scenery := Arena.scenery_script(arena)
	var natural := not scenery.is_empty() or definition.controller_script == "res://src/minigames/tank_arena.gd"
	if natural:
		paths.append_array(PackedStringArray([
			NATURAL + "rock_moss_set_01/rock_moss_set_01_2k.gltf",
			NATURAL + "pine_mobile.glb", NATURAL + "fern_02/fern_02_1k.gltf",
			ARENAS + "valley_terrain.gdshader", ARENAS + "valley_water.gdshader"]))
		for surface in ["gravel_floor", "forrest_ground_01", "aerial_rocks_01"]:
			for map in ["diff", "nor_gl", "rough"]:
				paths.append(NATURAL + "%s/%s_%s_2k.jpg" % [surface, surface, map])
	if definition.controller_script == "res://src/minigames/tank_arena.gd":
		paths.append_array(PackedStringArray([ARENAS + "tank_world.gd", ARENAS + "battlefield_terrain.gdshader"]))
	if not scenery.is_empty():
		paths.append_array(PackedStringArray([scenery, ARENAS + "racing_routes.gd",
			ARENAS + "race_structures.gd", ARENAS + "racing_asphalt.gdshader", ARENAS + "racing_lava.gdshader"]))
		if arena.id in ["frost_hairpin", "magma_ring", "neon_spiral", "alula_rain"]:
			paths.append_array(PackedStringArray([ARENAS + "racing_weather.gd", ARENAS + "racing_precipitation.gdshader"]))
		if arena.id == "sky_causeway":
			paths.append_array(PackedStringArray([ARENAS + "forest_life.gd", ARENAS + "forest_animal.gd", ARENAS + "forest_waterfall.gdshader"]))
		if arena.id == "alula_rain":
			paths.append_array(PackedStringArray([ARENAS + "alula_clouds.gdshader", ARENAS + "alula_sandstone.gdshader",
				NATURAL + "rock_moss_set_01/textures/rock_moss_set_01_diff_2k.jpg",
				NATURAL + "rock_moss_set_01/textures/rock_moss_set_01_nor_gl_2k.jpg"]))
	var unique := PackedStringArray()
	for path in paths:
		if not unique.has(path):
			unique.append(path)
	return unique


func prepare(paths: PackedStringArray, progress: Callable = Callable()) -> bool:
	if _released or _preparing:
		return false
	_preparing = true
	var loaded := await _prepare_paths(paths, progress)
	_preparing = false
	if _released:
		release()
	return loaded and not _released


func _prepare_paths(paths: PackedStringArray, progress: Callable) -> bool:
	set_process(false)
	var started := Time.get_ticks_msec()
	for i in paths.size():
		if _released:
			return false
		var path := paths[i]
		if not path.begins_with("res://") or not ResourceLoader.exists(path) or _request(path) != OK:
			error_path = path
			return false
		_pending_path = path
		# Never retrieve an in-progress resource: that would block the UI thread.
		while _status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if _released:
				return false
			if Time.get_ticks_msec() - started >= _wait_limit():
				error_path = path
				return false
			await get_tree().process_frame
		if _released:
			return false
		if _status(path) != ResourceLoader.THREAD_LOAD_LOADED:
			error_path = path
			return false
		var resource := _take(path)
		_pending_path = ""
		if resource == null:
			error_path = path
			return false
		resources.append(resource)
		if progress.is_valid():
			progress.call(float(i + 1) / paths.size())
		# Yield even for cache hits, keeping the transition UI responsive.
		await get_tree().process_frame
	return not _released


func release() -> void:
	_released = true
	resources.clear()
	if _preparing:
		# The coroutine exits at its next frame boundary, then drains the one
		# outstanding native request. Never free it while it is still awaiting.
		return
	if _pending_path.is_empty():
		queue_free()
	else:
		# Godot cannot cancel a threaded request. Drain it after UI rollback,
		# without retrieving it while the loading thread is still running.
		set_process(true)


func _process(_delta: float) -> void:
	if _preparing:
		return
	if _pending_path.is_empty() or _status(_pending_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	_take(_pending_path)
	_pending_path = ""
	queue_free()


func _request(path: String) -> Error:
	return ResourceLoader.load_threaded_request(path)


func _status(path: String) -> int:
	return ResourceLoader.load_threaded_get_status(path)


func _take(path: String) -> Resource:
	return ResourceLoader.load_threaded_get(path)


func _wait_limit() -> int:
	return MAX_WAIT_MSEC
