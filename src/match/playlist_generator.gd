class_name PlaylistGenerator
extends RefCounted
## Builds the schedule for a party: which games, in which arenas, with which
## modifiers — from a preset in `data/mutators.json` or from explicit filters.
##
## A blind shuffle repeats itself in ways a person notices immediately: three
## push-out games in a row, the same arena twice back to back. This generator
## draws without replacement the way `TournamentSession.random_games()`
## already did, and adds one more constraint on top — no two *consecutive*
## entries share a category or an arena, whenever the pool is large enough to
## avoid it. When the pool is too small to honour that (e.g. a "races only"
## preset with three race games), it falls back to plain no-repeat-per-pass
## rather than looping forever.
##
## One entry is `{game_id, arena_id, mutators, difficulty}` — everything
## `next_config()` needs to build a `MatchConfig` without asking anywhere else.

const MAX_PLACEMENT_ATTEMPTS := 12


## Build a schedule from a named preset (`data/mutators.json` → `presets`).
## `pool_override` limits selection to specific games (e.g. hand-picked in the
## UI); leave empty to use everything the preset's category filter allows.
static func from_preset(preset_id: String, rng_seed: int, pool_override: Array = []) -> Dictionary:
	var presets := Balance.list("mutators", "presets")
	var preset := {}
	for p in presets:
		if String(p.get("id", "")) == preset_id:
			preset = p
			break
	if preset.is_empty():
		Log.w("unknown party preset '%s'" % preset_id, "Playlist")
		preset = {"games_count": 8, "difficulty": 1, "powerups": true}

	var count := int(preset.get("games_count", 8))
	var categories: Array = preset.get("categories", [])
	var mutator_ids: Array = preset.get("mutators", [])
	var difficulty := int(preset.get("difficulty", 1))
	var chaos := bool(preset.get("chaos", false))
	var powerups := bool(preset.get("powerups", true))

	var pool := _resolve_pool(pool_override, categories)
	var entries := generate(pool, count, rng_seed)
	return {
		"entries": entries,
		"difficulty": difficulty,
		"chaos": chaos,
		"powerups": powerups,
		"mutators": mutator_ids,
		"preset": preset_id,
	}


static func _resolve_pool(pool_override: Array, categories: Array) -> Array[MiniGameDef]:
	var out: Array[MiniGameDef] = []
	var source: Array
	if not pool_override.is_empty():
		source = pool_override
	else:
		source = Progression.playable_games()
	for m in source:
		var def: MiniGameDef = m if m is MiniGameDef else Registry.minigame(String(m))
		if def == null:
			continue
		if not categories.is_empty() and not categories.has(def.category_name()):
			continue
		out.append(def)
	return out


## The reusable core: `count` entries drawn without replacement from `pool`,
## reshuffling once exhausted, preferring not to repeat the previous entry's
## category or arena. Deterministic for a given seed.
static func generate(pool: Array[MiniGameDef], count: int, rng_seed: int) -> Array:
	var out: Array = []
	if pool.is_empty() or count <= 0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var bag: Array[MiniGameDef] = []
	var last_category := ""
	var last_arena := ""

	while out.size() < count:
		if bag.is_empty():
			bag = pool.duplicate()
			_shuffle(bag, rng)
		var chosen := _pick_avoiding_repeat(bag, last_category)
		var def: MiniGameDef = chosen["def"]
		bag.remove_at(chosen["index"])
		var arena_id := _pick_arena(def, last_arena, rng)
		out.append({
			"game_id": def.id,
			"arena_id": arena_id,
			"category": def.category_name(),
		})
		last_category = def.category_name()
		last_arena = arena_id
	return out


static func _pick_avoiding_repeat(bag: Array[MiniGameDef], last_category: String) -> Dictionary:
	if last_category != "" and bag.size() > 1:
		for i in bag.size():
			if bag[i].category_name() != last_category:
				return {"def": bag[i], "index": i}
	# Pool is exhausted of variety (or this is the first pick) — take the front.
	return {"def": bag[0], "index": 0}


static func _pick_arena(def: MiniGameDef, last_arena: String, rng: RandomNumberGenerator) -> String:
	if def.arena_ids.is_empty():
		return ""
	if def.arena_ids.size() == 1 or not def.arena_ids.has(last_arena):
		return def.arena_ids[rng.randi_range(0, def.arena_ids.size() - 1)]
	var choices: PackedStringArray = []
	for a in def.arena_ids:
		if a != last_arena:
			choices.append(a)
	return choices[rng.randi_range(0, choices.size() - 1)] if choices.size() > 0 else def.arena_ids[0]


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


static func preset_ids() -> Array[String]:
	var out: Array[String] = []
	for p in Balance.list("mutators", "presets"):
		out.append(String(p.get("id", "")))
	return out


static func preset_meta(preset_id: String) -> Dictionary:
	for p in Balance.list("mutators", "presets"):
		if String(p.get("id", "")) == preset_id:
			return p
	return {}
