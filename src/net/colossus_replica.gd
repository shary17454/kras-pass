extends Node3D
## Host-owned arm poses and carved ground; no guest damage or crater physics.

const Fields = preload("res://src/net/crate_replica.gd")
const Boss = preload("res://src/net/forge_replica.gd")
var warnings := {}
var craters := {}
var _initialized := false
var _round := -1
var _damage := 0
var _strike := 0
var _phase := 0
var _defeated := false


static func capture(game: Node) -> Dictionary:
	var warning_rows: Array = []
	for row in game._telegraphs:
		if is_instance_valid(row.node):
			warning_rows.append({"id": str(row.node.get_instance_id()), "position": Fields._vec(row.pos),
				"radius": row.radius, "left": row.left, "total": row.total})
	var crater_rows: Array = []
	for row in game._craters:
		if is_instance_valid(row.node):
			crater_rows.append({"id": str(row.node.get_instance_id()), "position": Fields._vec(row.pos), "radius": row.radius})
	return {"boss": Boss.capture_boss(game), "warnings": warning_rows, "craters": crater_rows,
		"arm_rotation": Boss._angles(game._arm.rotation), "fist_position": Fields._vec(game._fist.global_position),
		"fist_scale": Fields._vec(game._fist.scale), "exposed": maxf(0.0, game._exposed)}


static func valid(world: Variant, count: int) -> bool:
	if count < 2 or count > 4 or not world is Dictionary or world.size() != 7 \
		or not Boss.valid_boss(world.get("boss"), 800.0, [0.66, 0.33]) \
		or not Boss._valid_angles(world.get("arm_rotation")) \
		or not Fields._vector(world.get("fist_position")) or not Fields._vector(world.get("fist_scale")) \
		or not Fields.Number._number(world.get("exposed")) or world.exposed < 0.0 or world.exposed > 2.4:
		return false
	for component in world.fist_scale:
		if component < 0.8 or component > 1.2: return false
	for group in ["warnings", "craters"]:
		if not world.get(group) is Array or world[group].size() > 64: return false
	var ids := {}
	for row in world.warnings:
		if not Boss.valid_warning(row, ids): return false
	for row in world.craters:
		if not Boss._row(row, 3, ids) or not Fields.Number._number(row.get("radius")) \
			or row.radius < 0.75 or row.radius > 100.0: return false
	return true


func render(game: Node, world: Dictionary, round_index: int, feedback: bool) -> void:
	if not _initialized:
		var previous: WeakRef = game.get_meta("colossus_network_view") if game.has_meta("colossus_network_view") else null
		if previous != null and is_instance_valid(previous.get_ref()) and previous.get_ref() != self:
			previous.get_ref().hide()
			previous.get_ref().queue_free()
		game.set_meta("colossus_network_view", weakref(self))
		game.presentation_only = true
		game._clear_telegraphs()
		game._clear_shots()
		game._clear_craters()
		game.ctx.arena.enable_crater_floor()
		game.ctx.arena._crater_floor.use_presentation_only()
		_initialized = true
	var baseline := _round != round_index
	var boss: Dictionary = world.boss
	game.boss_health = float(boss.health)
	game.phase = int(boss.phase)
	game.boss_defeated = bool(boss.defeated)
	game.damage_sequence = int(boss.damage)
	game.strike_sequence = int(boss.strike)
	game.strike_position = _position(boss.strike_position)
	game.strike_radius = float(boss.strike_radius)
	game.boss_node.global_position = _position(boss.position)
	game.boss_node.rotation = _position(boss.rotation)
	game.boss_node.visible = not game.boss_defeated
	game._arm.rotation = _position(world.arm_rotation)
	game._fist.global_position = _position(world.fist_position)
	game._fist.scale = _position(world.fist_scale)
	game._exposed = float(world.exposed)
	Boss.render_warning_views(self, warnings, world.warnings, feedback and not baseline)
	var present := {}
	var holes: Array = []
	for row in world.craters:
		present[row.id] = true
		if craters.has(row.id) and not is_equal_approx(float(craters[row.id].get_meta("radius")), float(row.radius)):
			_remove(craters, row.id)
		if not craters.has(row.id):
			var view := MeshFactory.torus(float(row.radius) - 0.15, float(row.radius), Color("#161a2c"), 0.0)
			view.set_meta("radius", float(row.radius))
			add_child(view)
			craters[row.id] = view
		var position := _position(row.position)
		craters[row.id].global_position = position + Vector3.UP * 0.1
		var local: Vector3 = position - game.ctx.arena.global_position
		holes.append({"point": Vector2(local.x, local.z), "radius": float(row.radius)})
	for id in craters.keys():
		if not present.has(id): _remove(craters, id)
	game.ctx.arena._crater_floor.apply_snapshot(game.ctx.arena.current_radius, holes)
	if feedback and not baseline:
		if int(boss.damage) > _damage: AudioManager.play_sfx("hit", game.boss_node.global_position)
		if int(boss.phase) != _phase:
			AudioManager.play_sfx("powerup")
			EventBus.shake(0.5, 0.4)
		if int(boss.strike) > _strike:
			AudioManager.play_sfx("explode", game.strike_position)
			EventBus.shake(0.45, 0.3)
		if not _defeated and bool(boss.defeated):
			AudioManager.play_sfx("victory")
			EventBus.shake(0.9, 0.8)
	_damage = int(boss.damage)
	_strike = int(boss.strike)
	_phase = int(boss.phase)
	_defeated = bool(boss.defeated)
	_round = round_index


func _position(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])


func _remove(views: Dictionary, id: String) -> void:
	views[id].hide()
	views[id].queue_free()
	views.erase(id)
