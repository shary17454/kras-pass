extends Node
## Lifetime statistics. Autoload name: `Stats`.
##
## Every number the profile screen shows and several achievements depend on this
## being the single writer. Mini-games never touch it; the match layer reports
## one result and everything else is derived.

signal updated()

const BRANCH := "stats"

var _s := {}
var _recording_profile := ""


func _ready() -> void:
	_load()
	SaveSystem.profile_loaded.connect(func(_d): _load())


func _load() -> void:
	_s = SaveSystem.player_branch(BRANCH)
	_fill_defaults()
	_commit()


func _fill_defaults() -> void:
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
		"top_three": 0, "goals": 0, "race_wins": 0,
		"party_tournaments": 0, "party_cups": 0, "rivals": {},
		"no_fall_wins": 0, "comeback_cups": 0,
	}
	for k in defaults:
		if not _s.has(k):
			_s[k] = defaults[k]


func _commit() -> void:
	if not _recording_profile.is_empty():
		SaveSystem.set_profile_branch(_recording_profile, BRANCH, _s)
	else:
		SaveSystem.set_player_branch(BRANCH, _s)


# --- reporting -------------------------------------------------------------

## Called once per finished match by `MatchScene`.
func record_match(config: MatchConfig, result: MatchResult) -> void:
	if not result.finished_naturally or config.context == MatchConfig.Context.TRAINING or bool(config.rule("party_tiebreak", false)) or result.has_meta("stats_recorded"):
		return
	result.set_meta("stats_recorded", true)
	SaveSystem.begin_batch()
	var seen := {}
	var humans := config.human_slots()
	for slot in humans:
		var player := config.player_at(slot)
		var id := player.local_profile_id
		# Legacy single-player modes implicitly use the active profile. Lobby
		# guests deliberately have no persistent identity.
		if id.is_empty() and player.display_name_override.is_empty() and slot == humans[0]:
			id = SaveSystem.active_profile_id()
		if id.is_empty() or seen.has(id) or not SaveSystem.profile_ids().has(id):
			continue
		seen[id] = true
		if not _claim_event(id, String(config.rule("party_progress_token", ""))):
			continue
		_recording_profile = id
		_s = SaveSystem.profile_branch(id, BRANCH)
		_fill_defaults()
		_record_for_slot(config, result, slot)
		var won := result.place_of(slot) == 1 and not result.is_draw()
		var gems := Balance.inum("tuning", "scoring.gems_per_win" if won else "scoring.gems_per_participation", 1)
		# Adventure owns its stage reward. It still evaluates each named
		# participant's earned statistics and achievement unlocks here.
		Progression.reward_profile(id, 0 if config.context == MatchConfig.Context.ADVENTURE else gems)
	_recording_profile = ""
	_load()
	SaveSystem.end_batch()
	updated.emit()


func _record_for_slot(config: MatchConfig, result: MatchResult, me: int) -> void:
	_s["matches"] = total_matches() + 1
	_s["rounds"] = int(_s.get("rounds", 0)) + maxi(1, result.rounds.size())
	_s["play_seconds"] = float(_s.get("play_seconds", 0.0)) + result.duration

	var won := me >= 0 and result.place_of(me) == 1 and not result.is_draw()
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
		_s["goals"] = int(_s.get("goals", 0)) + int(result.detail(me, "goals", 0))
		_s["powerups"] = int(_s.get("powerups", 0)) + int(result.detail(me, "powerups", 0))
		if won and not drew and result.duration > 0 and config.definition() != null and config.definition().category == MiniGameDef.Category.PUSH_OUT and int(result.detail(me, "falls", 0)) == 0:
			_s["no_fall_wins"] = int(_s.get("no_fall_wins", 0)) + 1
		if result.place_of(me) in [1, 2, 3]:
			_s["top_three"] = int(_s.get("top_three", 0)) + 1
		if won and not drew and config.definition() != null and config.definition().category == MiniGameDef.Category.RACE:
			_s["race_wins"] = int(_s.get("race_wins", 0)) + 1

	_commit()


func record_tournament(players: Array[PlayerConfig], champion_slot: int, shared: Array[int] = [], comeback_slots: Array[int] = [], token := "") -> void:
	SaveSystem.begin_batch()
	var seen := {}
	for p in players:
		var id := p.local_profile_id
		if id.is_empty() and p.is_human and p.display_name_override.is_empty() and seen.is_empty():
			id = SaveSystem.active_profile_id()
		if not p.is_human or id.is_empty() or seen.has(id) or not SaveSystem.profile_ids().has(id):
			continue
		seen[id] = true
		if not _claim_event(id, token):
			continue
		var data := SaveSystem.profile_branch(id, BRANCH)
		var cup := p.slot == champion_slot or shared.has(p.slot)
		data["party_tournaments"] = int(data.get("party_tournaments", 0)) + 1
		if cup:
			data["party_cups"] = int(data.get("party_cups", 0)) + 1
			if comeback_slots.has(p.slot):
				data["comeback_cups"] = int(data.get("comeback_cups", 0)) + 1
		var rivals: Dictionary = data.get("rivals", {})
		for other in players:
			if not other.is_human or other.slot == p.slot or other.local_profile_id.is_empty() or other.local_profile_id == p.local_profile_id:
				continue
			var entry: Dictionary = rivals.get(other.local_profile_id, {"played": 0, "wins": 0, "losses": 0})
			entry["played"] = int(entry["played"]) + 1
			entry["wins"] = int(entry["wins"]) + int(champion_slot == p.slot)
			entry["losses"] = int(entry["losses"]) + int(champion_slot == other.slot)
			rivals[other.local_profile_id] = entry
		data["rivals"] = rivals
		SaveSystem.set_profile_branch(id, BRANCH, data)
		Progression.reward_profile(id, Balance.inum("tuning", "scoring.gems_per_win", 3) * 3 if cup else 0, cup)
	_load()
	SaveSystem.end_batch()
	updated.emit()


func _claim_event(profile_id: String, token: String) -> bool:
	if token.is_empty():
		return true
	var receipts := SaveSystem.profile_branch(profile_id, "party_receipts")
	var recent: Array = receipts.get("recent", [])
	if recent.has(token):
		return false
	recent.append(token)
	while recent.size() > 128:
		recent.pop_front()
	SaveSystem.set_profile_branch(profile_id, "party_receipts", {"recent": recent})
	return true


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
	return float(_s.get("play_seconds", 0.0))


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
		{"key": "party.stats.top_three", "value": str(_s.get("top_three", 0))},
		{"key": "party.stats.goals", "value": str(_s.get("goals", 0))},
		{"key": "party.stats.race_wins", "value": str(_s.get("race_wins", 0))},
		{"key": "party.stats.cups", "value": str(_s.get("party_cups", 0))},
		{"key": "stats.powerups", "value": str(_s.get("powerups", 0))},
		{"key": "stats.playtime", "value": _format_time(play_seconds())},
		{"key": "stats.favourite_game", "value": _game_name(most_played_game())},
		{"key": "stats.favourite_character", "value": _char_name(most_played_character())},
	]


func rivalry_rows() -> Array:
	var rows: Array = []
	for id in _s.get("rivals", {}):
		if not SaveSystem.profile_ids().has(id):
			continue
		var entry: Dictionary = _s["rivals"][id].duplicate(true)
		entry["name"] = SaveSystem.profile_meta(id).get("name", "")
		rows.append(entry)
	return rows


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
