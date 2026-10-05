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
	if not can_observe(_target_tile) or _target_tile.state != ArenaTile.State.SOLID \
			or (unsafe and rng.randf() < edge_awareness):
		_target_tile = _pick_tile(arena, me.global_position)

	if can_observe(_target_tile):
		steer_to(_target_tile.global_position)
		if unsafe and distance_to(_target_tile.global_position) > 2.4:
			maybe_dash(1.5)
	else:
		steer_to(me.global_position)

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
	var origin := arena.tile_at(from)
	if not can_observe(origin) or not origin.is_standable():
		return null
	var visible_ground := {}
	for tile in arena.tiles:
		if can_observe(tile) and tile.is_standable() \
				and Vector2(tile.global_position.x - from.x, tile.global_position.z - from.z).length() <= 12.0:
			visible_ground[Vector2i(tile.grid_x, tile.grid_z)] = tile
	var start := Vector2i(origin.grid_x, origin.grid_z)
	# Cardinal steps cannot cut diagonally across the corner of a missing tile.
	var first_steps := {start: origin}
	var pending: Array[ArenaTile] = [origin]
	var cursor := 0
	while cursor < pending.size():
		var tile := pending[cursor]
		cursor += 1
		var cell := Vector2i(tile.grid_x, tile.grid_z)
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + offset
			if first_steps.has(next) or not visible_ground.has(next):
				continue
			var neighbour: ArenaTile = visible_ground[next]
			first_steps[next] = neighbour if cell == start else first_steps[cell]
			pending.append(neighbour)
	var best: ArenaTile = null
	var best_score := -INF
	for cell in first_steps:
		var t: ArenaTile = visible_ground.get(cell)
		if t == null or t.state != ArenaTile.State.SOLID:
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
			best = first_steps[cell]
	return best


func _solid_neighbours(arena: Arena, tile: ArenaTile) -> float:
	var n := 0.0
	for t in arena.tiles:
		if t == tile or not can_observe(t) or t.state != ArenaTile.State.SOLID:
			continue
		if absi(t.grid_x - tile.grid_x) <= 1 and absi(t.grid_z - tile.grid_z) <= 1:
			n += 1.0
	return n


func _occupied(tile: ArenaTile) -> bool:
	for i in ctx.fighters.size():
		if i == slot or not ctx.is_alive(i) or not can_observe(ctx.fighter(i)):
			continue
		if perceive(i).distance_to(tile.global_position) < 1.2:
			return true
	return false
