extends "res://tools/balance_sim.gd"
## Development-only observation of accepted contact feedback; never changes play.

var _probe_config: MatchConfig
var _contacts: Array[Dictionary] = []
var _invalid_contacts := 0
var _contact_file: FileAccess


func _begin_probe(cfg: MatchConfig) -> void:
	_probe_config = cfg
	_invalid_contacts = 0
	_contacts.clear()
	for player in cfg.players:
		_contacts.append({"character": player.character_id,
			"environment_hits": 0, "player_hits": 0, "blocked_feedback": 0,
			"environment_push": 0.0, "player_push": 0.0})


func _on_contact(attacker: int, victim: int, strength: float) -> void:
	if _probe_config == null:
		return
	if victim < 0 or victim >= _contacts.size() or attacker < -1 \
			or attacker >= _contacts.size() or not is_finite(strength) or strength < 0.0:
		_invalid_contacts += 1
		return
	var row := _contacts[victim]
	if strength == 0.0:
		row.blocked_feedback += 1
		return
	var kind := "environment" if attacker < 0 else "player"
	row[kind + "_hits"] += 1
	row[kind + "_push"] += strength


func _play(cfg: MatchConfig) -> MatchResult:
	_begin_probe(cfg)
	EventBus.player_hit.connect(_on_contact)
	var result: MatchResult = await super._play(cfg)
	EventBus.player_hit.disconnect(_on_contact)
	_probe_config = null
	if _contact_file == null:
		_contact_file = FileAccess.open(SaveSystem.storage_root.path_join("contact-probe.jsonl"), FileAccess.WRITE)
	if _contact_file == null:
		push_error("Cannot write contact probe in isolated test storage")
		get_tree().quit(2)
		return null
	var row := {"game": cfg.minigame_id, "seed": cfg.seed,
		"characters": cfg.players.map(func(player): return player.character_id),
		"difficulty": cfg.players.map(func(player): return player.ai_difficulty),
		"mutators": Array(cfg.mutators), "chaos": cfg.chaos,
		"completed": result != null, "contacts": _contacts.duplicate(true),
		"invalid_contacts": _invalid_contacts, "simulation_source": _source_start}
	if result != null:
		row["duration"] = result.duration
		row["scores"] = Array(result.scores)
		row["winners"] = Array(result.winners())
		row["details"] = result.details.duplicate(true)
	_contact_file.store_line(JSON.stringify(row))
	_contact_file.flush()
	return result


func _exit_tree() -> void:
	if EventBus.player_hit.is_connected(_on_contact):
		EventBus.player_hit.disconnect(_on_contact)
	_probe_config = null
	if _contact_file != null:
		_contact_file.close()
		_contact_file = null
