class_name MatchConfig
extends Resource
## Everything needed to start a match, from any entry point.
##
## Quick Play, Tournament, Adventure and Training all build one of these and
## hand it to `MatchScene`. The mini-game never asks *why* it is running, which
## is what lets the same 21 games serve four different modes.

enum Context { QUICK, TOURNAMENT, ADVENTURE, TRAINING, ONLINE }

@export var minigame_id := ""
@export var arena_id := ""
@export var context: Context = Context.QUICK
@export var rounds := 1
@export var duration_override := 0.0  # 0 = use the mini-game default
@export var players: Array[PlayerConfig] = []
@export var seed := 0
@export var allow_powerups := true
@export var sudden_death := true
## Free-form per-game switches (e.g. {"ball_count": 3}). Read via `rule()`.
@export var rules := {}
## Adventure/tournament label shown above the HUD.
@export var subtitle_key := ""


func rule(key: String, fallback):
	return rules.get(key, fallback)


func human_slots() -> Array[int]:
	var out: Array[int] = []
	for p in players:
		if p.is_human:
			out.append(p.slot)
	return out


func player_count() -> int:
	return players.size()


func player_at(slot: int) -> PlayerConfig:
	for p in players:
		if p.slot == slot:
			return p
	return null


func definition() -> MiniGameDef:
	return Registry.minigame(minigame_id)


func make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng


## Convenience builder used by Quick Play, the debug menu and every test.
static func build(game_id: String, characters: Array, human_count: int, difficulty: int, rng_seed: int = 0) -> MatchConfig:
	var cfg := MatchConfig.new()
	cfg.minigame_id = game_id
	var def := Registry.minigame(game_id)
	if def != null and def.arena_ids.size() > 0:
		cfg.arena_id = def.arena_ids[0]
		cfg.rounds = def.default_rounds
		cfg.sudden_death = def.supports_sudden_death
	cfg.seed = rng_seed if rng_seed != 0 else 1
	for i in characters.size():
		var p := PlayerConfig.new()
		p.slot = i
		p.character_id = String(characters[i])
		p.is_human = i < human_count
		p.ai_difficulty = difficulty
		cfg.players.append(p)
	return cfg
