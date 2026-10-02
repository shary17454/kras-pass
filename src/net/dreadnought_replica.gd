extends Node3D
## Host snapshots only: these meshes never run damage, physics or mine timers.

const Fields = preload("res://src/net/crate_replica.gd")
const Boss = preload("res://src/net/forge_replica.gd")
var warnings := {}
var mines := {}
var shots := {}
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
	var mines: Array = []
	for row in game._mines:
		if is_instance_valid(row.node):
			mines.append({"id": str(row.node.get_instance_id()), "position": Fields._vec(row.node.global_position), "armed": row.armed})
	var shots: Array = []
	for shot in game._shots:
		if is_instance_valid(shot) and shot.active:
			shots.append({"id": str(shot.get_instance_id()), "position": Fields._vec(shot.global_position), "direction": Fields._vec(shot.direction)})
	return {"boss": Boss.capture_boss(game), "warnings": warnings, "mines": mines, "shots": shots}


static func valid(world: Variant, count: int) -> bool:
	if count < 2 or count > 4 or not world is Dictionary or world.size() != 4 \
		or not Boss.valid_boss(world.get("boss"), 1100.0, [0.7, 0.35]):
		return false
	for group in ["warnings", "mines", "shots"]:
		if not world.get(group) is Array or world[group].size() > (96 if group == "mines" else 64):
			return false
	var ids := {}
	for row in world.warnings:
		if not Boss.valid_warning(row, ids): return false
	for row in world.mines:
		if not Boss._row(row, 3, ids) or not Fields.Number._number(row.get("armed")) or row.armed < 0.0 or row.armed > 1.0:
			return false
	for row in world.shots:
		if not Boss._row(row, 3, ids) or not Fields._vector(row.get("direction")):
			return false
		var direction := Vector3(row.direction[0], row.direction[1], row.direction[2])
		if absf(direction.length_squared() - 1.0) > 0.001: return false
	return true


func render(game: Node, world: Dictionary, round_index: int, feedback: bool) -> void:
	if not _initialized:
		var previous: WeakRef = game.get_meta("dreadnought_network_view") if game.has_meta("dreadnought_network_view") else null
		if previous != null and is_instance_valid(previous.get_ref()) and previous.get_ref() != self:
			previous.get_ref().hide()
			previous.get_ref().queue_free()
		game.set_meta("dreadnought_network_view", weakref(self))
		game.presentation_only = true
		game._clear_telegraphs()
		game._clear_shots()
		game._clear_mines()
		_initialized = true
	var baseline := _round != round_index
	var boss: Dictionary = world.boss
	game.boss_health = float(boss.health)
	game.phase = int(boss.phase)
	game.boss_defeated = bool(boss.defeated)
	game.damage_sequence = int(boss.damage)
	game.strike_sequence = int(boss.strike)
	game.strike_position = _position({"position": boss.strike_position})
	game.strike_radius = float(boss.strike_radius)
	game.boss_node.global_position = _position(boss)
	game.boss_node.rotation = Vector3(boss.rotation[0], boss.rotation[1], boss.rotation[2])
	game.boss_node.visible = not game.boss_defeated
	var present := {}
	for row in world.warnings:
		present[row.id] = true
		if warnings.has(row.id) and not is_equal_approx(float(warnings[row.id].get_meta("radius")), float(row.radius)):
			_remove(warnings, row.id)
		if not warnings.has(row.id):
			var view := MeshFactory.torus(float(row.radius) - 0.25, float(row.radius), Boss.COLOR, 1.8)
			view.set_meta("radius", float(row.radius))
			add_child(view)
			warnings[row.id] = view
			if feedback and not baseline: AudioManager.play_sfx("tick", _position(row), 0.7)
		warnings[row.id].global_position = _position(row) + Vector3(0, 0.12, 0)
		var fill: float = 1.0 - clampf(float(row.left) / float(row.total), 0.0, 1.0)
		warnings[row.id].scale = Vector3(0.35 + 0.65 * fill, 1, 0.35 + 0.65 * fill)
	_prune(warnings, present)
	present.clear()
	for index in world.mines.size():
		var row: Dictionary = world.mines[index]
		present[row.id] = true
		if not mines.has(row.id):
			var view := MeshFactory.cylinder(0.7, 0.35, Boss.COLOR, 1.4)
			add_child(view)
			mines[row.id] = view
		mines[row.id].global_position = _position(row)
		mines[row.id].scale.y = 1.0 + 0.3 * sin(float(row.armed) * 8.0 + index)
	_prune(mines, present)
	present.clear()
	for row in world.shots:
		present[row.id] = true
		if not shots.has(row.id):
			var view := Node3D.new()
			view.add_child(MeshFactory.sphere(0.26, Boss.COLOR, 2.0))
			var tail := MeshFactory.box(Vector3(0.16, 0.16, 0.9), Boss.COLOR, 1.4)
			tail.position.z = 0.5
			view.add_child(tail)
			add_child(view)
			shots[row.id] = view
			if feedback and not baseline: AudioManager.play_sfx("shoot", _position(row))
		shots[row.id].global_position = _position(row)
		var direction := Vector3(row.direction[0], row.direction[1], row.direction[2])
		shots[row.id].look_at(_position(row) + direction, Vector3.RIGHT if absf(direction.y) > 0.99 else Vector3.UP)
	_prune(shots, present)
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
	var burst := MeshFactory.burst(Boss.COLOR, count, radius)
	add_child(burst)
	burst.global_position = position
