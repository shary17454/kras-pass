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
var _profile_id := ""


func setup(world: Dictionary, stage_data: Dictionary, character: String) -> void:
	world_id = String(world.get("id", ""))
	stage = stage_data
	character_id = character
	_profile_id = SaveSystem.active_profile_id()


func stage_id() -> String:
	return String(stage.get("id", ""))


static func for_rematch(config: MatchConfig, context: Dictionary) -> AdventureSession:
	if config == null or config.context != MatchConfig.Context.ADVENTURE or config.player_at(0) == null:
		return null
	var player := config.player_at(0)
	if not player.local_profile_id.is_empty() and player.local_profile_id != SaveSystem.active_profile_id():
		return null
	var world := Registry.world(String(context.get("world", "")))
	for candidate in world.get("stages", []):
		if String(candidate.get("id", "")) == String(context.get("stage", "")) \
				and String(candidate.get("game", "")) == config.minigame_id:
			var session := AdventureSession.new()
			session.setup(world, candidate, player.character_id)
			return session
	return null


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
	me.local_profile_id = _profile_id
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
	if players <= 0 or place <= 0 or place > players:
		return 0
	if place == 1:
		return 3
	if place == 2 and players > 2:
		return 2
	return 1


func award_result(result: MatchResult) -> Dictionary:
	var reward := {"cleared": false, "stars": 0, "newly_cleared": false, "gems": 0}
	if result == null or not result.finished_naturally or result.place_of(0) <= 0 \
			or _profile_id.is_empty() or SaveSystem.active_profile_id() != _profile_id \
			or result.scores.size() != result.places.size() \
			or result.place_of(0) > result.places.size() or world_id.is_empty() or stage_id().is_empty() \
			or result.minigame_id != String(stage.get("game", "")):
		return reward
	var receipt := "%s:%s" % [world_id, stage_id()]
	if result.reward_id.is_empty():
		result.reward_id = Crypto.new().generate_random_bytes(16).hex_encode()
	var receipts := SaveSystem.profile_branch(_profile_id, "adventure_receipts")
	if receipts.has(result.reward_id):
		var saved = receipts[result.reward_id]
		if saved is Dictionary and saved.get("stage") == receipt and saved.get("reward") is Dictionary:
			var canonical := _canonical_reward(saved["reward"])
			return canonical if not canonical.is_empty() else reward
		return reward
	var rewards = result.get_meta("adventure_rewards", {})
	if not rewards is Dictionary:
		return reward
	if rewards.has(receipt):
		var canonical := _canonical_reward(rewards[receipt])
		if canonical.is_empty():
			return reward
		reward = canonical
		receipts[result.reward_id] = {"stage": receipt, "reward": reward.duplicate(true)}
		SaveSystem.set_profile_branch(_profile_id, "adventure_receipts", receipts)
		SaveSystem.flush()
		return reward
	var place := result.place_of(0)
	var definition := Registry.minigame(result.minigame_id)
	var objective_met := true
	if definition != null and definition.is_boss:
		var rounds := maxi(1, result.rounds.size())
		objective_met = int(result.detail(0, "boss_rounds", 0)) == rounds \
			and int(result.detail(0, "boss_defeats", 0)) == rounds
	var cleared := objective_met and place == 1 and not result.is_draw()
	var stars := stars_for(2 if place == 1 and result.is_draw() else place, result.places.size()) if objective_met else 0
	SaveSystem.begin_batch()
	var newly := Progression.record_stage(world_id, stage_id(), cleared, stars, result.score_of(0))
	var gems := Balance.inum("tuning", "scoring.gems_per_participation", 1)
	if cleared:
		gems += Balance.inum("tuning", "scoring.gems_per_win", 3)
	if newly and stage.has("reward_gems"):
		gems += int(stage["reward_gems"])
	Progression.grant_gems(gems)
	Achievements.evaluate_all()
	reward = {"cleared": cleared, "stars": stars, "newly_cleared": newly, "gems": gems}
	# Receipt and progression share the same atomic profile-slot write.
	receipts[result.reward_id] = {"stage": receipt, "reward": reward.duplicate(true)}
	SaveSystem.set_profile_branch(_profile_id, "adventure_receipts", receipts)
	SaveSystem.end_batch()
	rewards[receipt] = reward.duplicate(true)
	result.set_meta("adventure_rewards", rewards)
	return reward


static func _canonical_reward(value: Variant) -> Dictionary:
	if not value is Dictionary or not value.get("cleared") is bool or not value.get("newly_cleared") is bool:
		return {}
	for key in ["stars", "gems"]:
		var number = value.get(key)
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)) \
				or number < 0 or number > 2147483647 or float(number) != floor(float(number)):
			return {}
	if value["stars"] > 3:
		return {}
	return {"cleared": value["cleared"], "stars": int(value["stars"]),
		"newly_cleared": value["newly_cleared"], "gems": int(value["gems"])}


func on_match_finished(result: MatchResult) -> void:
	var reward := award_result(result)
	SceneRouter.go_to("results", {
		"result": result,
		"config": build_config(),
		"adventure": {
			"world": world_id,
			"stage": stage_id(),
			"cleared": reward["cleared"],
			"stars": reward["stars"],
			"newly_cleared": reward["newly_cleared"],
			"gems": reward["gems"],
		},
	}, false)
