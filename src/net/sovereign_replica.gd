extends Node3D
## Snapshot-owned views; no guest orb physics, shield rules or damage callbacks.

const Fields = preload("res://src/net/crate_replica.gd")
const Boss = preload("res://src/net/forge_replica.gd")
var warnings := {}
var orbs := {}
var shield: MeshInstance3D
var _initialized := false
var _round := -1
var _damage := 0
var _strike := 0
var _phase := 0
var _defeated := false
var _shielded := false


static func capture(game: Node) -> Dictionary:
	var warnings: Array = []
	for row in game._telegraphs:
		if is_instance_valid(row.node):
			warnings.append({"id": str(row.node.get_instance_id()), "position": Fields._vec(row.pos),
				"radius": row.radius, "left": row.left, "total": row.total})
	var orbs: Array = []
	for row in game._orbs:
		if is_instance_valid(row.node):
			orbs.append({"id": str(row.node.get_instance_id()), "position": Fields._vec(row.node.global_position),
				"returned": row.returned})
	return {"boss": Boss.capture_boss(game), "warnings": warnings, "orbs": orbs,
		"shielded": game._shielded, "recovery": maxf(0.0, game._recover)}


static func valid(world: Variant, count: int) -> bool:
	if count < 2 or count > 4 or not world is Dictionary or world.size() != 5 \
		or not Boss.valid_boss(world.get("boss"), 1500.0, [0.66, 0.30]) \
		or not world.get("shielded") is bool \
		or (world.shielded and int(world.boss.phase) != 1) \
		or not Fields.Number._number(world.get("recovery")) or world.recovery < 0.0 or world.recovery > 2.8 \
		or not world.get("warnings") is Array or world.warnings.size() > 64 \
		or not world.get("orbs") is Array or world.orbs.size() > 32:
		return false
	var ids := {}
	for row in world.warnings:
		if not Boss.valid_warning(row, ids): return false
	for row in world.orbs:
		if not Boss._row(row, 3, ids) or not row.get("returned") is bool: return false
	return true


func render(game: Node, world: Dictionary, round_index: int, feedback: bool) -> void:
	if not _initialized:
		var previous: WeakRef = game.get_meta("sovereign_network_view") if game.has_meta("sovereign_network_view") else null
		if previous != null and is_instance_valid(previous.get_ref()) and previous.get_ref() != self:
			previous.get_ref().hide()
			previous.get_ref().queue_free()
		game.set_meta("sovereign_network_view", weakref(self))
		game.presentation_only = true
		game._clear_telegraphs()
		game._clear_shots()
		game._clear_orbs()
		if is_instance_valid(game._shield): game._shield.hide()
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
	game._shielded = bool(world.shielded)
	game._recover = float(world.recovery)
	if is_instance_valid(game._core):
		game._core.scale = Vector3.ONE * (1.0 + 0.08 * sin(float(Time.get_ticks_msec()) * 0.004))
	if not is_instance_valid(shield):
		shield = MeshFactory.sphere(3.6, Color("#5ad6a0"), 0.9)
		shield.material_override = MeshFactory.transparent(Color("#5ad6a0"), 0.32)
		add_child(shield)
	shield.global_position = game.boss_node.global_position + Vector3(0, 2.6, 0)
	shield.visible = game._shielded and not game.boss_defeated
	Boss.render_warning_views(self, warnings, world.warnings, feedback and not baseline)
	var present := {}
	for row in world.orbs:
		present[row.id] = true
		if not orbs.has(row.id):
			var view := MeshFactory.sphere(0.7, Color("#ffd166"), 2.4)
			add_child(view)
			orbs[row.id] = view
			if feedback and not baseline: AudioManager.play_sfx("shoot", _position(row))
		elif feedback and not baseline and bool(row.returned) and not bool(orbs[row.id].get_meta("returned", false)):
			AudioManager.play_sfx("hit", _position(row), 1.3)
		orbs[row.id].set_meta("returned", bool(row.returned))
		orbs[row.id].global_position = _position(row)
	for id in orbs.keys():
		if not present.has(id):
			orbs[id].hide()
			orbs[id].queue_free()
			orbs.erase(id)
	if feedback and not baseline:
		if int(boss.damage) > _damage: AudioManager.play_sfx("hit", game.boss_node.global_position)
		if int(boss.phase) != _phase: AudioManager.play_sfx("powerup")
		if bool(world.shielded) != _shielded: AudioManager.play_sfx("shield_break", game.boss_node.global_position)
		if int(boss.strike) > _strike:
			AudioManager.play_sfx("explode", game.strike_position)
			EventBus.shake(0.45, 0.3)
			_burst(game.strike_position, 16, game.strike_radius)
		if not _defeated and bool(boss.defeated):
			AudioManager.play_sfx("victory")
			_burst(game.boss_node.global_position, 30, 5.0)
	_damage = int(boss.damage)
	_strike = int(boss.strike)
	_phase = int(boss.phase)
	_defeated = bool(boss.defeated)
	_shielded = bool(world.shielded)
	_round = round_index


func _position(row: Dictionary) -> Vector3:
	return Vector3(row.position[0], row.position[1], row.position[2])


func _burst(position: Vector3, count: int, radius: float) -> void:
	if DisplayServer.get_name() == "headless": return
	var burst := MeshFactory.burst(Boss.COLOR, count, radius)
	add_child(burst)
	burst.global_position = position
