extends Node3D
## Host-owned boss and world views. No guest bodies, timers or callbacks.

const Fields = preload("res://src/net/crate_replica.gd")
const COLOR := Color("#ff5f8d")
var warnings := {}
var crates := {}
var slag := {}
var _initialized := false
var _round := -1
var _damage := 0
var _strike := 0
var _phase := 0
var _defeated := false


static func capture(game: Node) -> Dictionary:
	var warnings: Array = []
	for row in game._telegraphs:
		if is_instance_valid(row.node):
			warnings.append({"id": str(row.node.get_instance_id()), "position": Fields._vec(row.pos),
				"radius": row.radius, "left": row.left, "total": row.total})
	var crates: Array = []
	for node in game._crates:
		if is_instance_valid(node):
			crates.append({"id": str(node.get_instance_id()), "position": Fields._vec(node.global_position)})
	var slag: Array = []
	for row in game._slag:
		if is_instance_valid(row.node):
			slag.append({"id": str(row.node.get_instance_id()), "position": Fields._vec(row.node.global_position),
				"life": row.life, "by": row.by})
	return {"boss": capture_boss(game),
		"intake": _angles(game._intake.rotation), "warnings": warnings, "crates": crates, "slag": slag}


static func capture_boss(game: Node) -> Dictionary:
	return {"health": game.boss_health, "phase": game.phase, "defeated": game.boss_defeated,
		"position": Fields._vec(game.boss_node.global_position), "rotation": _angles(game.boss_node.rotation),
		"damage": game.damage_sequence, "strike": game.strike_sequence,
		"strike_position": Fields._vec(game.strike_position), "strike_radius": game.strike_radius}


static func _angles(value: Vector3) -> Array:
	return [wrapf(value.x, -PI, PI), wrapf(value.y, -PI, PI), wrapf(value.z, -PI, PI)]


static func valid(world: Variant, count: int) -> bool:
	if count < 2 or count > 4 or not world is Dictionary or world.size() != 5 \
		or not world.get("boss") is Dictionary or world.boss.size() != 9:
		return false
	if not valid_boss(world.boss, 900.0, [0.66, 0.33]) or not _valid_angles(world.get("intake")):
		return false
	if not world.get("warnings") is Array or world.warnings.size() > 64 \
		or not world.get("crates") is Array or world.crates.size() > 96 \
		or not world.get("slag") is Array or world.slag.size() > 96:
		return false
	var ids := {}
	for row in world.warnings:
		if not valid_warning(row, ids): return false
	for row in world.crates:
		if not _row(row, 2, ids): return false
	for row in world.slag:
		if not _row(row, 4, ids) or not Fields.Number._number(row.get("life")) \
			or row.life <= 0.0 or row.life > 6.0 or not Fields._integer(row.get("by"), 0, count - 1):
			return false
	return true


static func valid_boss(boss: Variant, maximum: float, thresholds: Array) -> bool:
	if not boss is Dictionary or boss.size() != 9:
		return false
	if not Fields.Number._number(boss.get("health")) or boss.health < 0.0 or boss.health > maximum \
		or not Fields._integer(boss.get("phase"), 0, 2) or not boss.get("defeated") is bool \
		or bool(boss.defeated) != (float(boss.health) == 0.0) \
		or not Fields._vector(boss.get("position")) or not _valid_angles(boss.get("rotation")) \
		or not Fields._integer(boss.get("damage"), 0, 1000000) \
		or not Fields._integer(boss.get("strike"), 0, 1000000) or not Fields._vector(boss.get("strike_position")) \
		or not Fields.Number._number(boss.get("strike_radius")) or boss.strike_radius < 0.0 or boss.strike_radius > 100.0:
		return false
	var wanted := 0
	for threshold in thresholds:
		if float(boss.health) / maximum <= float(threshold): wanted += 1
	return int(boss.phase) == wanted


static func valid_warning(row: Variant, ids: Dictionary) -> bool:
	return _row(row, 5, ids) and Fields.Number._number(row.get("radius")) \
		and row.radius >= 0.25 and row.radius <= 100.0 and Fields.Number._number(row.get("left")) \
		and Fields.Number._number(row.get("total")) and row.total > 0.0 and row.total <= 60.0 \
		and row.left >= 0.0 and row.left <= row.total


static func render_warning_views(parent: Node3D, views: Dictionary, rows: Array, feedback: bool) -> void:
	var present := {}
	for row in rows:
		present[row.id] = true
		if views.has(row.id) and not is_equal_approx(float(views[row.id].get_meta("radius")), float(row.radius)):
			views[row.id].hide()
			views[row.id].queue_free()
			views.erase(row.id)
		if not views.has(row.id):
			var view := MeshFactory.torus(float(row.radius) - 0.25, float(row.radius), COLOR, 1.8)
			view.set_meta("radius", float(row.radius))
			parent.add_child(view)
			views[row.id] = view
			if feedback: AudioManager.play_sfx("tick", Vector3(row.position[0], row.position[1], row.position[2]), 0.7)
		views[row.id].global_position = Vector3(row.position[0], row.position[1], row.position[2]) + Vector3(0, 0.12, 0)
		var fill: float = 1.0 - clampf(float(row.left) / float(row.total), 0.0, 1.0)
		views[row.id].scale = Vector3(0.35 + 0.65 * fill, 1, 0.35 + 0.65 * fill)
	for id in views.keys():
		if not present.has(id):
			views[id].hide()
			views[id].queue_free()
			views.erase(id)


static func _row(row: Variant, size: int, ids: Dictionary) -> bool:
	return row is Dictionary and row.size() == size and Fields._id(row.get("id"), ids) and Fields._vector(row.get("position"))


static func _valid_angles(value: Variant) -> bool:
	return Fields._vector(value) and value.all(func(component): return absf(component) <= PI)


func render(game: Node, world: Dictionary, round_index: int, feedback: bool) -> void:
	if not _initialized:
		var previous: WeakRef = game.get_meta("forge_network_view") if game.has_meta("forge_network_view") else null
		if previous != null and is_instance_valid(previous.get_ref()) and previous.get_ref() != self:
			previous.get_ref().hide()
			previous.get_ref().queue_free()
		game.set_meta("forge_network_view", weakref(self))
		game.presentation_only = true
		game._clear_telegraphs()
		game._clear_shots()
		game._clear_forge_objects()
		_initialized = true
	var baseline := _round != round_index
	var boss: Dictionary = world.boss
	game.boss_health = float(boss.health)
	game.phase = int(boss.phase)
	game.boss_defeated = bool(boss.defeated)
	game.damage_sequence = int(boss.damage)
	game.strike_sequence = int(boss.strike)
	game.strike_position = Vector3(boss.strike_position[0], boss.strike_position[1], boss.strike_position[2])
	game.strike_radius = float(boss.strike_radius)
	game.boss_node.global_position = Vector3(boss.position[0], boss.position[1], boss.position[2])
	game.boss_node.rotation = Vector3(boss.rotation[0], boss.rotation[1], boss.rotation[2])
	game.boss_node.visible = not game.boss_defeated
	game._intake.rotation = Vector3(world.intake[0], world.intake[1], world.intake[2])
	render_warning_views(self, warnings, world.warnings, feedback and not baseline)
	var present := {}
	for row in world.crates:
		present[row.id] = true
		if not crates.has(row.id):
			var view := MeshFactory.crate(1.4, Color("#7d6a55"), Color("#ff8a3d"))
			add_child(view)
			crates[row.id] = view
			if feedback and not baseline: AudioManager.play_sfx("crate_break", _position(row), 0.7)
		crates[row.id].global_position = _position(row)
	_prune(crates, present)
	present.clear()
	for row in world.slag:
		present[row.id] = true
		if not slag.has(row.id):
			var view := MeshFactory.sphere(0.6, Color("#ff8a3d"), 2.6)
			add_child(view)
			slag[row.id] = view
			if feedback and not baseline: AudioManager.play_sfx("crate_break", _position(row))
		slag[row.id].global_position = _position(row)
		slag[row.id].scale = Vector3.ONE * (0.5 + 0.5 * float(row.life) / 6.0)
	_prune(slag, present)
	if feedback and not baseline:
		if int(boss.damage) > _damage: AudioManager.play_sfx("hit", game.boss_node.global_position)
		if int(boss.phase) != _phase:
			AudioManager.play_sfx("powerup")
			EventBus.shake(0.5, 0.4)
		if int(boss.strike) > _strike:
			AudioManager.play_sfx("explode", game.strike_position)
			EventBus.shake(0.45, 0.3)
			_burst(game.strike_position, 16, game.strike_radius)
		if not _defeated and bool(boss.defeated):
			AudioManager.play_sfx("victory")
			EventBus.shake(0.9, 0.8)
			_burst(game.boss_node.global_position, 30, 5.0)
	_damage = int(boss.damage)
	_strike = int(boss.strike)
	_phase = int(boss.phase)
	_defeated = bool(boss.defeated)
	_round = round_index


func _position(row: Dictionary) -> Vector3:
	return Vector3(row.position[0], row.position[1], row.position[2])


func _prune(views: Dictionary, present: Dictionary) -> void:
	for id in views.keys():
		if not present.has(id): _remove(views, id)


func _remove(views: Dictionary, id: String) -> void:
	views[id].hide()
	views[id].queue_free()
	views.erase(id)


func _burst(position: Vector3, count: int, radius: float) -> void:
	if DisplayServer.get_name() == "headless": return
	var burst := MeshFactory.burst(COLOR, count, radius)
	add_child(burst)
	burst.global_position = position
