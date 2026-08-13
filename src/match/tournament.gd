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

var _points_table: Array = [5, 3, 2, 1]
var _tie_share := true


func setup(player_list: Array[PlayerConfig], games: Array[String], rng_seed: int) -> void:
	players = player_list
	game_ids = games
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
	return session


func total_games() -> int:
	return game_ids.size()


func is_complete() -> bool:
	return index >= game_ids.size()


func current_game() -> MiniGameDef:
	return Registry.minigame(game_ids[index]) if not is_complete() else null


## Build the config for the next game in the schedule.
func next_config() -> MatchConfig:
	if is_complete():
		return null
	var def := Registry.minigame(game_ids[index])
	var cfg := MatchConfig.new()
	cfg.minigame_id = def.id
	cfg.context = MatchConfig.Context.TOURNAMENT
	cfg.rounds = 1
	cfg.allow_powerups = allow_powerups
	cfg.sudden_death = def.supports_sudden_death
	cfg.seed = seed_value + index * 977
	var picked := String(arena_ids[index]) if index < arena_ids.size() else ""
	if picked != "" and def.arena_ids.has(picked):
		cfg.arena_id = picked
	elif def.arena_ids.size() > 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = cfg.seed
		cfg.arena_id = def.arena_ids[rng.randi_range(0, def.arena_ids.size() - 1)]
	cfg.mutators = mutators
	cfg.chaos = chaos
	cfg.subtitle_key = "tournament.title"
	for p in players:
		cfg.players.append(p)
	return cfg


## Callable target handed to MatchScene. Records the result and returns to the
## standings screen — or to the champion screen when the schedule is done.
func on_match_finished(result: MatchResult) -> void:
	record(result)
	SceneRouter.go_to("standings", {"session": self, "last": result}, false)


func record(result: MatchResult) -> void:
	results.append(result)
	var awarded := award_for(result)
	for i in mini(points.size(), awarded.size()):
		points[i] += awarded[i]
	index += 1
	if is_complete() and not recorded:
		recorded = true
		var champ := champion()
		var human := -1
		for p in players:
			if p.is_human:
				human = p.slot
				break
		if champ == human and human >= 0:
			Progression.record_tournament_win()
			Progression.grant_gems(Balance.inum("tuning", "scoring.gems_per_win", 3) * 3)
		Achievements.evaluate_all()
		completed.emit(champ)


## Points for one game's placements. Ties share the higher award so a two-way
## first place does not silently demote one of them to second.
func award_for(result: MatchResult) -> Array[int]:
	var out: Array[int] = []
	out.resize(players.size())
	out.fill(0)
	for slot in mini(players.size(), result.places.size()):
		var place := result.places[slot]
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
	var best := -1
	var best_points := -1
	for i in points.size():
		if points[i] > best_points:
			best_points = points[i]
			best = i
	return best


## Slots ordered best-first, with the last game's placement as a tie-break.
func ranking() -> Array[int]:
	var order: Array[int] = []
	for i in points.size():
		order.append(i)
	var last: MatchResult = results.back() if results.size() > 0 else null
	order.sort_custom(func(a, b):
		if points[a] != points[b]:
			return points[a] > points[b]
		if last != null:
			return last.place_of(a) < last.place_of(b)
		return a < b)
	return order


func rows() -> Array:
	var out: Array = []
	var order := ranking()
	for rank in order.size():
		var slot: int = order[rank]
		out.append({
			"rank": rank + 1,
			"slot": slot,
			"name": players[slot].display_name(),
			"color": players[slot].color(),
			"points": points[slot],
			"human": players[slot].is_human,
		})
	return out


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
