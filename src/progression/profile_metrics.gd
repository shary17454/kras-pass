class_name ProfileMetrics
extends RefCounted
## Evaluate earned progress without switching the active local player.

const TYPES := ["wins", "matches", "knockouts", "expert_wins", "flawless_wins", "no_fall_wins", "comeback_cups",
	"trophies", "gems", "tournaments", "win_streak", "characters_unlocked", "games_unlocked", "completion",
	"play_hours", "all_minigames_won", "adventure_complete", "world_cleared", "stage_cleared", "achievement", "game_wins", "game_best"]


static func world_progress(progress: Dictionary, world_id: String) -> Dictionary:
	var stages: Array = Registry.world(world_id).get("stages", [])
	var saved: Dictionary = progress.get("adventure", {}).get(world_id, {})
	var cleared := 0
	var stars := 0
	for stage in stages:
		var record: Dictionary = saved.get(String(stage.get("id", "")), {})
		cleared += int(bool(record.get("cleared", false)))
		stars += clampi(int(record.get("stars", 0)), 0, 3)
	return {"cleared": cleared, "total": stages.size(), "stars": stars, "max_stars": stages.size() * 3}


static func completion(progress: Dictionary) -> float:
	var total := 0
	var done := 0
	for world in Registry.worlds():
		var value := world_progress(progress, String(world.get("id", "")))
		total += int(value["total"])
		done += int(value["cleared"])
	for character in Registry.characters():
		total += 1
		done += int(progress.get("characters", []).has(character.id))
	for game in Registry.minigames():
		total += 1
		done += int(progress.get("games", []).has(game.id))
	return 100.0 * float(done) / float(total) if total > 0 else 0.0


static func measure(condition: Dictionary, profile_id: String) -> float:
	var stats := SaveSystem.profile_branch(profile_id, "stats")
	var progress := SaveSystem.profile_branch(profile_id, "progress")
	var kind := String(condition.get("type", ""))
	match kind:
		"wins", "matches", "knockouts", "expert_wins", "flawless_wins", "no_fall_wins", "comeback_cups":
			return float(stats.get(kind, 0))
		"trophies", "gems": return float(progress.get(kind, 0))
		"tournaments": return float(progress.get("tournaments_won", 0))
		"win_streak": return float(stats.get("longest_win_streak", 0))
		"characters_unlocked": return float(progress.get("characters", []).size())
		"games_unlocked": return float(progress.get("games", []).size())
		"completion": return completion(progress)
		"play_hours": return float(stats.get("play_seconds", 0)) / 3600.0
		"all_minigames_won":
			for game in Registry.minigames():
				if int(stats.get("per_game", {}).get(game.id, {}).get("wins", 0)) < 1:
					return 0.0
			return 1.0
		"adventure_complete":
			for world in Registry.worlds():
				var value := world_progress(progress, String(world.get("id", "")))
				if value["cleared"] < value["total"]:
					return 0.0
			return 1.0
		"world_cleared":
			var value := world_progress(progress, String(condition.get("world", "")))
			return 1.0 if value["total"] > 0 and value["cleared"] == value["total"] else 0.0
		"stage_cleared":
			return float(bool(progress.get("adventure", {}).get(String(condition.get("world", "")), {}).get(String(condition.get("stage", "")), {}).get("cleared", false)))
		"achievement":
			return float(SaveSystem.profile_branch(profile_id, "achievements").has(String(condition.get("id", ""))))
		"game_wins", "game_best":
			return float(stats.get("per_game", {}).get(String(condition.get("game", "")), {}).get("wins" if kind == "game_wins" else "best", 0))
	return 0.0


static func rule_met(condition: Dictionary, profile_id: String, empty_allowed := false) -> bool:
	if condition.is_empty():
		return empty_allowed
	if not TYPES.has(String(condition.get("type", ""))):
		return false
	return measure(condition, profile_id) >= float(condition.get("amount", 1))
