class_name TournamentSession
extends RefCounted
## A run of several mini-games scored on a points table.
##
## The session outlives the screens: it is referenced by the `on_finished`
## Callable handed to `MatchScene`, so it stays alive across the whole
## standings -> match -> standings loop without any global state.

signal completed(champion_slot: int)

var players: Array[PlayerConfig] = []
var game_ids: Array[String] = []
## Parallel to `game_ids`. Empty entries (or a shorter array) fall back to a
## random arena at config-build time, so a session built the old way — before
## presets existed — keeps working unchanged.
var arena_ids: Array[String] = []
## Applied to every game in the cup. A preset picks one set of modifiers for
## the whole party rather than per-game, which matches how "a chaos cup" or
## "a skill cup" is meant to feel — consistently, not one game at a time.
var mutators: PackedStringArray = []
var chaos := false
var index := 0
var points: Array[int] = []
var results: Array[MatchResult] = []
var seed_value := 1
var allow_powerups := true
var recorded := false
var preset_id := ""
var double_final := false
var match_rules: Dictionary = {}
var last_awards: Array[int] = []
var tiebreak_slots: Array[int] = []
var tiebreak_attempts := 0
var resolved_champion := -1
var shared_champions: Array[int] = []
var owner_profile := ""
var _persistent := false
var run_id := ""
var performance: Array = []
var trailed_last: Array[int] = []

const SAVE_VERSION := 1
const SAVE_BRANCH := "active_tournament"
const MAX_TIEBREAKS := 3

var _points_table: Array = [5, 3, 2, 1]
var _tie_share := true


func setup(player_list: Array[PlayerConfig], games: Array[String], rng_seed: int) -> void:
	players = player_list.duplicate()
	game_ids = games.duplicate()
	index = 0
	run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	results.clear()
	performance.clear()
	trailed_last.clear()
	for _player in players:
		performance.append({})
	recorded = false
	tiebreak_slots.clear()
	shared_champions.clear()
	resolved_champion = -1
	tiebreak_attempts = 0
	seed_value = rng_seed if rng_seed != 0 else 1
	points.resize(players.size())
	points.fill(0)
	var table := Balance.list("tuning", "scoring.tournament_points")
	if table.size() >= 4:
		_points_table = table
	_tie_share = Balance.flag("tuning", "scoring.tournament_points_tie_share", true)


## The preset path: one call builds the whole schedule — games, arenas,
## modifiers and the AI opponents' difficulty — from `data/mutators.json`.
## `player_list`'s AI entries have their difficulty overwritten to match the
## preset; the human slot (`is_human == true`) is left alone.
static func from_preset(preset_id_: String, player_list: Array[PlayerConfig], rng_seed: int,
		pool_override: Array = []) -> TournamentSession:
	var plan := PlaylistGenerator.from_preset(preset_id_, rng_seed, pool_override)
	var entries: Array = plan["entries"]
	var games: Array[String] = []
	var arenas: Array[String] = []
	for e in entries:
		games.append(String(e["game_id"]))
		arenas.append(String(e["arena_id"]))
	for p in player_list:
		if not p.is_human:
			p.ai_difficulty = int(plan["difficulty"])
	var session := TournamentSession.new()
	session.setup(player_list, games, rng_seed)
	session.arena_ids = arenas
	session.mutators = PackedStringArray(plan["mutators"])
	session.chaos = bool(plan["chaos"])
	session.allow_powerups = bool(plan["powerups"])
	session.preset_id = preset_id_
	session.match_rules = plan.get("rules", {}).duplicate(true)
	return session


func total_games() -> int:
	return game_ids.size()


func is_complete() -> bool:
	return index >= game_ids.size() and tiebreak_slots.is_empty()


func current_game() -> MiniGameDef:
	if not tiebreak_slots.is_empty():
		return Registry.minigame("quick_draw")
	return Registry.minigame(game_ids[index]) if not is_complete() else null


## Build the config for the next game in the schedule.
func next_config() -> MatchConfig:
	if is_complete():
		return null
	var def := current_game()
	if def == null:
		return null
	var cfg := MatchConfig.new()
	cfg.minigame_id = def.id
	cfg.context = MatchConfig.Context.TOURNAMENT
	cfg.rounds = 1
	cfg.allow_powerups = allow_powerups
	cfg.sudden_death = def.supports_sudden_death
	cfg.seed = seed_value + index * 977 + tiebreak_attempts * 7919
	var picked := String(arena_ids[index]) if index < arena_ids.size() else ""
	if picked != "" and def.arena_ids.has(picked):
		cfg.arena_id = picked
	elif def.arena_ids.size() > 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = cfg.seed
		cfg.arena_id = def.arena_ids[rng.randi_range(0, def.arena_ids.size() - 1)]
	cfg.mutators = mutators
	cfg.chaos = chaos
	if chaos:
		var choices := MutatorSystem.available_for(def)
		var random := RandomNumberGenerator.new()
		random.seed = cfg.seed
		if not choices.is_empty():
			cfg.mutators = PackedStringArray([choices[random.randi_range(0, choices.size() - 1)]])
	cfg.subtitle_key = "tournament.title"
	cfg.rules = match_rules.duplicate(true)
	cfg.rules["party_short_race"] = int(match_rules.get("race_laps", 3)) < 3
	cfg.rules["ai_personalities"] = true
	cfg.rules["party_final"] = index == game_ids.size() - 1
	cfg.rules["party_progress_token"] = "%s:match:%d" % [run_id, index]
	cfg.rules["maximum_duration"] = float(match_rules.get("maximum_duration", 240.0))
	cfg.duration_override = minf(def.duration, float(match_rules.get("round_seconds", 120.0)))
	if not tiebreak_slots.is_empty():
		cfg.subtitle_key = "party.tiebreak"
		cfg.duration_override = 20.0
		cfg.rules["maximum_duration"] = 25.0
		cfg.sudden_death = false
		cfg.allow_powerups = false
		cfg.mutators = []
		cfg.chaos = false
		cfg.rules["party_tiebreak"] = true
		for original_slot in tiebreak_slots:
			var p := players[original_slot].duplicate() as PlayerConfig
			p.slot = cfg.players.size()
			cfg.players.append(p)
	else:
		for p in players:
			cfg.players.append(p)
	return cfg


## Callable target handed to MatchScene. Records the result and returns to the
## standings screen — or to the champion screen when the schedule is done.
func on_match_finished(result: MatchResult) -> void:
	record(result)
	SceneRouter.go_to("standings", {"session": self, "last": result}, false)


func record(result: MatchResult) -> void:
	if result == null or is_complete() or not result.finished_naturally:
		return
	var expected := tiebreak_slots.size() if not tiebreak_slots.is_empty() else players.size()
	if result.places.size() != expected or result.minigame_id != current_game().id:
		return
	for place in result.places:
		if place < 1 or place > expected:
			return
	if not tiebreak_slots.is_empty():
		last_awards.assign([0, 0, 0, 0].slice(0, players.size()))
		var survivors: Array[int] = []
		for winner in result.winners():
			survivors.append(tiebreak_slots[winner])
		tiebreak_attempts += 1
		if survivors.size() == 1:
			resolved_champion = survivors[0]
			tiebreak_slots.clear()
		elif tiebreak_attempts >= MAX_TIEBREAKS:
			# An unresolved match is a shared cup, never a slot-order lottery.
			shared_champions = survivors
			tiebreak_slots.clear()
		else:
			tiebreak_slots = survivors
		_complete_or_save()
		return
	results.append(result)
	for slot in players.size():
		for key in ["knockouts", "falls", "collected", "goals", "saves", "crates"]:
			performance[slot][key] = int(performance[slot].get(key, 0)) + maxi(0, int(result.detail(slot, key, 0)))
	var awarded := award_for(result)
	if double_final and index == game_ids.size() - 1:
		for i in awarded.size():
			awarded[i] *= 2
	last_awards = awarded
	for i in mini(points.size(), awarded.size()):
		points[i] += awarded[i]
	index += 1
	if index < game_ids.size() and points.min() != points.max():
		for slot in points.size():
			if points[slot] == points.min() and not trailed_last.has(slot):
				trailed_last.append(slot)
	if index >= game_ids.size():
		var leaders := leading_slots()
		if leaders.size() > 1:
			tiebreak_slots = leaders
		else:
			resolved_champion = leaders[0] if not leaders.is_empty() else -1
	_complete_or_save()


func _complete_or_save() -> void:
	if is_complete() and not recorded:
		recorded = true
		var champ := champion()
		if _persistent:
			SaveSystem.set_shared_branch(SAVE_BRANCH, {})
		Stats.record_tournament(players, champ, shared_champions, trailed_last, run_id + ":cup")
		completed.emit(champ)
	if _persistent:
		if is_complete():
			SaveSystem.set_shared_branch(SAVE_BRANCH, {})
			SaveSystem.flush()
		else:
			checkpoint()


## Points for one game's placements. Ties share the higher award so a two-way
## first place does not silently demote one of them to second.
func award_for(result: MatchResult) -> Array[int]:
	var out: Array[int] = []
	out.resize(players.size())
	out.fill(0)
	for slot in mini(players.size(), result.places.size()):
		var place := result.places[slot]
		if place < 1 or place > players.size():
			continue
		var value: int = int(_points_table[mini(place - 1, _points_table.size() - 1)])
		if _tie_share:
			var shared := 0
			for other in result.places:
				if other == place:
					shared += 1
			if shared > 1:
				# Average the band the tied players occupy, rounded up.
				var total := 0
				for k in shared:
					total += int(_points_table[mini(place - 1 + k, _points_table.size() - 1)])
				value = int(ceil(float(total) / float(shared)))
		out[slot] = int(value)
	return out


func champion() -> int:
	if resolved_champion >= 0:
		return resolved_champion
	var leaders := leading_slots()
	return leaders[0] if leaders.size() == 1 else -1


func leading_slots() -> Array[int]:
	var leaders: Array[int] = []
	if points.is_empty():
		return leaders
	var highest: int = points.max()
	for i in points.size():
		if points[i] == highest:
			leaders.append(i)
	return leaders


## Slots ordered best-first, with the last game's placement as a tie-break.
func ranking() -> Array[int]:
	var order: Array[int] = []
	for i in points.size():
		order.append(i)
	order.sort_custom(func(a, b):
		if a == resolved_champion or b == resolved_champion:
			return a == resolved_champion
		if points[a] != points[b]:
			return points[a] > points[b]
		return a < b)
	return order


func rows() -> Array:
	var out: Array = []
	var order := ranking()
	var place := 1
	for rank in order.size():
		var slot: int = order[rank]
		if rank > 0 and (points[slot] != points[order[rank - 1]] or order[rank - 1] == resolved_champion):
			place = rank + 1
		out.append({
			"rank": place,
			"slot": slot,
			"name": players[slot].display_name(),
			"color": players[slot].color(),
			"points": points[slot],
			"human": players[slot].is_human,
		})
	return out


func fun_awards() -> Array:
	var awards: Array = []
	for key in ["knockouts", "falls", "collected", "goals", "saves", "crates"]:
		var best := 0
		var slots: Array[int] = []
		for slot in performance.size():
			var count := int(performance[slot].get(key, 0))
			if count > best:
				best = count
				slots = [slot]
			elif count == best and count > 0:
				slots.append(slot)
		if best > 0:
			awards.append({"key": "party.award." + key, "slots": slots, "value": best})
	if is_complete() and champion() >= 0 and trailed_last.has(champion()):
		awards.append({"key": "party.award.comeback", "slots": [champion()], "value": 1})
	return awards


func checkpoint() -> void:
	if is_complete():
		return
	_persistent = true
	if owner_profile.is_empty():
		owner_profile = SaveSystem.active_profile_id()
	SaveSystem.set_shared_branch(SAVE_BRANCH, to_dict())
	SaveSystem.flush()


func to_dict() -> Dictionary:
	var roster: Array = []
	for player in players:
		roster.append(player.to_dict())
	return {"version": SAVE_VERSION, "players": roster, "games": game_ids,
		"arenas": arena_ids, "seed": seed_value, "index": index, "points": points,
		"mutators": Array(mutators), "chaos": chaos, "powerups": allow_powerups,
		"preset": preset_id, "double_final": double_final, "rules": match_rules,
		"tiebreak_slots": tiebreak_slots, "tiebreak_attempts": tiebreak_attempts,
		"owner": owner_profile, "performance": performance, "trailed_last": trailed_last, "run_id": run_id}


static func restore(data: Dictionary) -> TournamentSession:
	if int(data.get("version", 0)) != SAVE_VERSION:
		return null
	for key in ["players", "games", "arenas", "points", "mutators", "tiebreak_slots"]:
		if not data.get(key) is Array:
			return null
	if not data.get("rules") is Dictionary:
		return null
	var roster: Array[PlayerConfig] = []
	if data["players"].size() < 2 or data["players"].size() > 4:
		return null
	for raw in data["players"]:
		if not raw is Dictionary:
			return null
		var player := PlayerConfig.from_dict(raw)
		if player == null or player.slot != roster.size():
			return null
		roster.append(player)
	var games: Array[String] = []
	if data["games"].is_empty() or data["games"].size() > 20:
		return null
	for raw in data["games"]:
		var def := Registry.minigame(String(raw))
		if def == null or def.is_boss or roster.size() < def.min_players or roster.size() > def.max_players:
			return null
		games.append(def.id)
	var next := int(data.get("index", -1))
	if next < 0 or next > games.size() or data["points"].size() != roster.size():
		return null
	var session := TournamentSession.new()
	session.setup(roster, games, int(data.get("seed", 1)))
	session.index = next
	for i in roster.size():
		var value := int(data["points"][i])
		if value < 0 or value > 200:
			return null
		session.points[i] = value
	for raw in data["tiebreak_slots"]:
		var slot := int(raw)
		if slot < 0 or slot >= roster.size() or session.tiebreak_slots.has(slot):
			return null
		session.tiebreak_slots.append(slot)
	if not session.tiebreak_slots.is_empty() and (next != games.size() or session.tiebreak_slots.size() < 2):
		return null
	session.tiebreak_attempts = clampi(int(data.get("tiebreak_attempts", 0)), 0, MAX_TIEBREAKS - 1)
	session.arena_ids.assign(data["arenas"])
	session.mutators = PackedStringArray(data["mutators"])
	session.chaos = bool(data.get("chaos", false))
	session.allow_powerups = bool(data.get("powerups", true))
	session.double_final = bool(data.get("double_final", false))
	session.match_rules = data["rules"].duplicate(true)
	session.preset_id = String(data.get("preset", ""))
	session.owner_profile = String(data.get("owner", ""))
	var restored_id := String(data.get("run_id", ""))
	if restored_id.length() == 32 and restored_id.is_valid_hex_number():
		session.run_id = restored_id
	# Optional fields preserve version-1 checkpoints made before awards existed.
	var totals = data.get("performance", [])
	if totals is Array and totals.size() == roster.size():
		for slot in roster.size():
			if not totals[slot] is Dictionary:
				return null
			for key in ["knockouts", "falls", "collected", "goals", "saves", "crates"]:
				session.performance[slot][key] = clampi(int(totals[slot].get(key, 0)), 0, 100000)
	var trailing = data.get("trailed_last", [])
	if trailing is Array:
		for slot in trailing:
			if int(slot) >= 0 and int(slot) < roster.size() and not session.trailed_last.has(int(slot)):
				session.trailed_last.append(int(slot))
	session._persistent = true
	return null if session.is_complete() else session


static func saved_session() -> TournamentSession:
	var data = SaveSystem.shared_branch(SAVE_BRANCH, {})
	return restore(data) if data is Dictionary else null


func rematch() -> TournamentSession:
	var fresh := TournamentSession.new()
	fresh.setup(players, game_ids, seed_value)
	fresh.arena_ids = arena_ids.duplicate()
	fresh.mutators = mutators.duplicate()
	fresh.chaos = chaos
	fresh.allow_powerups = allow_powerups
	fresh.double_final = double_final
	fresh.match_rules = match_rules.duplicate(true)
	fresh.preset_id = preset_id
	return fresh


## Random schedule honouring the unlocked library.
static func random_games(count: int, rng_seed: int, pool: Array = []) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var source: Array = pool.duplicate()
	if source.is_empty():
		for m in Progression.playable_games():
			source.append(m.id)
	var out: Array[String] = []
	if source.is_empty():
		return out
	# Draw without replacement until the pool is exhausted, then reshuffle, so a
	# short tournament never repeats a game and a long one still can.
	var bag: Array = []
	while out.size() < count:
		if bag.is_empty():
			bag = source.duplicate()
			# Fisher-Yates with the session seed keeps lobbies in sync.
			for i in range(bag.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var tmp = bag[i]
				bag[i] = bag[j]
				bag[j] = tmp
		out.append(String(bag.pop_back()))
	return out
