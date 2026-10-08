extends "res://tools/balance_sim.gd"
## Development-only observation of accepted contact feedback; never changes play.

var _probe_config: MatchConfig
var _contacts: Array[Dictionary] = []
var _invalid_contacts := 0
var _contact_file: FileAccess
var _round_tick := -1
var _round_complete := false


func _begin_probe(cfg: MatchConfig) -> void:
	_probe_config = cfg
	_invalid_contacts = 0
	_round_tick = -1
	_round_complete = false
	process_physics_priority = 100
	_contacts.clear()
	for player in cfg.players:
		_contacts.append({"character": player.character_id,
			"environment_hits": 0, "player_hits": 0, "blocked_feedback": 0,
			"environment_push": 0.0, "player_push": 0.0,
			"jump_requests": 0, "alive_seconds": null})


func _physics_process(_delta: float) -> void:
	if _probe_config == null or _round_tick < 0 or _round_complete:
		return
	for slot in _contacts.size():
		if _contacts[slot].alive_seconds == null and InputRouter.frame(slot).just_pressed(InputFrame.Btn.JUMP):
			_contacts[slot].jump_requests += 1


func _on_round_started(_index: int) -> void:
	_round_tick = _physics_tick()


func _physics_tick() -> int:
	return Engine.get_physics_frames()


func _on_eliminated(slot: int, _place: int) -> void:
	if _round_tick >= 0 and slot >= 0 and slot < _contacts.size() and _contacts[slot].alive_seconds == null:
		_contacts[slot].alive_seconds = float(_physics_tick() - _round_tick) / float(Engine.physics_ticks_per_second)


func _on_round_finished(result: MatchResult) -> void:
	_round_complete = true
	for row in _contacts:
		row.alive_seconds = result.duration if row.alive_seconds == null else clampf(float(row.alive_seconds), 0.0, result.duration)


func _disconnect_feedback() -> void:
	for binding in [[EventBus.player_hit, _on_contact], [EventBus.round_started, _on_round_started],
			[EventBus.player_eliminated, _on_eliminated], [EventBus.round_finished, _on_round_finished]]:
		var event: Signal = binding[0]
		if event.is_connected(binding[1]):
			event.disconnect(binding[1])


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
	EventBus.round_started.connect(_on_round_started)
	EventBus.player_eliminated.connect(_on_eliminated)
	EventBus.round_finished.connect(_on_round_finished)
	var result: MatchResult = await super._play(cfg)
	_disconnect_feedback()
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
	_disconnect_feedback()
	_probe_config = null
	if _contact_file != null:
		_contact_file.close()
		_contact_file = null
