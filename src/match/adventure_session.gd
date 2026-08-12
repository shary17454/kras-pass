class_name AdventureSession
extends RefCounted
## One adventure stage attempt.
##
## Owns the bridge between the map screen, the match and the reward. Stars are
## awarded on placement, trophies on first clear, and the whole thing is
## recorded through `Progression` so the map, the completion percentage and the
## unlock rules all see the same event.

var world_id := ""
var stage := {}
var character_id := ""


func setup(world: Dictionary, stage_data: Dictionary, character: String) -> void:
	world_id = String(world.get("id", ""))
	stage = stage_data
	character_id = character


func stage_id() -> String:
	return String(stage.get("id", ""))


func is_boss() -> bool:
	return bool(stage.get("boss", false))


func display_name() -> String:
	if stage.has("name_key"):
		return Loc.t(String(stage["name_key"]))
	var m := Registry.minigame(String(stage.get("game", "")))
	return m.display_name() if m != null else stage_id()


func build_config() -> MatchConfig:
	var game_id := String(stage.get("game", ""))
	var def := Registry.minigame(game_id)
	if def == null:
		return null
	var cfg := MatchConfig.new()
	cfg.minigame_id = game_id
	cfg.context = MatchConfig.Context.ADVENTURE
	cfg.arena_id = String(stage.get("arena", def.arena_ids[0] if def.arena_ids.size() > 0 else ""))
	cfg.rounds = int(stage.get("rounds", 1))
	cfg.sudden_death = def.supports_sudden_death
	cfg.subtitle_key = String(stage.get("name_key", "adventure.title"))
	cfg.seed = hash(world_id + stage_id()) & 0x7FFFFFFF

	var difficulty := int(stage.get("difficulty", 1))
	if is_boss():
		difficulty = mini(PlayerConfig.Difficulty.EXPERT, difficulty + 1)
	var opponents := int(stage.get("opponents", 3))
	if DevTools.available() and DevTools.forced_bot_count >= 0:
		opponents = DevTools.forced_bot_count

	var me := PlayerConfig.new()
	me.slot = 0
	me.character_id = character_id
	me.is_human = true
	cfg.players.append(me)

	var roster := _opponent_roster(opponents)
	for i in opponents:
		var p := PlayerConfig.new()
		p.slot = i + 1
		p.character_id = roster[i]
		p.is_human = false
		p.ai_difficulty = difficulty
		cfg.players.append(p)
	return cfg


## Opponents are drawn from the full roster, not just unlocked characters — the
## adventure is where a player first meets the competitors they have yet to earn.
func _opponent_roster(count: int) -> Array[String]:
	var all: Array[String] = []
	for c in Registry.characters():
		if c.id != character_id:
			all.append(c.id)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(world_id + stage_id() + "opponents") & 0x7FFFFFFF
	var out: Array[String] = []
	for i in count:
		if all.is_empty():
			out.append(character_id)
			continue
		var idx := rng.randi_range(0, all.size() - 1)
		out.append(all[idx])
		all.remove_at(idx)
	return out


## Stars: 3 for winning, 2 for a podium, 1 for finishing at all.
static func stars_for(place: int, players: int) -> int:
	if place <= 1:
		return 3
	if place == 2 and players > 2:
		return 2
	return 1


func on_match_finished(result: MatchResult) -> void:
	var place := result.place_of(0)
	var cleared := place == 1
	var stars := stars_for(place, result.places.size())
	var newly := Progression.record_stage(world_id, stage_id(), cleared, stars, result.score_of(0))
	var gems := Balance.inum("tuning", "scoring.gems_per_participation", 1)
	if cleared:
		gems += Balance.inum("tuning", "scoring.gems_per_win", 3)
	if newly and stage.has("reward_gems"):
		gems += int(stage["reward_gems"])
	Progression.grant_gems(gems)
	Achievements.evaluate_all()
	SceneRouter.go_to("results", {
		"result": result,
		"config": build_config(),
		"adventure": {
			"world": world_id,
			"stage": stage_id(),
			"cleared": cleared,
			"stars": stars,
			"newly_cleared": newly,
			"gems": gems,
		},
	}, false)
