extends RefCounted
## One public setup per UTC day; trial content never changes unlock ownership.

const REWARD_GEMS := 12
const HISTORY_LIMIT := 32
const CLAIM_LIMIT := 90
const MAX_ATTEMPTS := 2147483647


static func today_key() -> String:
	var date := Time.get_date_dict_from_system(true)
	return "%04d%02d%02d" % [date.year, date.month, date.day]


static func plan(day_key: String) -> Dictionary:
	if RegEx.create_from_string("^[0-9]{8}$").search(day_key) == null:
		return {}
	var games := Registry.minigames().duplicate()
	games.sort_custom(func(a, b): return a.id < b.id)
	var characters := Registry.characters().duplicate()
	characters.sort_custom(func(a, b): return a.id < b.id)
	if games.is_empty() or characters.is_empty():
		return {}
	var seed_value := int(day_key.hash()) & 0x7FFFFFFF
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var game: MiniGameDef = games[rng.randi_range(0, games.size() - 1)]
	var arenas := game.arena_ids.duplicate()
	arenas.sort()
	if arenas.is_empty():
		return {}
	var arena := arenas[rng.randi_range(0, arenas.size() - 1)]
	var character: CharacterData = characters[rng.randi_range(0, characters.size() - 1)]
	var modifiers := MutatorSystem.available_for(game)
	modifiers.sort()
	var mutators: Array[String] = []
	if not modifiers.is_empty() and rng.randf() < 0.5:
		mutators.append(modifiers[rng.randi_range(0, modifiers.size() - 1)])
	return {"key": day_key, "catalog": PartyPlaylist.catalog(), "seed": seed_value,
		"game": game.id, "arena": arena, "character": character.id,
		"difficulty": rng.randi_range(1, 3), "mutators": mutators}


static func configuration(setup: Dictionary, profile_id: String) -> MatchConfig:
	if setup.is_empty():
		return null
	var game := Registry.minigame(String(setup.game))
	var roster: Array = [setup.character]
	var characters := Registry.characters().duplicate()
	characters.sort_custom(func(a, b): return a.id < b.id)
	for slot in range(1, mini(4, game.max_players)):
		roster.append(characters[(slot + int(setup.seed)) % characters.size()].id)
	var cfg := MatchConfig.build(game.id, roster, 1, int(setup.difficulty), int(setup.seed))
	cfg.arena_id = String(setup.arena)
	cfg.rounds = game.default_rounds
	cfg.subtitle_key = "daily.title"
	cfg.mutators = PackedStringArray(setup.mutators)
	cfg.players[0].local_profile_id = profile_id
	return cfg


static func _stored(profile_id: String) -> Dictionary:
	var player: Dictionary = SaveSystem.profile().get("profiles", {}).get(profile_id, {})
	var raw = player.get("daily_done", {})
	var data: Dictionary = raw.duplicate(true) if raw is Dictionary else {"key": raw} if raw is String else {}
	if not data.get("records") is Dictionary:
		data["records"] = {}
	if not data.get("claims") is Dictionary:
		data["claims"] = {}
	var old_key := String(data.get("key", ""))
	if not old_key.is_empty():
		data.claims[old_key] = true
	return data


static func claimed(profile_id: String, day_key: String) -> bool:
	return bool(_stored(profile_id).claims.get(day_key, false))


static func _record_key(setup: Dictionary) -> String:
	return String(setup.key) + "-" + String(setup.catalog)


static func record(profile_id: String, setup: Dictionary) -> Dictionary:
	return _normalized_record(_stored(profile_id).records.get(_record_key(setup)))


static func _normalized_record(value: Variant) -> Dictionary:
	var raw: Dictionary = value if value is Dictionary else {}
	var row := raw.duplicate(true)
	row.merge({"attempts": 0, "completed": 0, "last_completed_attempt": 0,
		"best_score": null, "best_time": null}, true)
	for field in ["attempts", "completed", "last_completed_attempt"]:
		var count: Variant = raw.get(field)
		if (count is int or count is float) and is_finite(float(count)) \
			and float(count) >= 0.0 and float(count) <= MAX_ATTEMPTS and float(count) == floorf(float(count)):
			row[field] = int(count)
	row.completed = mini(row.completed, row.attempts)
	row.last_completed_attempt = mini(maxi(row.last_completed_attempt, row.completed), row.attempts)
	var score: Variant = raw.get("best_score")
	if (score is int or score is float) and is_finite(float(score)) \
		and float(score) >= 0.0 and float(score) <= MAX_ATTEMPTS and float(score) == floorf(float(score)):
		row.best_score = int(score)
	var seconds: Variant = raw.get("best_time")
	if (seconds is int or seconds is float) and is_finite(float(seconds)) and float(seconds) >= 0.0:
		row.best_time = float(seconds)
	return row


static func begin_attempt(profile_id: String, setup: Dictionary) -> int:
	if not SaveSystem.profile_ids().has(profile_id) or setup.is_empty():
		return 0
	var data := _stored(profile_id)
	var key := _record_key(setup)
	var row := _normalized_record(data.records.get(key))
	if int(row.attempts) >= MAX_ATTEMPTS:
		return 0
	row.attempts = int(row.attempts) + 1
	data.records[key] = row
	_trim(data.records, HISTORY_LIMIT)
	SaveSystem.set_profile_branch(profile_id, "daily_done", data)
	SaveSystem.flush()
	return int(row.attempts)


static func complete_attempt(profile_id: String, setup: Dictionary, attempt: int, result: MatchResult) -> bool:
	if result == null or not result.finished_naturally or setup.is_empty() \
		or result.minigame_id != String(setup.game) or result.arena_id != String(setup.arena) \
		or result.scores.is_empty() or result.places.size() != result.scores.size() \
		or not is_finite(result.duration) or result.duration < 0.0 \
		or not SaveSystem.profile_ids().has(profile_id):
		return false
	var data := _stored(profile_id)
	var key := _record_key(setup)
	var row := _normalized_record(data.records.get(key))
	if row.is_empty() or attempt <= int(row.last_completed_attempt) or attempt > int(row.attempts):
		return false
	row.last_completed_attempt = attempt
	row.completed = int(row.completed) + 1
	var game := Registry.minigame(String(setup.game))
	var racing := game.scoring == MiniGameDef.Scoring.RACE_TIME
	var score := result.score_of(0)
	if not racing or score < 1000000000:
		if row.best_score == null or (score < int(row.best_score) if racing else score > int(row.best_score)):
			row.best_score = score
		var won := result.winners().size() == 1 and result.winner_slot() == 0
		if racing or won:
			var seconds := float(score) / 100.0 if racing else result.duration
			if row.best_time == null or seconds < float(row.best_time):
				row.best_time = seconds
	data.records[key] = row
	var reward := result.winners().size() == 1 and result.winner_slot() == 0 \
		and not bool(data.claims.get(String(setup.key), false))
	if reward:
		data.claims[String(setup.key)] = true
		if String(setup.key) > String(data.get("key", "")):
			data["key"] = String(setup.key)
	_trim(data.claims, CLAIM_LIMIT)
	SaveSystem.begin_batch()
	SaveSystem.set_profile_branch(profile_id, "daily_done", data)
	if reward:
		Progression.reward_profile(profile_id, REWARD_GEMS)
	SaveSystem.end_batch()
	return true


static func _trim(values: Dictionary, limit: int) -> void:
	var keys := values.keys()
	keys.sort()
	while keys.size() > limit:
		values.erase(keys.pop_front())
