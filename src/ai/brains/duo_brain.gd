extends "res://src/ai/brains/generic_brain.gd"
## Duo Clash. The brawler underneath already lines rivals up against the rim;
## the only thing a team changes is who counts as a rival — and that a partner
## in trouble is worth leaving a fight for.


func _pick_target() -> int:
	if controller == null:
		return super._pick_target()
	var team: int = controller.call("team_of", slot)
	# Whoever is nearest the edge on the *other* side, else the nearest
	# opponent. Reusing the base class's cues would happily pick a partner.
	var arena := ctx.arena as Arena
	var best := -1
	var best_margin := 4.0
	if arena != null and rng.randf() < edge_awareness:
		for i in ctx.fighters.size():
			if i == slot or not ctx.is_alive(i) or int(controller.call("team_of", i)) == team:
				continue
			var margin := arena.edge_distance(perceive(i))
			if margin < best_margin:
				best_margin = margin
				best = i
	if best >= 0 and not is_empowered(best):
		return best
	var me := self_body()
	if me == null:
		return -1
	var nearest := -1
	var nearest_d := INF
	for i in ctx.fighters.size():
		if i == slot or not ctx.is_alive(i) or int(controller.call("team_of", i)) == team:
			continue
		var d := me.global_position.distance_squared_to(perceive(i))
		if d < nearest_d:
			nearest_d = d
			nearest = i
	return nearest
