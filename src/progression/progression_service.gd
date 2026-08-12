extends Node
## Unlocks, currency and adventure progress. Autoload name: `Progression`.
##
## Owns the `progress` branch of the profile. Unlock *rules* live in the content
## JSON (`unlock: {...}` on a character or mini-game), so adding a new unlock
## condition is a data edit plus one clause in `_rule_met()`.

signal trophies_changed(total: int)
signal gems_changed(total: int)
signal completion_changed(percent: float)

const BRANCH := "progress"

var _p := {}


func _ready() -> void:
	_load()
	SaveSystem.profile_loaded.connect(func(_d): _load())


func _load() -> void:
	_p = SaveSystem.player_branch(BRANCH)
	var defaults := {
		"characters": [],
		"games": [],
		"worlds": [],
		"adventure": {},      # world_id -> {stage_id: {"cleared": bool, "stars": int, "best": int}}
		"trophies": 0,
		"gems": 0,
		"tournaments_won": 0,
		"last_character": "",
		"seen_intro": false,
	}
	for k in defaults:
		if not _p.has(k):
			_p[k] = defaults[k]
	# Starter content is always available, even on a corrupted profile.
	for c in Registry.starter_characters():
		if not _p["characters"].has(c.id):
			_p["characters"].append(c.id)
	for m in Registry.minigames():
		if m.unlock.is_empty() and not _p["games"].has(m.id):
			_p["games"].append(m.id)
	var worlds := Registry.worlds()
	if worlds.size() > 0 and _p["worlds"].is_empty():
		_p["worlds"].append(String(worlds[0].get("id", "")))
	_commit()


func _commit() -> void:
	SaveSystem.set_player_branch(BRANCH, _p)


func save_now() -> void:
	_commit()
	SaveSystem.flush()


# --- currency --------------------------------------------------------------

func trophies() -> int:
	return int(_p.get("trophies", 0))


func gems() -> int:
	return int(_p.get("gems", 0))


func grant_trophies(n: int) -> void:
	if n <= 0:
		return
	_p["trophies"] = trophies() + n
	trophies_changed.emit(trophies())
	EventBus.reward_granted.emit("trophy", n)
	_check_unlocks()
	save_now()


func grant_gems(n: int) -> void:
	if n <= 0:
		return
	_p["gems"] = gems() + n
	gems_changed.emit(gems())
	EventBus.reward_granted.emit("gem", n)
	_check_unlocks()
	save_now()


func tournaments_won() -> int:
	return int(_p.get("tournaments_won", 0))


func record_tournament_win() -> void:
	_p["tournaments_won"] = tournaments_won() + 1
	_check_unlocks()
	save_now()


# --- characters and games --------------------------------------------------

func unlocked_characters() -> Array:
	return _p.get("characters", [])


func is_character_unlocked(id: String) -> bool:
	return unlocked_characters().has(id)


func unlock_character(id: String, announce := true) -> bool:
	if is_character_unlocked(id):
		return false
	_p["characters"].append(id)
	if announce:
		EventBus.character_unlocked.emit(id)
		var c := Registry.character(id)
		EventBus.notify(Loc.t("unlock.character", {"name": c.display_name() if c else id}), "★")
	save_now()
	return true


func unlocked_games() -> Array:
	return _p.get("games", [])


func is_game_unlocked(id: String) -> bool:
	return unlocked_games().has(id)


func unlock_game(id: String, announce := true) -> bool:
	if is_game_unlocked(id):
		return false
	_p["games"].append(id)
	if announce:
		EventBus.minigame_unlocked.emit(id)
		var m := Registry.minigame(id)
		EventBus.notify(Loc.t("unlock.minigame", {"name": m.display_name() if m else id}), "◆")
	save_now()
	return true


func playable_characters() -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for c in Registry.characters():
		if is_character_unlocked(c.id) or DevTools.unlock_all:
			out.append(c)
	return out


func playable_games() -> Array[MiniGameDef]:
	var out: Array[MiniGameDef] = []
	for m in Registry.minigames():
		if is_game_unlocked(m.id) or DevTools.unlock_all:
			out.append(m)
	return out


func last_character() -> String:
	var id := String(_p.get("last_character", ""))
	if id != "" and is_character_unlocked(id):
		return id
	var list := playable_characters()
	return list[0].id if list.size() > 0 else ""


func set_last_character(id: String) -> void:
	_p["last_character"] = id
	_commit()


# --- adventure -------------------------------------------------------------

func is_world_unlocked(id: String) -> bool:
	return _p.get("worlds", []).has(id) or DevTools.unlock_all


func unlock_world(id: String) -> void:
	if _p["worlds"].has(id):
		return
	_p["worlds"].append(id)
	EventBus.world_unlocked.emit(id)
	save_now()


func stage_record(world_id: String, stage_id: String) -> Dictionary:
	var w: Dictionary = _p.get("adventure", {}).get(world_id, {})
	return w.get(stage_id, {"cleared": false, "stars": 0, "best": 0})


func is_stage_cleared(world_id: String, stage_id: String) -> bool:
	return bool(stage_record(world_id, stage_id).get("cleared", false))


## Records a stage attempt and returns true when it was newly cleared.
func record_stage(world_id: String, stage_id: String, cleared: bool, stars: int, score: int) -> bool:
	var adv: Dictionary = _p.get("adventure", {})
	if not adv.has(world_id):
		adv[world_id] = {}
	var w: Dictionary = adv[world_id]
	var prev: Dictionary = w.get(stage_id, {"cleared": false, "stars": 0, "best": 0})
	var newly := cleared and not bool(prev.get("cleared", false))
	w[stage_id] = {
		"cleared": bool(prev.get("cleared", false)) or cleared,
		"stars": maxi(int(prev.get("stars", 0)), stars),
		"best": maxi(int(prev.get("best", 0)), score),
	}
	_p["adventure"] = adv
	if newly:
		grant_trophies(1)
	_check_world_unlocks()
	completion_changed.emit(completion_percent())
	save_now()
	return newly


func world_progress(world_id: String) -> Dictionary:
	var w := Registry.world(world_id)
	var stages: Array = w.get("stages", [])
	var cleared := 0
	var stars := 0
	for s in stages:
		var rec := stage_record(world_id, String(s.get("id", "")))
		if bool(rec.get("cleared", false)):
			cleared += 1
		stars += int(rec.get("stars", 0))
	return {"cleared": cleared, "total": stages.size(), "stars": stars, "max_stars": stages.size() * 3}


## Overall completion across adventure stages, characters and mini-games.
## Drives the 25/50/75/100% reward tiers.
func completion_percent() -> float:
	var total := 0.0
	var done := 0.0
	for w in Registry.worlds():
		var wid := String(w.get("id", ""))
		var prog := world_progress(wid)
		total += float(prog["total"])
		done += float(prog["cleared"])
	total += float(Registry.characters().size())
	done += float(unlocked_characters().size())
	total += float(Registry.minigames().size())
	done += float(unlocked_games().size())
	if total <= 0.0:
		return 0.0
	return clampf(done / total * 100.0, 0.0, 100.0)


func adventure_complete() -> bool:
	for w in Registry.worlds():
		var wid := String(w.get("id", ""))
		var prog := world_progress(wid)
		if int(prog["cleared"]) < int(prog["total"]):
			return false
	return true


func reset_progress() -> void:
	SaveSystem.set_player_branch(BRANCH, {})
	_p = {}
	_load()
	completion_changed.emit(completion_percent())


# --- unlock evaluation -----------------------------------------------------

func _check_unlocks() -> void:
	for c in Registry.characters():
		if not is_character_unlocked(c.id) and _rule_met(c.unlock):
			unlock_character(c.id)
	for m in Registry.minigames():
		if not is_game_unlocked(m.id) and _rule_met(m.unlock):
			unlock_game(m.id)


func _check_world_unlocks() -> void:
	var worlds := Registry.worlds()
	for i in worlds.size():
		var w: Dictionary = worlds[i]
		var wid := String(w.get("id", ""))
		if is_world_unlocked(wid):
			continue
		var req := int(w.get("required_trophies", 0))
		var prev_done := true
		if i > 0:
			var prev := String(worlds[i - 1].get("id", ""))
			var prog := world_progress(prev)
			prev_done = int(prog["cleared"]) >= maxi(1, int(prog["total"]) - int(w.get("allow_skip", 0)))
		if prev_done and trophies() >= req:
			unlock_world(wid)
	_check_unlocks()


func _rule_met(rule: Dictionary) -> bool:
	if rule.is_empty():
		return true
	match String(rule.get("type", "")):
		"trophies":
			return trophies() >= int(rule.get("amount", 0))
		"gems":
			return gems() >= int(rule.get("amount", 0))
		"world_cleared":
			var prog := world_progress(String(rule.get("world", "")))
			return int(prog["total"]) > 0 and int(prog["cleared"]) >= int(prog["total"])
		"stage_cleared":
			return is_stage_cleared(String(rule.get("world", "")), String(rule.get("stage", "")))
		"wins":
			return Stats.total_wins() >= int(rule.get("amount", 0))
		"tournaments":
			return tournaments_won() >= int(rule.get("amount", 0))
		"completion":
			return completion_percent() >= float(rule.get("amount", 100.0))
		"achievement":
			return Achievements.is_unlocked(String(rule.get("id", "")))
	return false


## Human-readable hint for a locked item, shown on the select screens.
func unlock_hint(rule: Dictionary) -> String:
	if rule.is_empty():
		return ""
	var t := String(rule.get("type", ""))
	match t:
		"trophies":
			return Loc.t("unlock.hint.trophies", {"n": rule.get("amount", 0)})
		"gems":
			return Loc.t("unlock.hint.gems", {"n": rule.get("amount", 0)})
		"world_cleared":
			var w := Registry.world(String(rule.get("world", "")))
			return Loc.t("unlock.hint.world", {"name": Loc.t(String(w.get("name_key", "")))})
		"wins":
			return Loc.t("unlock.hint.wins", {"n": rule.get("amount", 0)})
		"tournaments":
			return Loc.t("unlock.hint.tournaments", {"n": rule.get("amount", 0)})
		"completion":
			return Loc.t("unlock.hint.completion", {"n": rule.get("amount", 0)})
	return Loc.t("unlock.hint.generic")
