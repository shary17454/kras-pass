extends RefCounted
## Camera-only terrain treatment. Collision and AI sight queries are untouched.

const TAG := &"camera_occlusion_mesh"
const INTERVAL := 0.1
const MAX_TARGETS := 4
const MAX_HITS_PER_RAY := 6
const MAX_CACHE := 64
const SAMPLE_HEIGHTS := [0.6, 1.5]

var _elapsed := INTERVAL
var _arena: Arena
var _cache := {}
var queries_last_sample := 0
var targets_last_sample := 0
var samples := 0
var copies_created := 0
var peak_cache := 0
var peak_queries := 0
var last_sample_usec := 0
var skipped_non_physics := 0


func update(camera: Camera3D, arena: Arena, targets: Array, delta: float) -> void:
	# Direct space access is only safe inside the physics callback, including
	# projects that later enable a separate physics-server thread.
	if not Engine.is_in_physics_frame():
		skipped_non_physics += 1
		return
	if arena != _arena:
		clear()
		_arena = arena
	var alpha := alpha_for(arena.def) if is_instance_valid(arena) and arena.def != null else 0.0
	if alpha <= 0.0 or not is_finite(alpha):
		clear()
		return
	_elapsed += maxf(0.0, delta)
	if _elapsed < INTERVAL:
		return
	# No catch-up bursts after a slow frame or pause.
	_elapsed = 0.0
	queries_last_sample = 0
	targets_last_sample = 0
	samples += 1
	var started := Time.get_ticks_usec()
	var occluded := {}
	for index in mini(targets.size(), MAX_TARGETS):
		targets_last_sample += 1
		var target := targets[index] as Fighter
		if not is_instance_valid(target) or not target.alive:
			continue
		var origin: Vector3 = target.global_position
		for height in SAMPLE_HEIGHTS:
			var point: Vector3 = origin + Vector3.UP * float(height)
			if camera.is_position_behind(point):
				continue
			_trace(camera, arena, point, occluded)
	_apply(occluded, clampf(alpha, 0.08, 0.35))
	peak_queries = maxi(peak_queries, queries_last_sample)
	last_sample_usec = Time.get_ticks_usec() - started


func _trace(camera: Camera3D, arena: Arena, point: Vector3, occluded: Dictionary) -> void:
	var origin := camera.global_position + camera.global_basis.x * camera.h_offset + camera.global_basis.y * camera.v_offset
	if origin.distance_squared_to(point) < 0.0001:
		return
	var query := PhysicsRayQueryParameters3D.create(origin, point, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_back_faces = true
	query.hit_from_inside = true
	for attempt in MAX_HITS_PER_RAY:
		queries_last_sample += 1
		var hit := _intersect_ray(camera, query)
		if hit.is_empty():
			break
		var body := hit.get("collider") as CollisionObject3D
		if not is_instance_valid(body) or not arena.is_ancestor_of(body) or not body.has_meta(TAG):
			break
		var mesh := body.get_node_or_null(NodePath(body.get_meta(TAG))) as MeshInstance3D
		if not is_instance_valid(mesh) or not body.is_ancestor_of(mesh) or not mesh.is_visible_in_tree() \
				or mesh.layers & camera.cull_mask == 0:
			break
		occluded[mesh.get_instance_id()] = mesh
		var excluded := query.exclude
		excluded.append(body.get_rid())
		query.exclude = excluded


func _intersect_ray(camera: Camera3D, query: PhysicsRayQueryParameters3D) -> Dictionary:
	return camera.get_world_3d().direct_space_state.intersect_ray(query)


static func alpha_for(definition: ArenaDef) -> float:
	# Do not edit arenas.json: its bytes identify saved playlists/daily records.
	return definition.param("camera_occluder_alpha", 0.12 if definition.id == "duel_pit" else 0.0)


func _apply(occluded: Dictionary, alpha: float) -> void:
	for id in _cache.keys():
		var entry: Dictionary = _cache[id]
		var mesh := entry.mesh.get_ref() as MeshInstance3D
		if not is_instance_valid(mesh):
			_cache.erase(id)
		elif not occluded.has(id):
			_restore(entry)
	for id in occluded:
		var mesh: MeshInstance3D = occluded[id]
		if not _cache.has(id):
			if _cache.size() >= MAX_CACHE or mesh.mesh == null or mesh.material_overlay != null:
				continue
			var original := mesh.material_override
			var source := original as StandardMaterial3D
			if source == null and original == null and mesh.mesh.get_surface_count() == 1:
				source = mesh.get_active_material(0) as StandardMaterial3D
			# Do not replace unknown shaders, multipass art or pre-transparent cues.
			if source == null or source.next_pass != null or source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
					or source.albedo_color.a <= 0.0:
				continue
			var faded := source.duplicate() as StandardMaterial3D
			faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_cache[id] = {"mesh": weakref(mesh), "original": original, "faded": faded,
				"source_alpha": source.albedo_color.a, "active": false}
			copies_created += 1
			peak_cache = maxi(peak_cache, _cache.size())
		var entry: Dictionary = _cache[id]
		var faded: StandardMaterial3D = entry.faded
		# Positive alpha preserves AIBrain's existing opaque-cue classification.
		var wanted_alpha := float(entry.source_alpha) * alpha
		if faded.albedo_color.a != wanted_alpha:
			faded.albedo_color.a = wanted_alpha
		if mesh.material_override != faded:
			mesh.material_override = faded
		entry.active = true


func _restore(entry: Dictionary) -> void:
	var mesh := entry.mesh.get_ref() as MeshInstance3D
	if is_instance_valid(mesh) and bool(entry.active):
		# Do not overwrite another visual owner's replacement material.
		if mesh.material_override == entry.faded:
			mesh.material_override = entry.original
		entry.active = false


func clear() -> void:
	for entry in _cache.values():
		_restore(entry)
	_cache.clear()
	_arena = null
	_elapsed = INTERVAL
	queries_last_sample = 0
	targets_last_sample = 0


func diagnostics() -> Dictionary:
	var active := 0
	for entry in _cache.values():
		if bool(entry.active):
			active += 1
	return {"cached": _cache.size(), "active": active, "queries": queries_last_sample, "samples": samples,
		"targets_scanned": targets_last_sample,
		"copies_created": copies_created, "peak_cache": peak_cache, "peak_queries": peak_queries,
		"last_sample_usec": last_sample_usec}
