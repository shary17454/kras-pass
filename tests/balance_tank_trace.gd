extends "res://tests/balance_pair_sim.gd"
## Passive damage/elimination snapshots. Never publishes inputs or advances RNG.

var _match_index := 0
var _eliminations: Array[Dictionary] = []
var _seen_slots := {}
var _player_count := 0
var _hits: Array[Dictionary] = []
var _observed_controllers: Array[WeakRef] = []
var _physics_start := 0


func _parse_args(arguments: PackedStringArray) -> bool:
	return super._parse_args(arguments) and only == "tank_arena"


func _begin_ledger(count: int) -> void:
	_disconnect_controllers()
	_player_count = count
	_eliminations.clear()
	_seen_slots.clear()
	_hits.clear()
	_physics_start = Engine.get_physics_frames()


func _play(cfg: MatchConfig) -> MatchResult:
	_begin_ledger(cfg.players.size())
	EventBus.player_eliminated.connect(_record_elimination)
	get_tree().node_added.connect(_observe_controller)
	var result: MatchResult = await super._play(cfg)
	get_tree().node_added.disconnect(_observe_controller)
	_disconnect_controllers()
	EventBus.player_eliminated.disconnect(_record_elimination)
	var players: Array[Dictionary] = []
	for player in cfg.players:
		players.append(player.to_dict())
	var row := {"match_index": _match_index, "seed": cfg.seed,
		"arena_id": cfg.arena_id, "players": players,
		"hits": _hits.duplicate(true),
		"eliminations": _eliminations.duplicate(true), "completed": result != null}
	if result != null:
		row["scores"] = result.scores.duplicate()
		row["places"] = result.places.duplicate()
		row["details"] = result.details.duplicate(true)
	var path := SaveSystem.storage_root.path_join("tank-trace.jsonl")
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE
	var file := FileAccess.open(path, mode)
	if file == null:
		push_error("Cannot write tank diagnostic trace")
		return null
	file.seek_end()
	file.store_line(JSON.stringify(row))
	file.close()
	_match_index += 1
	return result


func _observe_controller(node: Node) -> void:
	var script: Script = node.get_script()
	if script == null or script.resource_path != "res://src/minigames/tank_arena.gd":
		return
	var callback := _record_damage.bind(node)
	if not node.is_connected("armor_damaged", callback):
		node.connect("armor_damaged", callback)
		_observed_controllers.append(weakref(node))


func _disconnect_controllers() -> void:
	for reference in _observed_controllers:
		var node: Node = reference.get_ref()
		if is_instance_valid(node):
			var callback := _record_damage.bind(node)
			if node.is_connected("armor_damaged", callback):
				node.disconnect("armor_damaged", callback)
	_observed_controllers.clear()


func _record_damage(shooter: int, victim: int, damage: int, armor_left: int, controller: Node) -> void:
	var context: MatchContext = controller.ctx
	if context == null or shooter < 0 or shooter >= _player_count \
			or victim < 0 or victim >= _player_count or shooter == victim:
		return
	var bodies: Array[Dictionary] = []
	for slot in [shooter, victim]:
		var body := context.fighter(slot)
		if not is_instance_valid(body):
			return
		var position := body.global_position
		var velocity := body.velocity
		bodies.append({"slot": slot, "position": [position.x, position.y, position.z],
			"velocity": [velocity.x, velocity.y, velocity.z]})
	_hits.append({"shooter": shooter, "victim": victim, "damage": damage,
		"armor_left": armor_left, "round": context.round_index,
		"time_left": context.time_left, "physics_tick": Engine.get_physics_frames() - _physics_start,
		"bodies": bodies})


func _record_elimination(slot: int, place: int) -> void:
	for child in get_children():
		var script: Script = child.get_script()
		if script == null or script.resource_path != "res://src/match/match_scene.gd":
			continue
		var context: MatchContext = child.ctx
		var controller: Node = child.controller
		if context == null or not is_instance_valid(controller):
			return
		var bodies: Array[Dictionary] = []
		for index in context.player_count():
			var body := context.fighter(index)
			if not is_instance_valid(body):
				bodies.append({"slot": index, "missing": true})
				continue
			var position := body.global_position
			var velocity := body.velocity
			bodies.append({"slot": index, "alive": context.is_alive(index),
				"position": [position.x, position.y, position.z],
				"velocity": [velocity.x, velocity.y, velocity.z],
				"edge_distance": child.arena.edge_distance(position)})
		_append_elimination(slot, place, {"elapsed": child._round_elapsed,
			"armor": controller.armor.duplicate(), "ammo": controller.ammo.duplicate(),
			"shell_types": controller.shell_types.duplicate(),
			"order": context.elimination_order.duplicate(), "bodies": bodies})
		return


func _append_elimination(slot: int, place: int, state: Dictionary) -> bool:
	if slot < 0 or slot >= _player_count or place < 1 or place > _player_count \
			or _seen_slots.has(slot):
		return false
	var snapshot := state.duplicate(true)
	snapshot["slot"] = slot
	snapshot["place"] = place
	_eliminations.append(snapshot)
	_seen_slots[slot] = true
	return true
