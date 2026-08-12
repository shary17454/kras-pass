extends "res://src/ai/brains/generic_brain.gd"
## Crumble Court: keep moving toward solid ground.
##
## The bot evaluates the tiles around it exactly as they are drawn — solid,
## shaking, gone — and heads for the nearest solid one that is not directly
## under a rival. `edge_awareness` governs how far ahead it plans, so Easy bots
## routinely paint themselves into a corner.

var _target_tile: ArenaTile


func decide(_delta: float) -> void:
	var me := self_body()
	var arena := ctx.arena as Arena
	if me == null or arena == null:
		return

	var current := arena.tile_at(me.global_position)
	var unsafe := current == null or current.state != ArenaTile.State.SOLID
	if _target_tile == null or not is_instance_valid(_target_tile) or not _target_tile.is_standable() \
			or (unsafe and rng.randf() < edge_awareness):
		_target_tile = _pick_tile(arena, me.global_position)

	if _target_tile != null and is_instance_valid(_target_tile):
		steer_to(_target_tile.global_position)
		if unsafe and distance_to(_target_tile.global_position) > 2.4:
			maybe_dash(1.5)
	else:
		steer_to(arena.global_position)

	# Opportunistic shove: a rival standing on shaking ground is one nudge from
	# being gone.
	var rival := nearest_rival()
	if rival >= 0 and distance_to(perceive(rival)) < 2.6:
		var their_tile := arena.tile_at(perceive(rival))
		if their_tile != null and their_tile.state != ArenaTile.State.SOLID:
			maybe_attack(rival, 2.6)
		elif rng.randf() < aggression * 0.5:
			maybe_attack(rival, 2.6)


func _pick_tile(arena: Arena, from: Vector3) -> ArenaTile:
	var best: ArenaTile = null
	var best_score := -INF
	for t in arena.tiles:
		if t.state != ArenaTile.State.SOLID:
			continue
		var d: float = Vector2(t.global_position.x - from.x, t.global_position.z - from.z).length()
		if d > 12.0:
			continue
		var score := -d
		# Prefer tiles with solid neighbours: a lone island is a death sentence.
		score += _solid_neighbours(arena, t) * lerp(0.4, 2.4, edge_awareness)
		if _occupied(t):
			score -= 4.0
		if score > best_score:
			best_score = score
			best = t
	return best


func _solid_neighbours(arena: Arena, tile: ArenaTile) -> float:
	var n := 0.0
	for t in arena.tiles:
		if t == tile or t.state != ArenaTile.State.SOLID:
			continue
		if absi(t.grid_x - tile.grid_x) <= 1 and absi(t.grid_z - tile.grid_z) <= 1:
			n += 1.0
	return n


func _occupied(tile: ArenaTile) -> bool:
	for i in ctx.fighters.size():
		if i == slot or not ctx.is_alive(i):
			continue
		if perceive(i).distance_to(tile.global_position) < 1.2:
			return true
	return false
