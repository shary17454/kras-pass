extends Node
## Typed content catalogue. Autoload name: `Registry`.
##
## Turns the raw JSON in `Balance` into validated resource objects and is the
## only place the rest of the game looks up content. `validate()` is run by the
## test suite and by the debug menu: it catches a missing script, a mini-game
## pointing at an arena that does not exist, or a string key with no
## translation — the class of bug that otherwise only shows up as a broken
## screen three menus deep.

var _characters: Array[CharacterData] = []
var _minigames: Array[MiniGameDef] = []
var _arenas: Array[ArenaDef] = []
var _powerups: Array[PowerUpDef] = []
var _by_id := {"char": {}, "game": {}, "arena": {}, "powerup": {}}


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	_characters.clear()
	_minigames.clear()
	_arenas.clear()
	_powerups.clear()
	for k in _by_id:
		_by_id[k].clear()

	for d in Balance.list("characters", "characters"):
		var c := CharacterData.from_dict(d)
		_characters.append(c)
		_by_id["char"][c.id] = c
	for d in Balance.list("minigames", "games"):
		var m := MiniGameDef.from_dict(d)
		_minigames.append(m)
		_by_id["game"][m.id] = m
	for d in Balance.list("arenas", "arenas"):
		var a := ArenaDef.from_dict(d)
		_arenas.append(a)
		_by_id["arena"][a.id] = a
	for d in Balance.list("powerups", "powerups"):
		var p := PowerUpDef.from_dict(d)
		_powerups.append(p)
		_by_id["powerup"][p.id] = p
	Log.i("registry: %d characters, %d games, %d arenas, %d powerups" % [
		_characters.size(), _minigames.size(), _arenas.size(), _powerups.size()
	], "Registry")


# --- lookups ---------------------------------------------------------------

func characters() -> Array[CharacterData]:
	return _characters


func character(id: String) -> CharacterData:
	return _by_id["char"].get(id)


func minigames() -> Array[MiniGameDef]:
	return _minigames


func minigame(id: String) -> MiniGameDef:
	return _by_id["game"].get(id)


func arenas() -> Array[ArenaDef]:
	return _arenas


func arena(id: String) -> ArenaDef:
	return _by_id["arena"].get(id)


func powerups() -> Array[PowerUpDef]:
	return _powerups


func powerup(id: String) -> PowerUpDef:
	return _by_id["powerup"].get(id)


func minigames_in_category(cat: MiniGameDef.Category) -> Array[MiniGameDef]:
	var out: Array[MiniGameDef] = []
	for m in _minigames:
		if m.category == cat:
			out.append(m)
	return out


func powerups_for(category_name: String) -> Array[PowerUpDef]:
	var out: Array[PowerUpDef] = []
	for p in _powerups:
		if p.allowed_in(category_name):
			out.append(p)
	return out


func starter_characters() -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for c in _characters:
		if c.starter:
			out.append(c)
	return out


func worlds() -> Array:
	return Balance.list("adventure", "worlds")


func world(id: String) -> Dictionary:
	for w in worlds():
		if String(w.get("id", "")) == id:
			return w
	return {}


func achievement_defs() -> Array:
	return Balance.list("achievements", "achievements")


## Deterministic pick used by "random game" buttons and the tournament roller,
## seeded so a replay or a networked lobby lands on the same choice.
func random_minigame(rng: RandomNumberGenerator, pool: Array = []) -> MiniGameDef:
	var source: Array = pool if not pool.is_empty() else _minigames
	if source.is_empty():
		return null
	return source[rng.randi_range(0, source.size() - 1)]


# --- validation ------------------------------------------------------------

## Returns a list of human-readable content problems. Empty means shippable.
func validate(check_localization: bool = true) -> PackedStringArray:
	var problems := PackedStringArray()
	if _characters.is_empty():
		problems.append("no characters defined")
	if _minigames.is_empty():
		problems.append("no mini-games defined")

	var seen := {}
	for c in _characters:
		if c.id == "":
			problems.append("character with empty id")
		if seen.has("c" + c.id):
			problems.append("duplicate character id '%s'" % c.id)
		seen["c" + c.id] = true
		if check_localization and not Loc.has(c.name_key):
			problems.append("character '%s' missing loc key %s" % [c.id, c.name_key])

	for m in _minigames:
		if seen.has("g" + m.id):
			problems.append("duplicate mini-game id '%s'" % m.id)
		seen["g" + m.id] = true
		# The full completeness checklist lives in MiniGameValidator so that
		# adding a game fails loudly at build time rather than quietly in a menu.
		problems.append_array(MiniGameValidator.validate(m, check_localization))
		if not ResourceLoader.exists(m.controller_script):
			problems.append("mini-game '%s' script not found: %s" % [m.id, m.controller_script])
		if m.arena_ids.is_empty():
			problems.append("mini-game '%s' has no arenas" % m.id)
		for aid in m.arena_ids:
			if arena(aid) == null:
				problems.append("mini-game '%s' references unknown arena '%s'" % [m.id, aid])
		if m.min_players < 1 or m.max_players < m.min_players or m.max_players > 4:
			problems.append("mini-game '%s' has invalid player range" % m.id)
		if m.duration <= 0.0 and m.scoring != MiniGameDef.Scoring.SURVIVAL:
			problems.append("mini-game '%s' has no duration" % m.id)
		if check_localization:
			for key in [m.name_key, m.desc_key, m.rules_key]:
				if not Loc.has(key):
					problems.append("mini-game '%s' missing loc key %s" % [m.id, key])

	for a in _arenas:
		if seen.has("a" + a.id):
			problems.append("duplicate arena id '%s'" % a.id)
		seen["a" + a.id] = true
		if a.radius <= 2.0:
			problems.append("arena '%s' radius too small" % a.id)
		if check_localization and not Loc.has(a.name_key):
			problems.append("arena '%s' missing loc key %s" % [a.id, a.name_key])

	for p in _powerups:
		if check_localization and not Loc.has(p.name_key):
			problems.append("powerup '%s' missing loc key %s" % [p.id, p.name_key])

	# Every arena should be reachable from at least one mini-game, otherwise it
	# is dead content that will never be seen.
	var used := {}
	for m in _minigames:
		for aid in m.arena_ids:
			used[aid] = true
	for a in _arenas:
		if not used.has(a.id):
			problems.append("arena '%s' is not used by any mini-game" % a.id)

	# Adventure must only reference games that exist.
	for w in worlds():
		for stage in w.get("stages", []):
			var gid := String(stage.get("game", ""))
			if minigame(gid) == null:
				problems.append("adventure world '%s' references unknown game '%s'" % [w.get("id", "?"), gid])
	return problems
