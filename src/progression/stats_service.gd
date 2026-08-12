extends Node
## Lifetime statistics. Autoload name: `Stats`.
##
## Every number the profile screen shows and several achievements depend on this
## being the single writer. Mini-games never touch it; the match layer reports
## one result and everything else is derived.

signal updated()

const BRANCH := "stats"

var _s := {}
var _session_start := 0.0


func _ready() -> void:
	_session_start = Time.get_ticks_msec() / 1000.0
	_load()
	SaveSystem.profile_loaded.connect(func(_d): _load())


func _load() -> void:
	_s = SaveSystem.player_branch(BRANCH)
	var defaults := {
		"matches": 0, "wins": 0, "losses": 0, "draws": 0,
		"rounds": 0, "play_seconds": 0.0,
		"knockouts": 0, "falls": 0, "powerups": 0,
		"per_game": {},        # game_id -> {"plays", "wins", "best"}
		"per_character": {},   # char_id -> {"plays", "wins"}
		"per_difficulty": {},  # "0".."3" -> {"plays", "wins"}
		"flawless_wins": 0,
		"expert_wins": 0,
		"longest_win_streak": 0,
		"current_win_streak": 0,
	}
	for k in defaults:
		if not _s.has(k):
			_s[k] = defaults[k]
	_commit()


func _commit() -> void:
	SaveSystem.set_player_branch(BRANCH, _s)


# --- reporting -------------------------------------------------------------

## Called once per finished match by `MatchScene`.
func record_match(config: MatchConfig, result: MatchResult) -> void:
	_s["matches"] = total_matches() + 1
	_s["rounds"] = int(_s.get("rounds", 0)) + maxi(1, result.rounds.size())
	_s["play_seconds"] = float(_s.get("play_seconds", 0.0)) + result.duration

	var human := config.human_slots()
	var me := human[0] if human.size() > 0 else -1
	var won := me >= 0 and result.place_of(me) == 1
	var drew := me >= 0 and result.is_draw() and result.place_of(me) == 1
	if me >= 0:
		if drew:
			_s["draws"] = int(_s.get("draws", 0)) + 1
		elif won:
			_s["wins"] = total_wins() + 1
		else:
			_s["losses"] = int(_s.get("losses", 0)) + 1
		if won and not drew:
			_s["current_win_streak"] = int(_s.get("current_win_streak", 0)) + 1
			_s["longest_win_streak"] = maxi(int(_s.get("longest_win_streak", 0)), int(_s["current_win_streak"]))
		else:
			_s["current_win_streak"] = 0

	var g: Dictionary = _s["per_game"]
	var gid := config.minigame_id
	var ge: Dictionary = g.get(gid, {"plays": 0, "wins": 0, "best": 0})
	ge["plays"] = int(ge["plays"]) + 1
	if won:
		ge["wins"] = int(ge["wins"]) + 1
	if me >= 0:
		ge["best"] = maxi(int(ge["best"]), result.score_of(me))
	g[gid] = ge

	if me >= 0:
		var pc := config.player_at(me)
		if pc != null:
			var c: Dictionary = _s["per_character"]
			var ce: Dictionary = c.get(pc.character_id, {"plays": 0, "wins": 0})
			ce["plays"] = int(ce["plays"]) + 1
			if won:
				ce["wins"] = int(ce["wins"]) + 1
			c[pc.character_id] = ce

	var hardest := 0
	for p in config.players:
		if not p.is_human:
			hardest = maxi(hardest, p.ai_difficulty)
	var d: Dictionary = _s["per_difficulty"]
	var de: Dictionary = d.get(str(hardest), {"plays": 0, "wins": 0})
	de["plays"] = int(de["plays"]) + 1
	if won:
		de["wins"] = int(de["wins"]) + 1
		if hardest >= PlayerConfig.Difficulty.EXPERT:
			_s["expert_wins"] = int(_s.get("expert_wins", 0)) + 1
	d[str(hardest)] = de

	# A flawless win = won every round of a multi-round match.
	if won and result.rounds.size() > 1:
		var all_rounds := true
		for r in result.rounds:
			if r.place_of(me) != 1:
				all_rounds = false
				break
		if all_rounds:
			_s["flawless_wins"] = int(_s.get("flawless_wins", 0)) + 1

	if me >= 0:
		_s["knockouts"] = int(_s.get("knockouts", 0)) + int(result.detail(me, "knockouts", 0))
		_s["falls"] = int(_s.get("falls", 0)) + int(result.detail(me, "falls", 0))

	_commit()
	SaveSystem.flush()
	updated.emit()


func record_powerup() -> void:
	_s["powerups"] = int(_s.get("powerups", 0)) + 1
	_commit()


# --- queries ---------------------------------------------------------------

func total_matches() -> int:
	return int(_s.get("matches", 0))


func total_wins() -> int:
	return int(_s.get("wins", 0))


func total_losses() -> int:
	return int(_s.get("losses", 0))


func win_rate() -> float:
	var played := total_matches()
	return 0.0 if played == 0 else float(total_wins()) / float(played) * 100.0


func play_seconds() -> float:
	return float(_s.get("play_seconds", 0.0)) + (Time.get_ticks_msec() / 1000.0 - _session_start)


func expert_wins() -> int:
	return int(_s.get("expert_wins", 0))


func flawless_wins() -> int:
	return int(_s.get("flawless_wins", 0))


func longest_streak() -> int:
	return int(_s.get("longest_win_streak", 0))


func knockouts() -> int:
	return int(_s.get("knockouts", 0))


func powerups_collected() -> int:
	return int(_s.get("powerups", 0))


func game_entry(game_id: String) -> Dictionary:
	return _s.get("per_game", {}).get(game_id, {"plays": 0, "wins": 0, "best": 0})


func character_entry(char_id: String) -> Dictionary:
	return _s.get("per_character", {}).get(char_id, {"plays": 0, "wins": 0})


func won_every_minigame() -> bool:
	for m in Registry.minigames():
		if int(game_entry(m.id).get("wins", 0)) <= 0:
			return false
	return true


func most_played_game() -> String:
	var best := ""
	var best_n := 0
	for k in _s.get("per_game", {}):
		var n := int(_s["per_game"][k].get("plays", 0))
		if n > best_n:
			best_n = n
			best = k
	return best


func most_played_character() -> String:
	var best := ""
	var best_n := 0
	for k in _s.get("per_character", {}):
		var n := int(_s["per_character"][k].get("plays", 0))
		if n > best_n:
			best_n = n
			best = k
	return best


func summary_rows() -> Array:
	return [
		{"key": "stats.matches", "value": str(total_matches())},
		{"key": "stats.wins", "value": str(total_wins())},
		{"key": "stats.losses", "value": str(total_losses())},
		{"key": "stats.win_rate", "value": "%.0f%%" % win_rate()},
		{"key": "stats.streak", "value": str(longest_streak())},
		{"key": "stats.tournaments", "value": str(Progression.tournaments_won())},
		{"key": "stats.knockouts", "value": str(_s.get("knockouts", 0))},
		{"key": "stats.powerups", "value": str(_s.get("powerups", 0))},
		{"key": "stats.playtime", "value": _format_time(play_seconds())},
		{"key": "stats.favourite_game", "value": _game_name(most_played_game())},
		{"key": "stats.favourite_character", "value": _char_name(most_played_character())},
	]


func reset() -> void:
	SaveSystem.set_player_branch(BRANCH, {})
	_s = {}
	_load()
	updated.emit()


func _format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%dh %dm" % [s / 3600, (s % 3600) / 60] if s >= 3600 else "%dm" % (s / 60)


func _game_name(id: String) -> String:
	var m := Registry.minigame(id)
	return m.display_name() if m != null else "—"


func _char_name(id: String) -> String:
	var c := Registry.character(id)
	return c.display_name() if c != null else "—"
