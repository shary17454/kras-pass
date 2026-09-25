class_name PartyPlaylist
extends RefCounted

const PREFIX := "KP1."
const LIMIT := 12
static var _catalog_cache := ""


static func catalog() -> String:
	if not _catalog_cache.is_empty():
		return _catalog_cache
	var hashes := ""
	for file in ["characters", "minigames", "arenas", "powerups", "mutators", "tuning", "ai"]:
		hashes += FileAccess.get_sha256("res://data/%s.json" % file)
	_catalog_cache = hashes.sha256_text().left(16)
	return _catalog_cache


static func create_plan() -> Dictionary:
	var games := TournamentSession.random_games(3, 41)
	var entries: Array = []
	for id in games:
		entries.append({"game": id, "arena": Registry.minigame(id).arena_ids[0]})
	return {"version": 1, "catalog": catalog(), "name": "", "seed": randi_range(1, 2147483647),
		"preset": "normal", "double_final": false, "entries": entries}


static func valid(plan: Dictionary, require_unlocked := true) -> bool:
	if typeof(plan.get("version")) not in [TYPE_INT, TYPE_FLOAT] or not plan.get("catalog") is String or not plan.get("preset") is String:
		return false
	if float(plan.get("version", 0)) != 1.0 or String(plan.get("catalog", "")) != catalog():
		return false
	if not plan.get("entries") is Array or plan["entries"].size() < 3 or plan["entries"].size() > 10:
		return false
	if not PlaylistGenerator.preset_ids().has(String(plan.get("preset", ""))):
		return false
	if typeof(plan.get("seed")) not in [TYPE_INT, TYPE_FLOAT] or not plan.get("double_final", false) is bool or not plan.get("name", "") is String:
		return false
	var seed_number := float(plan["seed"])
	if not is_finite(seed_number) or seed_number < 1 or seed_number > 2147483647 or seed_number != floor(seed_number):
		return false
	for entry in plan["entries"]:
		if not entry is Dictionary:
			return false
		if not entry.get("game") is String or not entry.get("arena") is String:
			return false
		var game := Registry.minigame(String(entry.get("game", "")))
		if game == null or game.is_boss or not game.arena_ids.has(String(entry.get("arena", ""))):
			return false
		if require_unlocked and not Progression.is_game_unlocked(game.id):
			return false
	return true


static func sanitized(plan: Dictionary) -> Dictionary:
	if not valid(plan):
		return {}
	var entries: Array = []
	for entry in plan["entries"]:
		entries.append({"game": String(entry["game"]), "arena": String(entry["arena"])})
	return {"version": 1, "catalog": catalog(), "name": String(plan.get("name", "")).strip_edges().left(32),
		"seed": int(plan["seed"]), "preset": String(plan["preset"]),
		"double_final": bool(plan.get("double_final", false)), "entries": entries}


static func encode(plan: Dictionary) -> String:
	var clean := sanitized(plan)
	if clean.is_empty():
		return ""
	var json := JSON.stringify(clean)
	return PREFIX + Marshalls.utf8_to_base64(json) + "." + json.sha256_text().left(12)


static func decode(code: String) -> Dictionary:
	var text := code.strip_edges()
	if text.length() > 8192 or not text.begins_with(PREFIX):
		return {}
	var parts := text.split(".")
	if parts.size() != 3:
		return {}
	if parts[1].length() % 4 != 0 or RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$").search(parts[1]) == null:
		return {}
	var json := Marshalls.base64_to_utf8(parts[1])
	if json.sha256_text().left(12) != parts[2]:
		return {}
	var value = JSON.parse_string(json)
	return sanitized(value) if value is Dictionary else {}


static func saved() -> Dictionary:
	return SaveSystem.player_branch("party_playlists").duplicate(true)


static func save(plan: Dictionary) -> bool:
	var clean := sanitized(plan)
	if clean.is_empty() or clean["name"].is_empty():
		return false
	var all := saved()
	var name := String(clean["name"])
	if all.size() >= LIMIT and not all.has(name):
		return false
	all[name] = clean
	SaveSystem.set_player_branch("party_playlists", all)
	SaveSystem.flush()
	return true


static func remove(name: String) -> void:
	var all := saved()
	all.erase(name)
	SaveSystem.set_player_branch("party_playlists", all)
	SaveSystem.flush()


static func make_session(plan: Dictionary, players: Array[PlayerConfig]) -> TournamentSession:
	var clean := sanitized(plan)
	if clean.is_empty():
		return null
	for entry in clean["entries"]:
		var game := Registry.minigame(entry["game"])
		if players.size() < game.min_players or players.size() > game.max_players:
			return null
	var session := TournamentSession.from_preset(clean["preset"], players, clean["seed"])
	session.game_ids.clear()
	session.arena_ids.clear()
	for entry in clean["entries"]:
		session.game_ids.append(entry["game"])
		session.arena_ids.append(entry["arena"])
	session.double_final = clean["double_final"]
	return session
