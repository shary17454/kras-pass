class_name PartyLibrary
extends RefCounted


static func favorites() -> Array[String]:
	var out: Array[String] = []
	var data = SaveSystem.player_branch("party").get("favorites", [])
	if data is Array:
		for id in data:
			var def := Registry.minigame(String(id))
			if def != null and not def.is_boss and Progression.is_game_unlocked(def.id) and not out.has(def.id):
				out.append(def.id)
	return out


static func toggle_favorite(id: String) -> bool:
	var ids := favorites()
	if ids.has(id):
		ids.erase(id)
	else:
		var def := Registry.minigame(id)
		if def == null or def.is_boss or not Progression.is_game_unlocked(id):
			return false
		ids.append(id)
	var branch := SaveSystem.player_branch("party")
	branch["favorites"] = ids
	SaveSystem.set_player_branch("party", branch)
	SaveSystem.flush()
	return ids.has(id)
