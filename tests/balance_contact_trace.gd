extends "res://tests/balance_pair_sim.gd"
## Observational Duel diagnostic; callbacks never feed back into simulation.

var _match_index := 0
var _hits: Array[Dictionary] = []
var _respawns: Array[int] = []


func _parse_args(arguments: PackedStringArray) -> bool:
	return super._parse_args(arguments) and only == "duel_pit"


func _play(cfg: MatchConfig) -> MatchResult:
	_hits.clear()
	_respawns.clear()
	for player in cfg.players:
		_hits.append({"delivered": 0, "received": 0, "zero_strength": 0,
			"push_delivered": 0.0, "push_received": 0.0, "max_push_received": 0.0})
		_respawns.append(0)
	EventBus.player_hit.connect(_record_hit)
	EventBus.player_respawned.connect(_record_respawn)
	var result: MatchResult = await super._play(cfg)
	EventBus.player_hit.disconnect(_record_hit)
	EventBus.player_respawned.disconnect(_record_respawn)
	var players: Array[Dictionary] = []
	for player in cfg.players:
		players.append(player.to_dict())
	var row := {"match_index": _match_index, "seed": cfg.seed,
		"players": players, "hits": _hits.duplicate(true),
		"respawn_events": _respawns.duplicate(), "completed": result != null}
	if result != null:
		row["scores"] = result.scores.duplicate()
		row["places"] = result.places.duplicate()
		row["details"] = result.details.duplicate(true)
	var path := SaveSystem.storage_root.path_join("contact-trace.jsonl")
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE
	var file := FileAccess.open(path, mode)
	if file == null:
		push_error("Cannot write contact diagnostic trace")
		return null
	file.seek_end()
	file.store_line(JSON.stringify(row))
	file.close()
	_match_index += 1
	return result


func _record_hit(attacker: int, victim: int, strength: float) -> void:
	if victim < 0 or victim >= _hits.size():
		return
	var received: Dictionary = _hits[victim]
	received["received"] += 1
	received["push_received"] += strength
	received["max_push_received"] = maxf(received["max_push_received"], strength)
	if is_zero_approx(strength):
		received["zero_strength"] += 1
	if attacker >= 0 and attacker < _hits.size():
		_hits[attacker]["delivered"] += 1
		_hits[attacker]["push_delivered"] += strength


func _record_respawn(slot: int) -> void:
	if slot >= 0 and slot < _respawns.size():
		_respawns[slot] += 1
